package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/labstack/echo/v4"
	echomiddleware "github.com/labstack/echo/v4/middleware"
	"github.com/rs/zerolog"

	"github.com/miigho/miigho/internal/auth"
	"github.com/miigho/miigho/internal/business"
	"github.com/miigho/miigho/internal/chat"
	"github.com/miigho/miigho/internal/common"
	"github.com/miigho/miigho/internal/config"
	"github.com/miigho/miigho/internal/contact"
	"github.com/miigho/miigho/internal/ledger"
	"github.com/miigho/miigho/internal/media"
	"github.com/miigho/miigho/internal/middleware"
	"github.com/miigho/miigho/internal/platform/encryption"
	"github.com/miigho/miigho/internal/platform/events"
	"github.com/miigho/miigho/internal/psp"
	"github.com/miigho/miigho/internal/user"
	"github.com/miigho/miigho/pkg/cache"
	"github.com/miigho/miigho/pkg/database"
	"github.com/miigho/miigho/pkg/messaging"
	"github.com/miigho/miigho/pkg/storage"
)

type DevSMSProvider struct {
	logger zerolog.Logger
}

func (p *DevSMSProvider) SendSMS(phone, message string) error {
	p.logger.Info().Str("to", phone).Str("content", message).Msg("SMS OTP dispatched (Dev mode)")
	return nil
}

