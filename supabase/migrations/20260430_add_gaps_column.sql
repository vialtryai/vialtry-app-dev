-- Add gaps JSONB column to pdp_audits if not exists
ALTER TABLE pdp_audits 
  ADD COLUMN IF NOT EXISTS gaps JSONB NOT NULL DEFAULT '[]';

-- Index for querying gaps by brand
CREATE INDEX IF NOT EXISTS idx_pdp_audits_brand_gaps 
  ON pdp_audits(brand_id) 
  WHERE gaps != '[]';
