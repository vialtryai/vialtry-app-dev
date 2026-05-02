-- fix_history: tracks every AI-generated fix, push, and revert
CREATE TABLE IF NOT EXISTS fix_history (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id        UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
  product_id      TEXT NOT NULL,          -- Shopify product GID or numeric ID
  product_title   TEXT,
  attribute       TEXT NOT NULL,          -- e.g. "description", "meta_title"
  old_value       TEXT,
  new_value       TEXT NOT NULL,
  shopify_field   TEXT NOT NULL,          -- exact Shopify API field name
  pushed_at       TIMESTAMPTZ,
  reverted_at     TIMESTAMPTZ,
  status          TEXT NOT NULL DEFAULT 'generated'
                  CHECK (status IN ('generated','pushed','reverted','failed')),
  error_message   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fix_history_brand_id   ON fix_history(brand_id);
CREATE INDEX idx_fix_history_product_id ON fix_history(product_id);
CREATE INDEX idx_fix_history_status     ON fix_history(status);

-- competitor_tracking: brands being tracked per account
CREATE TABLE IF NOT EXISTS competitor_tracking (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id         UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
  competitor_name  TEXT NOT NULL,
  shopify_domain   TEXT,
  website_url      TEXT,
  added_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(brand_id, competitor_name)
);

-- competitor_sov: weekly SOV snapshot per competitor per prompt
CREATE TABLE IF NOT EXISTS competitor_sov (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id         UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
  competitor_name  TEXT NOT NULL,
  prompt           TEXT NOT NULL,
  mentioned        BOOLEAN NOT NULL DEFAULT FALSE,
  position         INTEGER,              -- rank in AI response (1-based), NULL if not mentioned
  ai_response_snippet TEXT,
  checked_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_competitor_sov_brand_id ON competitor_sov(brand_id);
CREATE INDEX idx_competitor_sov_checked  ON competitor_sov(checked_at);

-- billing_plans: simple flag-based gating, no Stripe yet
ALTER TABLE brands
  ADD COLUMN IF NOT EXISTS plan          TEXT NOT NULL DEFAULT 'free'
                                         CHECK (plan IN ('free','starter','growth','professional','enterprise')),
  ADD COLUMN IF NOT EXISTS product_limit INTEGER NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS plan_activated_at TIMESTAMPTZ;

-- RLS
ALTER TABLE fix_history         ENABLE ROW LEVEL SECURITY;
ALTER TABLE competitor_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE competitor_sov      ENABLE ROW LEVEL SECURITY;

CREATE POLICY "brand_own_fix_history"
  ON fix_history FOR ALL
  USING (brand_id IN (SELECT id FROM brands WHERE user_id = auth.uid()));

CREATE POLICY "brand_own_competitor_tracking"
  ON competitor_tracking FOR ALL
  USING (brand_id IN (SELECT id FROM brands WHERE user_id = auth.uid()));

CREATE POLICY "brand_own_competitor_sov"
  ON competitor_sov FOR ALL
  USING (brand_id IN (SELECT id FROM brands WHERE user_id = auth.uid()));