func main() {
	// Initialize structured logging
	logger := zerolog.New(os.Stdout).With().Timestamp().Logger()
	logger.Info().Msg("Starting MÏÏghO backend server (MÏÏghO OS v1.0)...")

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		logger.Fatal().Err(err).Msg("Failed to load configuration")
	}

	ctx := context.Background()

	// Initialize PostgreSQL connection pool
	pgPool, err := database.NewPostgresPool(ctx, cfg)
	if err != nil {
		logger.Fatal().Err(err).Msg("Failed to initialize PostgreSQL pool")
	}
	defer pgPool.Close()
	logger.Info().Msg("PostgreSQL connected successfully")

	// Initialize Valkey client
	valkeyClient, err := cache.NewValkeyClient(ctx, cfg)
	if err != nil {
		logger.Fatal().Err(err).Msg("Failed to initialize Valkey client")
	}
	logger.Info().Msg("Valkey connected successfully")

	// Initialize MinIO client
	s3Client, err := storage.NewS3Client(cfg)
	if err != nil {
		logger.Fatal().Err(err).Msg("Failed to initialize MinIO client")
	}
	if err := s3Client.EnsureBucket(ctx); err != nil {
		logger.Fatal().Err(err).Msg("Failed to ensure MinIO bucket exists")
	}
	logger.Info().Msg("MinIO initialized successfully")

	// Initialize NATS client & event bus
	natsClient, err := messaging.NewNATSClient(cfg.NATS.URL)
	if err != nil {
		logger.Fatal().Err(err).Msg("Failed to initialize NATS client")
	}
	defer natsClient.Close()
	logger.Info().Msg("NATS JetStream connected successfully")
	eventBus := events.NewNATSEventBus(natsClient)

	// Initialize custom validator
	validator := common.NewValidator()

	// Initialize domain repositories
	authRepo := auth.NewPostgresAuthRepository(pgPool)
	userRepo := user.NewPostgresUserRepository(pgPool)
	contactRepo := contact.NewPostgresContactRepository(pgPool)
	chatRepo := chat.NewPostgresChatRepository(pgPool)
	ledgerRepo := ledger.NewPostgresRepository(pgPool)
	businessRepo := business.NewPostgresBusinessRepository(pgPool, ledgerRepo)
	pspRepo := psp.NewPostgresRepository(pgPool)

	// Initialize domain services
	smsProvider := &DevSMSProvider{logger: logger}
	authService := auth.NewAuthService(authRepo, valkeyClient, smsProvider, cfg)
	userService := user.NewUserService(userRepo, valkeyClient)
	contactService := contact.NewContactService(contactRepo)
	mediaService := media.NewMediaService(s3Client)
	encService := &encryption.PassthroughEncryption{}
	chatService := chat.NewChatService(chatRepo, eventBus, encService, contactService)
	ledgerService := ledger.NewService(ledgerRepo)
	businessService := business.NewService(businessRepo, ledgerRepo)
	pspService := psp.NewGatewayService(pspRepo)

	// Initialize WebSocket hub for real-time messaging
	hub := chat.NewHub()
	go hub.Run()
	chatService.SetHub(hub)
	logger.Info().Msg("WebSocket Hub running")

	// Initialize handlers
	authHandler := auth.NewAuthHandler(authService, validator)
	userHandler := user.NewUserHandler(userService)
	contactHandler := contact.NewContactHandler(contactService)
	chatHandler := chat.NewChatHandler(chatService)
	mediaHandler := media.NewMediaHandler(mediaService)
	ledgerHandler := ledger.NewHandler(ledgerService)
	businessHandler := business.NewHandler(businessService, validator)
	pspHandler := psp.NewHandler(pspService, validator)

	// Initialize Echo router
	e := echo.New()
	e.HideBanner = true
	e.Validator = validator
	e.HTTPErrorHandler = common.ErrorHandler

	// Global Middlewares
	e.Use(middleware.RequestLogger(logger))
	e.Use(echomiddleware.Recover())
	e.Use(echomiddleware.CORSWithConfig(echomiddleware.CORSConfig{
		AllowOrigins: cfg.CORS.AllowedOrigins,
		AllowMethods: []string{http.MethodGet, http.MethodHead, http.MethodPut, http.MethodPatch, http.MethodPost, http.MethodDelete},
		AllowHeaders: []string{echo.HeaderOrigin, echo.HeaderContentType, echo.HeaderAccept, echo.HeaderAuthorization},
	}))

	// Security Middlewares
	authMiddleware := middleware.AuthMiddleware(valkeyClient, pgPool, cfg.Server.Mode)
	rateLimitMiddleware := middleware.RateLimitMiddleware(valkeyClient, 100, time.Minute)

	// Liveness check: verifies process is alive (instantaneous, 0 dependencies)
	e.GET("/health", func(c echo.Context) error {
		return c.JSON(http.StatusOK, map[string]interface{}{
			"status":    "ok",
			"system":    "MÏÏghO OS Core",
			"version":   "1.0.0",
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		})
	})

	// Readiness check: verifies critical dependencies are reachable (ping only, 0 ledger/financial access)
	e.GET("/ready", func(c echo.Context) error {
		reqCtx := c.Request().Context()
		ctx, cancel := context.WithTimeout(reqCtx, 2*time.Second)
		defer cancel()

		var dbStatus = "ok"
		if err := pgPool.Ping(ctx); err != nil {
			dbStatus = "unavailable"
		}

		var cacheStatus = "ok"
		if err := valkeyClient.HealthCheck(ctx); err != nil {
			cacheStatus = "unavailable"
		}

		if dbStatus != "ok" || cacheStatus != "ok" {
			return c.JSON(http.StatusServiceUnavailable, map[string]interface{}{
				"status": "unavailable",
				"system": "MÏÏghO OS Core",
				"checks": map[string]string{
					"database": dbStatus,
					"cache":    cacheStatus,
				},
				"timestamp": time.Now().UTC().Format(time.RFC3339),
			})
		}

		return c.JSON(http.StatusOK, map[string]interface{}{
			"status": "ready",
			"system": "MÏÏghO OS Core",
			"checks": map[string]string{
				"database": "ok",
				"cache":    "ok",
			},
			"timestamp": time.Now().UTC().Format(time.RFC3339),
		})
	})

	// WebSocket endpoint with auth
	e.GET("/ws", chat.HandleWebSocket(hub, chatService), middleware.WsAuthMiddleware(valkeyClient, pgPool, cfg.Server.Mode))

	// API v1 routes
	apiV1 := e.Group("/api/v1")
	apiV1.Use(rateLimitMiddleware)

	authHandler.RegisterRoutes(apiV1, authMiddleware)
	userHandler.RegisterRoutes(apiV1, authMiddleware)
	contactHandler.RegisterRoutes(apiV1, authMiddleware)
	chatHandler.RegisterRoutes(apiV1, authMiddleware)
	mediaHandler.RegisterRoutes(apiV1, authMiddleware)
	ledgerHandler.RegisterRoutes(apiV1, authMiddleware)
	businessHandler.RegisterRoutes(apiV1, authMiddleware)
	pspHandler.RegisterRoutes(apiV1, authMiddleware)

	// Start server in a goroutine
	serverAddr := fmt.Sprintf("%s:%s", cfg.Server.Host, cfg.Server.Port)
	go func() {
		logger.Info().Msgf("MÏÏghO server listening on %s", serverAddr)
		if err := e.Start(serverAddr); err != nil && err != http.ErrServerClosed {
			logger.Fatal().Err(err).Msg("Failed to start server")
		}
	}()

	// Handle graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, os.Interrupt, syscall.SIGTERM)
	<-quit

	logger.Info().Msg("Shutting down MÏÏghO server...")

	ctxShutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := e.Shutdown(ctxShutdown); err != nil {
		logger.Fatal().Err(err).Msg("Server shutdown failed")
	}

	logger.Info().Msg("MÏÏghO server exited gracefully")
}
