package ledger

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
)

// Service provides high-level financial operations powered by the double-entry ledger.
type Service struct {
	repo Repository
}

func NewService(repo Repository) *Service {
	s := &Service{repo: repo}
	s.seedSandboxDemoData()
	return s
}

// seedSandboxDemoData creates initial double-entry journal entries for the demo user if needed
func (s *Service) seedSandboxDemoData() {
	ctx := context.Background()
	demoUserID, err := uuid.Parse("00000000-0000-0000-0000-000000000001")
	if err != nil {
		demoUserID = uuid.New()
	}
	aminaUserID, _ := uuid.Parse("00000000-0000-0000-0000-000000000002")

	// Ensure accounts exist
	userAcc, _ := s.GetOrCreateUserAccount(ctx, demoUserID, "FCFA", "Compte Principal (Mamadou Koné)")
	aminaAcc, _ := s.GetOrCreateUserAccount(ctx, aminaUserID, "FCFA", "Compte Amina Diallo")
	momoPool, _ := s.repo.GetSystemAccount(ctx, "MoMo Settlement Pool", "FCFA", Liability)
	escrowPool, _ := s.repo.GetSystemAccount(ctx, "Marketplace Escrow Account", "FCFA", Liability)

	bal, _ := s.repo.GetBalance(ctx, userAcc.ID)
	if bal == 0 {
		// 1. Recharge Wave CI (+25 000 FCFA):
		// Debit User Asset (+25,000), Credit MoMo Liability (+25,000)
		entry1 := &JournalEntry{
			ID:              uuid.New(),
			TransactionType: MoMoCashIn,
			ReferenceID:     "WAVE-CI-982401",
			Description:     "Recharge Wave CI (Sandbox)",
			CreatedAt:       time.Now().UTC().Add(-3 * time.Hour),
		}
		p1 := []*LedgerPosting{
			{ID: uuid.New(), JournalEntryID: entry1.ID, AccountID: userAcc.ID, Amount: 25000, IsCredit: false, CreatedAt: entry1.CreatedAt}, // Debit user
			{ID: uuid.New(), JournalEntryID: entry1.ID, AccountID: momoPool.ID, Amount: 25000, IsCredit: true, CreatedAt: entry1.CreatedAt}, // Credit momo
		}
		_ = s.repo.PostJournalEntry(ctx, entry1, p1, "seed-tx-01")

		// 2. Transfert de Amina Diallo (+30 000 FCFA):
		// Debit User Asset (+30,000), Credit Amina Asset (-30,000)
		// First give Amina 30k from momo pool so she has balance
		entryAminaSeed := &JournalEntry{
			ID:              uuid.New(),
			TransactionType: MoMoCashIn,
			ReferenceID:     "SEED-AMINA-01",
			Description:     "Seed Amina Wallet",
			CreatedAt:       time.Now().UTC().Add(-24 * time.Hour),
		}
		pAmina := []*LedgerPosting{
			{ID: uuid.New(), JournalEntryID: entryAminaSeed.ID, AccountID: aminaAcc.ID, Amount: 30000, IsCredit: false, CreatedAt: entryAminaSeed.CreatedAt},
			{ID: uuid.New(), JournalEntryID: entryAminaSeed.ID, AccountID: momoPool.ID, Amount: 30000, IsCredit: true, CreatedAt: entryAminaSeed.CreatedAt},
		}
		_ = s.repo.PostJournalEntry(ctx, entryAminaSeed, pAmina, "seed-tx-02-pre")

		entry2 := &JournalEntry{
			ID:              uuid.New(),
			TransactionType: P2PTransfer,
			ReferenceID:     "P2P-AMINA-982402",
			Description:     "Transfert reçu de Amina Diallo",
			CreatedAt:       time.Now().UTC().Add(-24 * time.Hour),
		}
		p2 := []*LedgerPosting{
			{ID: uuid.New(), JournalEntryID: entry2.ID, AccountID: userAcc.ID, Amount: 30000, IsCredit: false, CreatedAt: entry2.CreatedAt}, // Debit user (+30,000)
			{ID: uuid.New(), JournalEntryID: entry2.ID, AccountID: aminaAcc.ID, Amount: 30000, IsCredit: true, CreatedAt: entry2.CreatedAt},  // Credit Amina (-30,000)
		}
		_ = s.repo.PostJournalEntry(ctx, entry2, p2, "seed-tx-02")

		// 3. Commande Market Escrow (-10 000 FCFA):
		// Credit User Asset (-10,000), Debit Escrow Liability (+10,000)
		entry3 := &JournalEntry{
			ID:              uuid.New(),
			TransactionType: MarketplaceEscrow,
			ReferenceID:     "MKT-ESCROW-982403",
			Description:     "Commande Market (Escrow) - Boutique Artisanat Sahel",
			CreatedAt:       time.Now().UTC().Add(-48 * time.Hour),
		}
		p3 := []*LedgerPosting{
			{ID: uuid.New(), JournalEntryID: entry3.ID, AccountID: userAcc.ID, Amount: 10000, IsCredit: true, CreatedAt: entry3.CreatedAt},     // Credit user (-10,000)
			{ID: uuid.New(), JournalEntryID: entry3.ID, AccountID: escrowPool.ID, Amount: 10000, IsCredit: false, CreatedAt: entry3.CreatedAt}, // Debit escrow
		}
		_ = s.repo.PostJournalEntry(ctx, entry3, p3, "seed-tx-03")

		// Total balance derived: 25000 + 30000 - 10000 = 45000 FCFA
	}
}

