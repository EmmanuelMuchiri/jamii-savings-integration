-- Synthetic seed data: one account per status, a zero balance and a 16-digit account.
-- MERGE keeps the script idempotent. Account numbers match the Postman environment.
MERGE INTO accounts (account_number, customer_id, status, balance, currency) KEY (account_number) VALUES
    ('0123456789',       '1001', 'ACTIVE',  15250.75, 'KES'),
    ('1234567890',       '1002', 'DORMANT',  3200.00, 'KES'),
    ('2345678901',       '1003', 'CLOSED',      0.00, 'KES'),
    ('3456789012',       '1004', 'ACTIVE',      0.00, 'KES'),
    ('4567890123456789', '1005', 'ACTIVE',  98000.50, 'KES');
