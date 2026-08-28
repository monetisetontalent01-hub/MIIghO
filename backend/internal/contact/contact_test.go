package contact

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/google/uuid"
	"github.com/labstack/echo/v4"
	"github.com/miigho/miigho/internal/platform/identity"
)

type mockContactRepo struct {
	users []ContactUser
}

func (m *mockContactRepo) BatchFindUsersByPhone(ctx context.Context, phones []string) ([]MatchedContact, error) {
	var matched []MatchedContact
	for _, p := range phones {
		for _, u := range m.users {
			if u.PhoneNumber == p {
				matched = append(matched, MatchedContact{PhoneNumber: p, UserID: u.ID})
			}
		}
	}
	return matched, nil
}

func (m *mockContactRepo) UpsertContact(ctx context.Context, contact *Contact) error {
	return nil
}

func (m *mockContactRepo) ListContacts(ctx context.Context, ownerID uuid.UUID) ([]*Contact, error) {
	return []*Contact{}, nil
}

func (m *mockContactRepo) ListContactUsers(ctx context.Context, ownerID uuid.UUID) ([]ContactUser, error) {
	return m.users, nil
}

func (m *mockContactRepo) SearchUsers(ctx context.Context, currentUserID uuid.UUID, query string) ([]ContactUser, error) {
	var res []ContactUser
	for _, u := range m.users {
		if u.ID != currentUserID && (u.PhoneNumber == query || u.DisplayName == query) {
			res = append(res, u)
		}
	}
	return res, nil
}

func (m *mockContactRepo) UpdateContactStatus(ctx context.Context, ownerID, userID uuid.UUID, isBlocked, isFav bool) error {
	return nil
}

func TestContactHandler_SearchContacts(t *testing.T) {
	currentUserID := uuid.New()
	targetUserID := uuid.New()

	repo := &mockContactRepo{
		users: []ContactUser{
			{
				ID:           targetUserID,
				PhoneNumber:  "+2250506169325",
				DisplayName:  "Mamadou Koné",
				IsMiighoUser: true,
			},
		},
	}
	service := NewContactService(repo)
	handler := NewContactHandler(service)

	e := echo.New()
	req := httptest.NewRequest(http.MethodGet, "/contacts/search?q=+2250506169325", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	// Set auth identity context
	identity.SetUserIdentity(c, &identity.UserIdentity{
		ID:          currentUserID,
		PhoneNumber: "+243991440019",
	})

	if err := handler.searchContacts(c); err != nil {
		t.Fatalf("searchContacts returned error: %v", err)
	}

	if rec.Code != http.StatusOK {
		t.Fatalf("expected HTTP 200, got %d", rec.Code)
	}
}