// CreateAccount implements LedgerService
func (s *Service) CreateAccount(ctx context.Context, userID *uuid.UUID, currency string, accountType AccountType) (*LedgerAccount, error) {
	name := fmt.Sprintf("Account-%s", currency)
	if userID != nil {
		name = fmt.Sprintf("User Wallet (%s)", currency)
	}
	acc := &LedgerAccount{
		ID:          uuid.New(),
		UserID:      userID,
		Currency:    currency,
		AccountType: accountType,
		Name:        name,
		CreatedAt:   time.Now().UTC(),
	}
	if err := s.repo.CreateAccount(ctx, acc); err != nil {
		return nil, err
	}
	return acc, nil
}

// GetOrCreateUserAccount returns the user's primary asset account for the given currency.
func (s *Service) GetOrCreateUserAccount(ctx context.Context, userID uuid.UUID, currency string, optionalName ...string) (*LedgerAccount, error) {
	acc, err := s.repo.GetAccountByUserID(ctx, userID, currency)
	if err == nil {
		return acc, nil
	}

	name := fmt.Sprintf("Portefeuille Principal (%s)", currency)
	if len(optionalName) > 0 && optionalName[0] != "" {
		name = optionalName[0]
	}

	newAcc := &LedgerAccount{
		ID:          uuid.New(),
		UserID:      &userID,
		Currency:    currency,
		AccountType: Asset,
		Name:        name,
		CreatedAt:   time.Now().UTC(),
	}
	if err := s.repo.CreateAccount(ctx, newAcc); err != nil {
		return nil, err
	}
	return newAcc, nil
}

// PostEntry implements LedgerService
func (s *Service) PostEntry(ctx context.Context, entry *JournalEntry, postings []*LedgerPosting) error {
	return s.repo.PostJournalEntry(ctx, entry, postings, "")
}

// GetBalance implements LedgerService
func (s *Service) GetBalance(ctx context.Context, accountID uuid.UUID) (int64, error) {
	return s.repo.GetBalance(ctx, accountID)
}

// GetStatement implements LedgerService
func (s *Service) GetStatement(ctx context.Context, accountID uuid.UUID, from, to time.Time, cursor string, limit int) ([]*LedgerPosting, string, error) {
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	postings, err := s.repo.GetStatement(ctx, accountID, from, to, limit, 0)
	if err != nil {
		return nil, "", err
	}
	return postings, "", nil
}

