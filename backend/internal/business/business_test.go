package business

import (
	"context"
	"errors"
	"testing"

	"github.com/google/uuid"
	"github.com/miigho/miigho/internal/ledger"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func setupTestBusinessService(t *testing.T) (*Service, *MemoryBusinessRepository, *ledger.MemoryRepository) {
	ledgerRepo := ledger.NewMemoryRepository()
	bizRepo := NewMemoryBusinessRepository(ledgerRepo)
	svc := NewService(bizRepo, ledgerRepo)
	return svc, bizRepo, ledgerRepo
}

// Test 1: Business Creation & Attributes
func TestBusiness_Create(t *testing.T) {
	svc, _, _ := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	req := &CreateBusinessRequest{
		LegalName:    "Société Sahel Agro SARL",
		DisplayName:  "Sahel Agro",
		BusinessType: "AGRICULTURE",
		Country:      "CI",
		Currency:     "FCFA",
		Phone:        "+22507000001",
		Email:        "contact@sahelagro.ci",
	}

	detail, err := svc.CreateBusiness(ctx, ownerID, req)
	require.NoError(t, err)
	require.NotNil(t, detail)
	assert.Equal(t, "Société Sahel Agro SARL", detail.Business.LegalName)
	assert.Equal(t, "Sahel Agro", detail.Business.DisplayName)
	assert.Equal(t, StatusActive, detail.Business.Status)
	assert.Equal(t, ownerID, detail.Business.OwnerUserID)
	assert.Equal(t, "FCFA", detail.Currency)
}

// Test 2: Owner Member Auto-Assignment
func TestBusiness_OwnerCreated(t *testing.T) {
	svc, _, _ := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	detail, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Pharmacie Espoir",
		DisplayName:  "Pharmacie Espoir",
		BusinessType: "HEALTHCARE",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)
	assert.Equal(t, RoleOwner, detail.UserRole)
	require.Len(t, detail.Members, 1)
	assert.Equal(t, ownerID, detail.Members[0].UserID)
	assert.Equal(t, RoleOwner, detail.Members[0].Role)
	assert.Equal(t, MemberStatusActive, detail.Members[0].Status)
}

// Test 3 & 4: Business Account & Ledger Account Linked
func TestBusiness_AccountAndLedgerLinked(t *testing.T) {
	svc, _, ledgerRepo := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	detail, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Boutique Artisanat Grand Bassam",
		DisplayName:  "Artisanat Bassam",
		BusinessType: "RETAIL",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)
	require.NotNil(t, detail.Account)
	assert.Equal(t, detail.Business.ID, detail.Account.BusinessID)
	assert.NotEqual(t, uuid.Nil, detail.Account.LedgerAccountID)

	// Verify ledger account exists in double-entry ledger
	ledgerAcc, err := ledgerRepo.GetAccount(ctx, detail.Account.LedgerAccountID)
	require.NoError(t, err)
	assert.Equal(t, ledger.Asset, ledgerAcc.AccountType)
	assert.Equal(t, "FCFA", ledgerAcc.Currency)
	assert.Contains(t, ledgerAcc.Name, "Artisanat Bassam")
}

// Test 5: Financial Integrity (Zero Money Creation / Zero Entries)
func TestBusiness_FinancialIntegrity(t *testing.T) {
	svc, _, ledgerRepo := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	detail, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Logistique Express CI",
		DisplayName:  "Logistique Express",
		BusinessType: "LOGISTICS",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	// Derived balance must be strictly 0
	bal, err := ledgerRepo.GetBalance(ctx, detail.Account.LedgerAccountID)
	require.NoError(t, err)
	assert.Equal(t, int64(0), bal)
	assert.Equal(t, int64(0), detail.AvailableBalance)

	// Statement must contain exactly 0 postings for this account
	postings, err := ledgerRepo.GetPostingsForAccount(ctx, detail.Account.LedgerAccountID, 100, 0)
	require.NoError(t, err)
	assert.Empty(t, postings, "New business must have strictly zero ledger postings")
}

// Test 6: Duplicate Member Prevention
func TestBusiness_DuplicateMember(t *testing.T) {
	svc, _, _ := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	detail, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Café de Cocody",
		DisplayName:  "Café Cocody",
		BusinessType: "RESTAURANT",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	memberUserID := uuid.New()
	_, err = svc.AddMember(ctx, detail.Business.ID, ownerID, &AddMemberRequest{
		UserID: memberUserID,
		Role:   RoleManager,
	})
	require.NoError(t, err)

	// Attempt adding the same member again
	_, err = svc.AddMember(ctx, detail.Business.ID, ownerID, &AddMemberRequest{
		UserID: memberUserID,
		Role:   RoleCashier,
	})
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrDuplicateMember))
}

