package chat

import (
	"sync"

	"github.com/google/uuid"
	"github.com/gorilla/websocket"
	"github.com/rs/zerolog/log"
)

type Connection struct {
	ws     *websocket.Conn
	send   chan []byte
	userID uuid.UUID
}

type Hub struct {
	connections map[uuid.UUID][]*Connection
	register    chan *Connection
	unregister  chan *Connection
	mu          sync.RWMutex
}

func NewHub() *Hub {
	return &Hub{
		connections: make(map[uuid.UUID][]*Connection),
		register:    make(chan *Connection),
		unregister:  make(chan *Connection),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case conn := <-h.register:
			h.mu.Lock()
			h.connections[conn.userID] = append(h.connections[conn.userID], conn)
			h.mu.Unlock()
			log.Info().Str("user_id", conn.userID.String()).Msg("User connected")

		case conn := <-h.unregister:
			h.mu.Lock()
			conns := h.connections[conn.userID]
			for i, c := range conns {
				if c == conn {
					h.connections[conn.userID] = append(conns[:i], conns[i+1:]...)
					break
				}
			}
			if len(h.connections[conn.userID]) == 0 {
				delete(h.connections, conn.userID)
			}
			h.mu.Unlock()
			close(conn.send)
			log.Info().Str("user_id", conn.userID.String()).Msg("User disconnected")
		}
	}
}

func (h *Hub) BroadcastToUser(userID uuid.UUID, message []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	for _, conn := range h.connections[userID] {
		select {
		case conn.send <- message:
		default:
			// Buffer full, drop or handle
		}
	}
}

func (h *Hub) BroadcastToUsers(userIDs []uuid.UUID, message []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()

	for _, uid := range userIDs {
		for _, conn := range h.connections[uid] {
			select {
			case conn.send <- message:
			default:
			}
		}
	}
}

func (h *Hub) IsUserOnline(userID uuid.UUID) bool {
	h.mu.RLock()
	defer h.mu.RUnlock()
	return len(h.connections[userID]) > 0
}