// GetWalletSummary returns the derived balance and statistics for the user's wallet.
func (s *Service) GetWalletSummary(ctx context.Context, userID uuid.UUID, currency string) (*WalletSummary, error) {
	acc, err := s.GetOrCreateUserAccount(ctx, userID, currency)
	if err != nil {
		return nil, err
	}

	balance, err := s.repo.GetBalance(ctx, acc.ID)
	if err != nil {
		return nil, err
	}

	// Calculate incoming and outgoing
	postings, err := s.repo.GetPostingsForAccount(ctx, acc.ID, 100, 0)
	if err != nil {
		return nil, err
	}

	var incoming int64
	var outgoing int64
	for _, p := range postings {
		if !p.IsCredit { // Debit increases asset (incoming)
			incoming += p.Amount
		} else { // Credit decreases asset (outgoing)
			outgoing += p.Amount
		}
	}

	return &WalletSummary{
		AccountID:        acc.ID,
		UserID:           userID,
		MiighoID:         fmt.Sprintf("MG-%s", strings.ToUpper(userID.String()[:8])),
		Currency:         currency,
		AvailableBalance: balance,
		PendingBalance:   0,
		TotalIncoming:    incoming,
		TotalOutgoing:    outgoing,
		IsSandbox:        true,
		LastUpdated:      time.Now().UTC(),
	}, nil
}

// TransferP2P performs an atomic double-entry P2P transfer between two users.
func (s *Service) TransferP2P(ctx context.Context, fromUserID uuid.UUID, req *TransferRequest) (*DetailedJournalEntry, error) {
	if req.Amount <= 0 {
		return nil, ErrInvalidAmount
	}

	// Check Idempotency Key
	if isUsed, entry, _ := s.repo.CheckIdempotency(ctx, req.IdempotencyKey); isUsed {
		return s.GetDetailedTransaction(ctx, entry.ID)
	}

	fromAcc, err := s.GetOrCreateUserAccount(ctx, fromUserID, req.Currency)
	if err != nil {
		return nil, err
	}

	// Verify sufficient funds
	balance, err := s.repo.GetBalance(ctx, fromAcc.ID)
	if err != nil {
		return nil, err
	}
	if balance < req.Amount {
		return nil, fmt.Errorf("%w: balance=%d, requested=%d", ErrInsufficientFunds, balance, req.Amount)
	}

	// Determine recipient account
	var toUserID uuid.UUID
	if req.ToUserID != nil && *req.ToUserID != uuid.Nil {
		toUserID = *req.ToUserID
	} else {
		// Use a deterministic synthetic ID for mock recipients if specified by phone / miigho ID
		toUserID = uuid.NewMD5(uuid.NameSpaceDNS, []byte(req.ToMiighoID+req.ToPhone))
	}

	toAcc, err := s.GetOrCreateUserAccount(ctx, toUserID, req.Currency, "Bénéficiaire P2P")
	if err != nil {
		return nil, err
	}

	ref := req.IdempotencyKey
	if ref == "" {
		ref = fmt.Sprintf("P2P-%d", time.Now().UnixNano())
	}

	desc := req.Description
	if desc == "" {
		desc = fmt.Sprintf("Transfert P2P vers %s", req.ToMiighoID)
	}

	entry := &JournalEntry{
		ID:              uuid.New(),
		TransactionType: P2PTransfer,
		ReferenceID:     ref,
		Description:     desc,
		CreatedAt:       time.Now().UTC(),
	}

	// Double-entry postings:
	// 1. Credit sender's Asset Account (Balance decreases)
	// 2. Debit recipient's Asset Account (Balance increases)
	postings := []*LedgerPosting{
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      fromAcc.ID,
			Amount:         req.Amount,
			IsCredit:       true, // Credit sender (decreases asset)
			CreatedAt:      entry.CreatedAt,
		},
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      toAcc.ID,
			Amount:         req.Amount,
			IsCredit:       false, // Debit recipient (increases asset)
			CreatedAt:      entry.CreatedAt,
		},
	}

	if err := s.repo.PostJournalEntry(ctx, entry, postings, req.IdempotencyKey); err != nil {
		return nil, err
	}

	return s.GetDetailedTransaction(ctx, entry.ID)
}