// Test 7: Authorization Matrix (Member vs Non-Member & Roles)
func TestBusiness_Authorization(t *testing.T) {
	svc, _, _ := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	strangerID := uuid.New()
	cashierID := uuid.New()

	detail, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Textiles Africains",
		DisplayName:  "Textiles Africains",
		BusinessType: "FASHION",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	// Add cashier
	_, err = svc.AddMember(ctx, detail.Business.ID, ownerID, &AddMemberRequest{
		UserID: cashierID,
		Role:   RoleCashier,
	})
	require.NoError(t, err)

	// 1. Stranger cannot view business
	_, err = svc.GetBusiness(ctx, detail.Business.ID, strangerID)
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrUnauthorizedAccess))

	// 2. Cashier cannot update business info
	newName := "New Name"
	_, err = svc.UpdateBusiness(ctx, detail.Business.ID, cashierID, &UpdateBusinessRequest{
		DisplayName: &newName,
	})
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrInsufficientPermission))

	// 3. Cashier cannot add new members
	_, err = svc.AddMember(ctx, detail.Business.ID, cashierID, &AddMemberRequest{
		UserID: uuid.New(),
		Role:   RoleCashier,
	})
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrInsufficientPermission))

	// 4. Owner can update business info
	updated, err := svc.UpdateBusiness(ctx, detail.Business.ID, ownerID, &UpdateBusinessRequest{
		DisplayName: &newName,
	})
	require.NoError(t, err)
	assert.Equal(t, "New Name", updated.DisplayName)
}

// Test 8: Business Update
func TestBusiness_Update(t *testing.T) {
	svc, _, _ := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	detail, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Garage Moderne Abidjan",
		DisplayName:  "Garage Moderne",
		BusinessType: "AUTOMOTIVE",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	newPhone := "+22507099999"
	newEmail := "garage@moderne.ci"
	updated, err := svc.UpdateBusiness(ctx, detail.Business.ID, ownerID, &UpdateBusinessRequest{
		Phone: &newPhone,
		Email: &newEmail,
	})
	require.NoError(t, err)
	assert.Equal(t, newPhone, updated.Phone)
	assert.Equal(t, newEmail, updated.Email)
}

// Test 9: Business Suspended Behavior
func TestBusiness_Suspended(t *testing.T) {
	svc, _, _ := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	detail, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Import Export Sahel",
		DisplayName:  "Import Export Sahel",
		BusinessType: "IMPORT_EXPORT",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	// Suspend business
	suspendedStatus := StatusSuspended
	_, err = svc.UpdateBusiness(ctx, detail.Business.ID, ownerID, &UpdateBusinessRequest{
		Status: &suspendedStatus,
	})
	require.NoError(t, err)

	// Adding members must be blocked when suspended
	_, err = svc.AddMember(ctx, detail.Business.ID, ownerID, &AddMemberRequest{
		UserID: uuid.New(),
		Role:   RoleManager,
	})
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrInsufficientPermission))

	// Viewing business details for audit remains permitted
	viewed, err := svc.GetBusiness(ctx, detail.Business.ID, ownerID)
	require.NoError(t, err)
	assert.Equal(t, StatusSuspended, viewed.Business.Status)
}

// Test 10: Business Closed (Data Preserved, No Deletion)
func TestBusiness_Closed(t *testing.T) {
	svc, bizRepo, ledgerRepo := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	detail, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Librairie Ancienne",
		DisplayName:  "Librairie Ancienne",
		BusinessType: "BOOKSTORE",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	// Close business
	closedStatus := StatusClosed
	_, err = svc.UpdateBusiness(ctx, detail.Business.ID, ownerID, &UpdateBusinessRequest{
		Status: &closedStatus,
	})
	require.NoError(t, err)

	// Verify all records still exist for audit
	b, err := bizRepo.GetBusiness(ctx, detail.Business.ID)
	require.NoError(t, err)
	assert.Equal(t, StatusClosed, b.Status)

	acc, err := bizRepo.GetBusinessAccount(ctx, detail.Business.ID)
	require.NoError(t, err)
	assert.NotNil(t, acc)

	ledgerAcc, err := ledgerRepo.GetAccount(ctx, acc.LedgerAccountID)
	require.NoError(t, err)
	assert.NotNil(t, ledgerAcc)
}

// Test 11: Rollback on Failure
type failingLedgerRepo struct {
	ledger.Repository
}

func (f *failingLedgerRepo) CreateAccount(ctx context.Context, account *ledger.LedgerAccount) error {
	return errors.New("simulated database failure on ledger account creation")
}

func TestBusiness_Rollback(t *testing.T) {
	failLedger := &failingLedgerRepo{Repository: ledger.NewMemoryRepository()}
	bizRepo := NewMemoryBusinessRepository(failLedger)
	svc := NewService(bizRepo, failLedger)
	ctx := context.Background()

	ownerID := uuid.New()
	_, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Doomed Business",
		DisplayName:  "Doomed",
		BusinessType: "SERVICES",
		Country:      "CI",
		Currency:     "FCFA",
	})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "simulated database failure")

	// Verify zero businesses or members exist in repo
	summaries, err := bizRepo.ListBusinessesForUser(ctx, ownerID)
	require.NoError(t, err)
	assert.Empty(t, summaries)
}

