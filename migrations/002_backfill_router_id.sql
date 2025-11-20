-- Backfill router_id for legacy data
-- Replace 'DEFAULT-ROUTER' with an appropriate value (e.g., known serial number)

USE pppoe_monitor;

SET @DEFAULT_ROUTER := 'DEFAULT-ROUTER';

-- users without router_id -> set to default
UPDATE users SET router_id = @DEFAULT_ROUTER WHERE (router_id = '' OR router_id IS NULL);

-- payments without router_id -> inherit from users when possible
UPDATE payments p
JOIN users u ON u.id = p.user_id
SET p.router_id = u.router_id
WHERE (p.router_id = '' OR p.router_id IS NULL);

-- odp without router_id -> set to default
UPDATE odp SET router_id = @DEFAULT_ROUTER WHERE (router_id = '' OR router_id IS NULL);