// CashIn simulates recharging the wallet from Mobile Money / Card.
func (s *Service) CashIn(ctx context.Context, userID uuid.UUID, req *CashInRequest) (*DetailedJournalEntry, error) {
	if req.Amount <= 0 {
		return nil, ErrInvalidAmount
	}

	if isUsed, entry, _ := s.repo.CheckIdempotency(ctx, req.IdempotencyKey); isUsed {
		return s.GetDetailedTransaction(ctx, entry.ID)
	}

	userAcc, err := s.GetOrCreateUserAccount(ctx, userID, req.Currency)
	if err != nil {
		return nil, err
	}

	momoPool, err := s.repo.GetSystemAccount(ctx, "MoMo Settlement Pool", req.Currency, Liability)
	if err != nil {
		return nil, err
	}

	providerLabel := strings.ToUpper(req.Provider)
	ref := req.IdempotencyKey
	if ref == "" {
		ref = fmt.Sprintf("MOMO-IN-%d", time.Now().UnixNano())
	}

	entry := &JournalEntry{
		ID:              uuid.New(),
		TransactionType: MoMoCashIn,
		ReferenceID:     ref,
		Description:     fmt.Sprintf("Recharge %s (%s)", providerLabel, req.PhoneNumber),
		CreatedAt:       time.Now().UTC(),
	}

	// Double-entry postings:
	// 1. Debit User Asset (increases balance)
	// 2. Credit System Settlement Pool (increases liability owed to network)
	postings := []*LedgerPosting{
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      userAcc.ID,
			Amount:         req.Amount,
			IsCredit:       false, // Debit user (+amount)
			CreatedAt:      entry.CreatedAt,
		},
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      momoPool.ID,
			Amount:         req.Amount,
			IsCredit:       true, // Credit momo pool (+liability)
			CreatedAt:      entry.CreatedAt,
		},
	}

	if err := s.repo.PostJournalEntry(ctx, entry, postings, req.IdempotencyKey); err != nil {
		return nil, err
	}

	return s.GetDetailedTransaction(ctx, entry.ID)
}

// CashOut simulates withdrawing funds to Mobile Money.
func (s *Service) CashOut(ctx context.Context, userID uuid.UUID, req *CashOutRequest) (*DetailedJournalEntry, error) {
	if req.Amount <= 0 {
		return nil, ErrInvalidAmount
	}

	if isUsed, entry, _ := s.repo.CheckIdempotency(ctx, req.IdempotencyKey); isUsed {
		return s.GetDetailedTransaction(ctx, entry.ID)
	}

	userAcc, err := s.GetOrCreateUserAccount(ctx, userID, req.Currency)
	if err != nil {
		return nil, err
	}

	balance, err := s.repo.GetBalance(ctx, userAcc.ID)
	if err != nil {
		return nil, err
	}
	if balance < req.Amount {
		return nil, fmt.Errorf("%w: balance=%d, requested=%d", ErrInsufficientFunds, balance, req.Amount)
	}

	momoPool, err := s.repo.GetSystemAccount(ctx, "MoMo Settlement Pool", req.Currency, Liability)
	if err != nil {
		return nil, err
	}

	providerLabel := strings.ToUpper(req.Provider)
	ref := req.IdempotencyKey
	if ref == "" {
		ref = fmt.Sprintf("MOMO-OUT-%d", time.Now().UnixNano())
	}

	entry := &JournalEntry{
		ID:              uuid.New(),
		TransactionType: MoMoCashOut,
		ReferenceID:     ref,
		Description:     fmt.Sprintf("Retrait vers %s (%s)", providerLabel, req.PhoneNumber),
		CreatedAt:       time.Now().UTC(),
	}

	// Double-entry postings:
	// 1. Credit User Asset (decreases balance)
	// 2. Debit System Settlement Pool (decreases liability)
	postings := []*LedgerPosting{
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      userAcc.ID,
			Amount:         req.Amount,
			IsCredit:       true, // Credit user (-amount)
			CreatedAt:      entry.CreatedAt,
		},
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      momoPool.ID,
			Amount:         req.Amount,
			IsCredit:       false, // Debit momo pool (-liability)
			CreatedAt:      entry.CreatedAt,
		},
	}

	if err := s.repo.PostJournalEntry(ctx, entry, postings, req.IdempotencyKey); err != nil {
		return nil, err
	}

	return s.GetDetailedTransaction(ctx, entry.ID)
}