// Test 12: Multiple Businesses Per User
func TestBusiness_MultipleBusinessesPerUser(t *testing.T) {
	svc, _, _ := setupTestBusinessService(t)
	ctx := context.Background()

	userA := uuid.New()

	b1, err := svc.CreateBusiness(ctx, userA, &CreateBusinessRequest{
		LegalName:    "Business A1 SARL",
		DisplayName:  "A1 Store",
		BusinessType: "RETAIL",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	b2, err := svc.CreateBusiness(ctx, userA, &CreateBusinessRequest{
		LegalName:    "Business A2 SAS",
		DisplayName:  "A2 Consulting",
		BusinessType: "CONSULTING",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	b3, err := svc.CreateBusiness(ctx, userA, &CreateBusinessRequest{
		LegalName:    "Business A3 EURL",
		DisplayName:  "A3 Tech",
		BusinessType: "TECH",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	// Verify 3 distinct businesses and accounts
	assert.NotEqual(t, b1.Business.ID, b2.Business.ID)
	assert.NotEqual(t, b2.Business.ID, b3.Business.ID)
	assert.NotEqual(t, b1.Account.LedgerAccountID, b2.Account.LedgerAccountID)

	summaries, err := svc.ListUserBusinesses(ctx, userA)
	require.NoError(t, err)
	assert.Len(t, summaries, 3)
}

// Test 13: Multiple Members & Roles Management
func TestBusiness_MultipleMembers(t *testing.T) {
	svc, _, _ := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	adminID := uuid.New()
	cashierID := uuid.New()

	detail, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Supermarché Plateau",
		DisplayName:  "Supermarché Plateau",
		BusinessType: "RETAIL",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	// Add Admin
	adminMember, err := svc.AddMember(ctx, detail.Business.ID, ownerID, &AddMemberRequest{
		UserID: adminID,
		Role:   RoleAdmin,
	})
	require.NoError(t, err)
	assert.Equal(t, RoleAdmin, adminMember.Role)

	// Add Cashier
	cashierMember, err := svc.AddMember(ctx, detail.Business.ID, ownerID, &AddMemberRequest{
		UserID: cashierID,
		Role:   RoleCashier,
	})
	require.NoError(t, err)
	assert.Equal(t, RoleCashier, cashierMember.Role)

	// Admin promotes cashier to Manager
	updatedMember, err := svc.UpdateMemberRole(ctx, detail.Business.ID, adminID, cashierMember.ID, &UpdateMemberRoleRequest{
		Role: RoleManager,
	})
	require.NoError(t, err)
	assert.Equal(t, RoleManager, updatedMember.Role)

	// Admin removes cashier
	err = svc.RemoveMember(ctx, detail.Business.ID, adminID, cashierMember.ID)
	require.NoError(t, err)

	// Verify member list count is 2 (Owner + Admin)
	members, err := svc.ListMembers(ctx, detail.Business.ID, ownerID)
	require.NoError(t, err)
	assert.Len(t, members, 2)
}

// Test 14: Cross-Business Isolation
func TestBusiness_Isolation(t *testing.T) {
	svc, _, _ := setupTestBusinessService(t)
	ctx := context.Background()

	userA := uuid.New()
	userB := uuid.New()

	bizA, err := svc.CreateBusiness(ctx, userA, &CreateBusinessRequest{
		LegalName:    "Business A",
		DisplayName:  "Business A",
		BusinessType: "RETAIL",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	bizB, err := svc.CreateBusiness(ctx, userB, &CreateBusinessRequest{
		LegalName:    "Business B",
		DisplayName:  "Business B",
		BusinessType: "RETAIL",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	// User A -> Business B => Denied
	_, err = svc.GetBusiness(ctx, bizB.Business.ID, userA)
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrUnauthorizedAccess))

	// User B -> Business A => Denied
	_, err = svc.GetBusiness(ctx, bizA.Business.ID, userB)
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrUnauthorizedAccess))
}

// Test 15: Cannot Remove Last Owner
func TestBusiness_CannotRemoveLastOwner(t *testing.T) {
	svc, _, _ := setupTestBusinessService(t)
	ctx := context.Background()

	ownerID := uuid.New()
	detail, err := svc.CreateBusiness(ctx, ownerID, &CreateBusinessRequest{
		LegalName:    "Unique Owner Enterprise",
		DisplayName:  "Unique Owner",
		BusinessType: "SERVICES",
		Country:      "CI",
		Currency:     "FCFA",
	})
	require.NoError(t, err)

	ownerMemberID := detail.Members[0].ID

	// Attempt removing the only owner
	err = svc.RemoveMember(ctx, detail.Business.ID, ownerID, ownerMemberID)
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrCannotRemoveOwner))

	// Attempt demoting the only owner to Cashier
	_, err = svc.UpdateMemberRole(ctx, detail.Business.ID, ownerID, ownerMemberID, &UpdateMemberRoleRequest{
		Role: RoleCashier,
	})
	assert.Error(t, err)
	assert.True(t, errors.Is(err, ErrCannotRemoveOwner))
}
