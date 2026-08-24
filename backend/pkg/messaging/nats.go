package messaging

import (
	"encoding/json"
	"fmt"
	"time"

	"github.com/nats-io/nats.go"
)

// NATSClient wraps NATS connection and JetStream context.
type NATSClient struct {
	nc *nats.Conn
	js nats.JetStreamContext
}

// EventEnvelope represents the standard structure for a domain event payload.
type EventEnvelope struct {
	ID        string      `json:"id"`
	Subject   string      `json:"subject"`
	Source    string      `json:"source"`
	Timestamp time.Time   `json:"timestamp"`
	Data      interface{} `json:"data"`
}

// NewNATSClient connects to NATS and returns a NATSClient.
func NewNATSClient(url string) (*NATSClient, error) {
	nc, err := nats.Connect(url)
	if err != nil {
		return nil, fmt.Errorf("failed to connect to NATS: %w", err)
	}

	js, err := nc.JetStream()
	if err != nil {
		nc.Close()
		return nil, fmt.Errorf("failed to get JetStream context: %w", err)
	}

	return &NATSClient{
		nc: nc,
		js: js,
	}, nil
}

// Close closes the NATS connection.
func (n *NATSClient) Close() {
	if n.nc != nil {
		n.nc.Close()
	}
}

// EnsureStream creates a JetStream stream if it does not exist.
func (n *NATSClient) EnsureStream(name string, subjects []string) error {
	stream, _ := n.js.StreamInfo(name)
	if stream == nil {
		_, err := n.js.AddStream(&nats.StreamConfig{
			Name:     name,
			Subjects: subjects,
		})
		if err != nil {
			return fmt.Errorf("failed to create stream: %w", err)
		}
	}
	return nil
}

// Publish publishes an event to a subject.
func (n *NATSClient) Publish(subject string, data interface{}) error {
	payload, err := json.Marshal(data)
	if err != nil {
		return fmt.Errorf("failed to marshal event data: %w", err)
	}

	_, err = n.js.Publish(subject, payload)
	if err != nil {
		return fmt.Errorf("failed to publish message to %s: %w", subject, err)
	}

	return nil
}

// Subscribe subscribes to a subject and processes messages using the handler.
func (n *NATSClient) Subscribe(subject string, handler func(msg *nats.Msg)) error {
	_, err := n.js.Subscribe(subject, handler)
	if err != nil {
		return fmt.Errorf("failed to subscribe to %s: %w", subject, err)
	}
	return nil
}