// QRPay processes a payment scanned from a QR code.
func (s *Service) QRPay(ctx context.Context, userID uuid.UUID, req *QRPayRequest) (*DetailedJournalEntry, error) {
	if req.Amount <= 0 {
		return nil, ErrInvalidAmount
	}

	if isUsed, entry, _ := s.repo.CheckIdempotency(ctx, req.IdempotencyKey); isUsed {
		return s.GetDetailedTransaction(ctx, entry.ID)
	}

	userAcc, err := s.GetOrCreateUserAccount(ctx, userID, req.Currency)
	if err != nil {
		return nil, err
	}

	balance, err := s.repo.GetBalance(ctx, userAcc.ID)
	if err != nil {
		return nil, err
	}
	if balance < req.Amount {
		return nil, fmt.Errorf("%w: balance=%d, requested=%d", ErrInsufficientFunds, balance, req.Amount)
	}

	// Parse recipient info from QR payload (e.g., "miigho://pay?to=MG-9824-CIV&name=Merchant")
	recipientName := "Commerçant MÏÏghO"
	if strings.Contains(req.QRData, "to=") {
		parts := strings.Split(req.QRData, "to=")
		if len(parts) > 1 {
			recipientName = strings.Split(parts[1], "&")[0]
		}
	}

	merchantUserID := uuid.NewMD5(uuid.NameSpaceDNS, []byte(req.QRData))
	merchantAcc, err := s.GetOrCreateUserAccount(ctx, merchantUserID, req.Currency, fmt.Sprintf("Boutique %s", recipientName))
	if err != nil {
		return nil, err
	}

	ref := req.IdempotencyKey
	if ref == "" {
		ref = fmt.Sprintf("QR-PAY-%d", time.Now().UnixNano())
	}

	entry := &JournalEntry{
		ID:              uuid.New(),
		TransactionType: P2PTransfer,
		ReferenceID:     ref,
		Description:     fmt.Sprintf("Paiement QR Code • %s", recipientName),
		CreatedAt:       time.Now().UTC(),
	}

	postings := []*LedgerPosting{
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      userAcc.ID,
			Amount:         req.Amount,
			IsCredit:       true, // Credit user (-amount)
			CreatedAt:      entry.CreatedAt,
		},
		{
			ID:             uuid.New(),
			JournalEntryID: entry.ID,
			AccountID:      merchantAcc.ID,
			Amount:         req.Amount,
			IsCredit:       false, // Debit merchant (+amount)
			CreatedAt:      entry.CreatedAt,
		},
	}

	if err := s.repo.PostJournalEntry(ctx, entry, postings, req.IdempotencyKey); err != nil {
		return nil, err
	}

	return s.GetDetailedTransaction(ctx, entry.ID)
}

