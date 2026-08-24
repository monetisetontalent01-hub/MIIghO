package chat

import (
	"net/http"
	"time"

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

func HandleWebSocket(hub *Hub) echo.HandlerFunc {
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
		go readPump(conn, hub)

		return nil
	}
}

func readPump(conn *Connection, hub *Hub) {
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
		// In a real app, unmarshal protobuf WsEnvelope here and dispatch
		_ = message
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
			w, err := conn.ws.NextWriter(websocket.BinaryMessage)
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
