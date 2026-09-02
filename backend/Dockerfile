# Multi-stage Dockerfile for MÏÏghO Backend Core (Go)

# Stage 1: Build binary
FROM --platform=$BUILDPLATFORM golang:alpine AS builder

ARG TARGETOS
ARG TARGETARCH

WORKDIR /src

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Cache Go modules
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build static binary using Go native cross-compilation
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH} go build -ldflags="-s -w" -o /app/server cmd/server/main.go

# Stage 2: Minimal runtime
FROM alpine:3.20

WORKDIR /app

# Install runtime certificates and timezone data
RUN apk --no-cache add ca-certificates tzdata && \
    addgroup -g 10001 -S appgroup && \
    adduser -u 10001 -S appuser -G appgroup

# Copy compiled binary from builder
COPY --from=builder /app/server /app/server

# Security: run as non-root user
USER appuser:appgroup

# Configurable port (default 8080)
EXPOSE 8080

ENTRYPOINT ["/app/server"]
