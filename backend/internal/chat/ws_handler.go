package chat

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/platform/identity"
	"github.com/rs/zerolog/log"
)

var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		return true // Allow all for MVP
	},
}

const (
	writeWait      = 10 * time.Second
	pongWait       = 60 * time.Second
	pingPeriod     = (pongWait * 9) / 10
	maxMessageSize = 512 * 1024
)

func HandleWebSocket(hub *Hub, service *ChatService) echo.HandlerFunc {
	return func(c echo.Context) error {
		userIdent, err := identity.GetUserIdentity(c)
		if err != nil {
			return echo.NewHTTPError(http.StatusUnauthorized)
		}

		ws, err := upgrader.Upgrade(c.Response(), c.Request(), nil)
		if err != nil {
			return err
		}

		conn := &Connection{
			ws:     ws,
			send:   make(chan []byte, 256),
			userID: userIdent.ID,
		}
		hub.register <- conn

		go writePump(conn)
		go readPump(conn, hub, service)

		return nil
	}
}

func readPump(conn *Connection, hub *Hub, service *ChatService) {
	defer func() {
		hub.unregister <- conn
		conn.ws.Close()
	}()
	conn.ws.SetReadLimit(maxMessageSize)
	conn.ws.SetReadDeadline(time.Now().Add(pongWait))
	conn.ws.SetPongHandler(func(string) error { conn.ws.SetReadDeadline(time.Now().Add(pongWait)); return nil })

	for {
		_, message, err := conn.ws.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Error().Err(err).Msg("WebSocket read error")
			}
			break
		}

		// Parse inbound client envelopes
		var env WsEnvelope
		if err := json.Unmarshal(message, &env); err == nil {
			switch env.Type {
			case "ping":
				pongEnv := WsEnvelope{
					Type:      "pong",
					Timestamp: time.Now(),
				}
				if payload, mErr := json.Marshal(pongEnv); mErr == nil {
					select {
					case conn.send <- payload:
					default:
					}
				}

			case "typing":
				if env.ConversationID != "" && service != nil {
					if convID, parseErr := uuid.Parse(env.ConversationID); parseErr == nil {
						// Broadcast typing indicator to other conversation members
						isTyping := true
						if val, ok := env.Data.(bool); ok {
							isTyping = val
						}
						typingPayload, _ := json.Marshal(WsEnvelope{
							Type:           "user.typing",
							ConversationID: env.ConversationID,
							UserID:         conn.userID.String(),
							Data: map[string]interface{}{
								"user_id":   conn.userID.String(),
								"is_typing": isTyping,
							},
							Timestamp: time.Now(),
						})

						members, memErr := service.repo.GetConversationMembers(context.Background(), convID)
						if memErr == nil {
							var recipientMembers []uuid.UUID
							for _, m := range members {
								if m != conn.userID {
									recipientMembers = append(recipientMembers, m)
								}
							}
							hub.BroadcastToUsers(recipientMembers, typingPayload)
						}
					}
				}
			}
		}
	}
}

func writePump(conn *Connection) {
	ticker := time.NewTicker(pingPeriod)
	defer func() {
		ticker.Stop()
		conn.ws.Close()
	}()
	for {
		select {
		case message, ok := <-conn.send:
			conn.ws.SetWriteDeadline(time.Now().Add(writeWait))
			if !ok {
				conn.ws.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			w, err := conn.ws.NextWriter(websocket.TextMessage)
			if err != nil {
				return
			}
			w.Write(message)
			if err := w.Close(); err != nil {
				return
			}
		case <-ticker.C:
			conn.ws.SetWriteDeadline(time.Now().Add(writeWait))
			if err := conn.ws.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}
