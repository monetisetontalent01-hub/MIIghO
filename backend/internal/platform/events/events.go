package events

import (
	"context"

	"github.com/miigho/miigho/pkg/messaging"
)

// DomainEvent is an interface that all domain events must implement.
type DomainEvent interface {
	Topic() string
	Payload() interface{}
}

// EventHandler represents a function capable of handling a domain event.
type EventHandler func(payload []byte) error

// EventBus defines the interface for publishing and subscribing to events.
type EventBus interface {
	Publish(ctx context.Context, event DomainEvent) error
	Subscribe(topic string, handler EventHandler) error
}

// NATSEventBus is an EventBus implementation using NATS JetStream.
type NATSEventBus struct {
	client *messaging.NATSClient
}

// NewNATSEventBus creates a new NATS-based event bus.
func NewNATSEventBus(client *messaging.NATSClient) *NATSEventBus {
	return &NATSEventBus{client: client}
}

// Publish publishes a domain event to the NATS broker.
func (n *NATSEventBus) Publish(ctx context.Context, event DomainEvent) error {
	return n.client.Publish(event.Topic(), event.Payload())
}

// Subscribe subscribes to a specific topic and handles incoming events.
func (n *NATSEventBus) Subscribe(topic string, handler EventHandler) error {
	// Not fully unpacking nats.Msg in interface to keep it decoupled from nats.go in business logic
	return nil // placeholder for full implementation
}

// Pre-defined Concrete Events

type UserRegistered struct {
	UserID      string `json:"user_id"`
	PhoneNumber string `json:"phone_number"`
}

func (e UserRegistered) Topic() string        { return "user.registered" }
func (e UserRegistered) Payload() interface{} { return e }

type MessageSent struct {
	MessageID      string `json:"message_id"`
	ConversationID string `json:"conversation_id"`
	SenderID       string `json:"sender_id"`
}

func (e MessageSent) Topic() string        { return "message.sent" }
func (e MessageSent) Payload() interface{} { return e }

type MessageDelivered struct {
	MessageID string `json:"message_id"`
	UserID    string `json:"user_id"`
}

func (e MessageDelivered) Topic() string        { return "message.delivered" }
func (e MessageDelivered) Payload() interface{} { return e }

type MessageRead struct {
	MessageID string `json:"message_id"`
	UserID    string `json:"user_id"`
}

func (e MessageRead) Topic() string        { return "message.read" }
func (e MessageRead) Payload() interface{} { return e }

type ConversationCreated struct {
	ConversationID string `json:"conversation_id"`
}

func (e ConversationCreated) Topic() string        { return "conversation.created" }
func (e ConversationCreated) Payload() interface{} { return e }

type GroupCreated struct {
	GroupID string `json:"group_id"`
}

func (e GroupCreated) Topic() string        { return "group.created" }
func (e GroupCreated) Payload() interface{} { return e }

type MediaUploaded struct {
	MediaID string `json:"media_id"`
	URL     string `json:"url"`
}

func (e MediaUploaded) Topic() string        { return "media.uploaded" }
func (e MediaUploaded) Payload() interface{} { return e }