// GetUserTransactions returns formatted transaction history for user view.
func (s *Service) GetUserTransactions(ctx context.Context, userID uuid.UUID, currency string, limit int, offset int) ([]*UserTransactionItem, error) {
	acc, err := s.GetOrCreateUserAccount(ctx, userID, currency)
	if err != nil {
		return nil, err
	}

	postings, err := s.repo.GetPostingsForAccount(ctx, acc.ID, limit, offset)
	if err != nil {
		return nil, err
	}

	var items []*UserTransactionItem
	for _, p := range postings {
		entry, allPostings, err := s.repo.GetJournalEntry(ctx, p.JournalEntryID)
		if err != nil {
			continue
		}

		isCreditToUser := !p.IsCredit // Debit to Asset = Credit to user pocket (+)

		title := entry.Description
		subtitle := "Transaction Sandbox"
		switch entry.TransactionType {
		case MoMoCashIn:
			title = entry.Description
			subtitle = "Recharge Mobile Money • Sandbox"
		case MoMoCashOut:
			title = entry.Description
			subtitle = "Retrait Mobile Money • Sandbox"
		case P2PTransfer:
			if isCreditToUser {
				title = entry.Description
				subtitle = "Transfert P2P Reçu • Sandbox"
			} else {
				title = entry.Description
				subtitle = "Transfert P2P Émis • Sandbox"
			}
		case MarketplaceEscrow:
			title = entry.Description
			subtitle = "Séquestre Garanti (Escrow) • Sandbox"
		case MarketplaceRelease:
			title = entry.Description
			subtitle = "Libération des fonds • Sandbox"
		case Fee:
			title = "Frais de service"
			subtitle = "Frais de réseau MÏÏghO"
		}

		counterparty := ""
		for _, otherP := range allPostings {
			if otherP.AccountID != acc.ID {
				if otherAcc, err := s.repo.GetAccount(ctx, otherP.AccountID); err == nil {
					counterparty = otherAcc.Name
				}
			}
		}

		items = append(items, &UserTransactionItem{
			ID:             p.ID,
			JournalEntryID: entry.ID,
			Title:          title,
			Subtitle:       subtitle,
			Amount:         p.Amount,
			Currency:       currency,
			IsCredit:       isCreditToUser,
			Type:           entry.TransactionType,
			Status:         StatusPosted,
			ReferenceID:    entry.ReferenceID,
			CreatedAt:      p.CreatedAt,
			Counterparty:   counterparty,
		})
	}

	return items, nil
}

// GetDetailedJournalEntries returns auditable journal entries with all debit/credit postings.
func (s *Service) GetDetailedJournalEntries(ctx context.Context, limit int, offset int) ([]*DetailedJournalEntry, error) {
	if limit <= 0 || limit > 100 {
		limit = 50
	}
	entries, err := s.repo.ListJournalEntries(ctx, limit, offset)
	if err != nil {
		return nil, err
	}

	var detailed []*DetailedJournalEntry
	for _, e := range entries {
		d, err := s.GetDetailedTransaction(ctx, e.ID)
		if err == nil {
			detailed = append(detailed, d)
		}
	}
	return detailed, nil
}

// GetDetailedTransaction retrieves a single transaction with its exact debit/credit postings.
func (s *Service) GetDetailedTransaction(ctx context.Context, entryID uuid.UUID) (*DetailedJournalEntry, error) {
	entry, postings, err := s.repo.GetJournalEntry(ctx, entryID)
	if err != nil {
		return nil, err
	}

	var detailedPostings []*DetailedLedgerPosting
	var totalDebit int64
	var totalCredit int64

	for _, p := range postings {
		acc, err := s.repo.GetAccount(ctx, p.AccountID)
		accName := "Unknown Account"
		accType := Asset
		currency := "FCFA"
		if err == nil {
			accName = acc.Name
			accType = acc.AccountType
			currency = acc.Currency
		}

		direction := Debit
		if p.IsCredit {
			direction = Credit
			totalCredit += p.Amount
		} else {
			totalDebit += p.Amount
		}

		detailedPostings = append(detailedPostings, &DetailedLedgerPosting{
			ID:             p.ID,
			JournalEntryID: p.JournalEntryID,
			AccountID:      p.AccountID,
			AccountName:    accName,
			AccountType:    accType,
			Amount:         p.Amount,
			Currency:       currency,
			IsCredit:       p.IsCredit,
			Direction:      direction,
			CreatedAt:      p.CreatedAt,
		})
	}

	return &DetailedJournalEntry{
		Entry:       entry,
		Status:      StatusPosted,
		Postings:    detailedPostings,
		TotalDebit:  totalDebit,
		TotalCredit: totalCredit,
		IsBalanced:  (totalDebit == totalCredit),
	}, nil
}
