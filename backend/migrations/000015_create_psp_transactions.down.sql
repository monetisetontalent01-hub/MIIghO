-- Rollback: Drop PSP Transactions and Webhook Events Tables
-- Phase 3A.6: PSP Gateway Abstraction & Sandbox Provider

DROP TABLE IF EXISTS psp_webhook_events;
DROP TABLE IF EXISTS psp_transactions;
