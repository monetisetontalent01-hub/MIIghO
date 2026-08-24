package encryption

import (
	"errors"

	"github.com/google/uuid"
)

// EncryptionMetadata contains metadata needed to decrypt the message.
type EncryptionMetadata struct {
	Algorithm   string `json:"algorithm"`
	KeyID       string `json:"key_id"`
	SenderKeyID string `json:"sender_key_id"`
	Nonce       []byte `json:"nonce"`
	Version     int    `json:"version"`
}

// EncryptionService defines the interface for end-to-end encryption operations.
type EncryptionService interface {
	Encrypt(plaintext []byte, recipientID uuid.UUID) (ciphertext []byte, metadata *EncryptionMetadata, err error)
	Decrypt(ciphertext []byte, metadata *EncryptionMetadata) (plaintext []byte, err error)
}

// Key structures for Signal Protocol implementation in Phase 2
type PreKeyBundle struct {
	IdentityKey []byte
	SignedKey   []byte
	Signature   []byte
	OneTimeKeys [][]byte
}

type PreKey struct {
	ID  uint32
	Key []byte
}

type IdentityKey struct {
	Key []byte
}

// KeyStore interface defining operations on E2E keys.
type KeyStore interface {
	StorePreKeyBundle(userID uuid.UUID, bundle *PreKeyBundle) error
	GetPreKeyBundle(userID uuid.UUID) (*PreKeyBundle, error)
	ConsumeOneTimePreKey(userID uuid.UUID) (*PreKey, error)
}

// PassthroughEncryption implements EncryptionService but returns plaintext as-is.
// This is the MVP implementation before full E2E is introduced in Phase 2.
type PassthroughEncryption struct{}

func (p *PassthroughEncryption) Encrypt(plaintext []byte, recipientID uuid.UUID) ([]byte, *EncryptionMetadata, error) {
	if plaintext == nil {
		return nil, nil, errors.New("plaintext cannot be nil")
	}
	metadata := &EncryptionMetadata{
		Algorithm: "none",
		Version:   1,
	}
	return plaintext, metadata, nil
}

func (p *PassthroughEncryption) Decrypt(ciphertext []byte, metadata *EncryptionMetadata) ([]byte, error) {
	if ciphertext == nil {
		return nil, errors.New("ciphertext cannot be nil")
	}
	return ciphertext, nil
}
