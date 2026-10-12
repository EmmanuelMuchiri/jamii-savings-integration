-- Accounts schema for the Balance API (H2 2.x). Idempotent: safe to run on every start.
CREATE TABLE IF NOT EXISTS accounts (
    account_number VARCHAR(20)   NOT NULL PRIMARY KEY,
    customer_id    VARCHAR(20)   NOT NULL,
    status         VARCHAR(10)   NOT NULL,
    balance        DECIMAL(18,2) NOT NULL,
    currency       CHAR(3)       NOT NULL DEFAULT 'KES',
    updated_at     TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_accounts_status CHECK (status IN ('ACTIVE', 'DORMANT', 'CLOSED')),
    CONSTRAINT chk_accounts_number CHECK (REGEXP_LIKE(account_number, '^[0-9]{10,16}$'))
);
