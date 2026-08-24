/*
Package ledger provides the core interfaces and types for the MÏÏghOPay double-entry accounting system.

Design Philosophy:
- Immutability: Journal entries and postings are append-only. They are never updated or deleted. Corrections require a compensating journal entry.
- Derived Balances: Balances are not stored as a mutable field. A balance is strictly the sum of credits minus the sum of debits (or vice versa depending on account type) over the account's postings. Caching can be used for performance, but the source of truth is always the sum of postings.
- ACID Compliance: All postings for a given JournalEntry must be written in a single database transaction.
- Invariants: For every JournalEntry, the absolute sum of all debit amounts must exactly equal the absolute sum of all credit amounts.
- Isolation: The ledger does not know about external PSP concepts (like MoMo APIs). It only records the financial truth. PSP interactions are handled via the PaymentGateway adapter interfaces.

Double-Entry Principles:
- Asset accounts: Debit increases, Credit decreases.
- Liability/Equity/Revenue accounts: Credit increases, Debit decreases.
- Expense accounts: Debit increases, Credit decreases.

Future Implementation:
This package currently only defines interfaces. The concrete PostgreSQL implementation and the PSP adapters (e.g., MTN MoMo, Orange Money) will be built in the MÏÏghOPay phase.
*/
package ledger
