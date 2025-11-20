-- Migration: Add router_id to users, payments, and odp
-- Run order: after database_schema.sql has been applied

USE pppoe_monitor;

-- users.router_id
ALTER TABLE users
  ADD COLUMN router_id VARCHAR(100) NOT NULL DEFAULT '' AFTER id,
  ADD INDEX idx_router_id (router_id),
  DROP INDEX idx_username,
  ADD UNIQUE KEY uniq_router_username (router_id, username);

-- payments.router_id (denormalized for simpler filtering and reporting)
ALTER TABLE payments
  ADD COLUMN router_id VARCHAR(100) NOT NULL DEFAULT '' AFTER id,
  ADD INDEX idx_pay_router_month_year (router_id, payment_year, payment_month);

-- odp.router_id (optional scoping ODP per router)
ALTER TABLE odp
  ADD COLUMN router_id VARCHAR(100) NOT NULL DEFAULT '' AFTER id,
  ADD INDEX idx_odp_router (router_id);

-- Note:
-- - Backfill values should be applied separately depending on deployment plan.
-- - For legacy data, set a default router_id (e.g., a known serial or label) to avoid null/empty usage.


