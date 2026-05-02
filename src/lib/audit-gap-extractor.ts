/**
 * Extracts fix targets from PDP audit results
 * Call this after scoring, before saving to pdp_audits
 * 
 * Input: raw attribute scores from your existing scorer
 * Output: gap array ready for fix_history / Fix Queue UI
 */

export interface AuditGap {
  attribute: string        // human label: "Product Description"
  shopify_field: string    // Shopify REST field: "body_html"
  current_value?: string
  fix_hint: string         // why it's failing — shown in UI
  criticality: 'ULTRA' | 'HIGH' | 'MEDIUM'
}

// Map your internal attribute keys → Shopify fields + human labels
// Extend this as you add more attributes to your scorer
const ATTRIBUTE_META: Record<string, {
  shopify_field: string
  label: string
  criticality: 'ULTRA' | 'HIGH' | 'MEDIUM'
  hint: (val?: string) => string
}> = {
  description: {
    shopify_field: 'body_html',
    label: 'Product Description',
    criticality: 'ULTRA',
    hint: (v) => !v ? 'No description — AI agents skip products with empty descriptions'
                    : v.length < 100 ? `Too short (${v.length} chars) — needs 150+ words for AI parsing`
                    : 'Lacks material, use case, or structured content',
  },
  title: {
    shopify_field: 'title',
    label: 'Product Title',
    criticality: 'ULTRA',
    hint: (v) => !v ? 'No title'
                    : v.length > 70 ? 'Title too long (70 char limit for AI agent display)'
                    : 'Missing product type or key differentiator in title',
  },
  tags: {
    shopify_field: 'tags',
    label: 'Product Tags',
    criticality: 'HIGH',
    hint: (v) => !v ? 'No tags — reduces category matching in AI queries'
                    : 'Under 8 tags — add material, use case, occasion, category',
  },
  product_type: {
    shopify_field: 'product_type',
    label: 'Product Type',
    criticality: 'HIGH',
    hint: () => 'Empty product_type — AI agents use this for category classification',
  },
  vendor: {
    shopify_field: 'vendor',
    label: 'Vendor / Brand',
    criticality: 'MEDIUM',
    hint: () => 'Missing vendor field — brand attribution for AI recommendations',
  },
  seo_title: {
    shopify_field: 'metafields',
    label: 'SEO Title',
    criticality: 'HIGH',
    hint: () => 'Missing meta title tag — affects Google AI Mode / SGE visibility',
  },
  seo_description: {
    shopify_field: 'metafields',
    label: 'SEO Description',
    criticality: 'HIGH',
    hint: () => 'Missing meta description — reduces snippet quality in AI search results',
  },
  // Variant-level
  weight: {
    shopify_field: 'variants',
    label: 'Product Weight',
    criticality: 'MEDIUM',
    hint: () => 'No weight specified — required for Amazon Rufus and shipping agents',
  },
  material: {
    shopify_field: 'body_html',
    label: 'Material / Fabric',
    criticality: 'ULTRA',
    hint: () => 'Material not mentioned — #1 factor for AI product matching queries',
  },
  care_instructions: {
    shopify_field: 'body_html',
    label: 'Care Instructions',
    criticality: 'MEDIUM',
    hint: () => 'No care instructions — missed opportunity for long-tail AI queries',
  },
}

/**
 * Main function: takes your scorer output, returns gap array
 * 
 * scorerOutput format (adapt to match your actual scorer):
 * {
 *   [attributeKey]: {
 *     score: number,        // 0 = failing, >0 = passing
 *     value?: string,       // current value from Shopify
 *     maxScore: number,
 *   }
 * }
 */
export function extractGaps(
  scorerOutput: Record<string, { score: number; value?: string; maxScore: number }>
): AuditGap[] {
  const gaps: AuditGap[] = []

  for (const [key, result] of Object.entries(scorerOutput)) {
    // Only process attributes that are failing (score = 0 or significantly below max)
    const isFailing = result.score === 0 || result.score / result.maxScore < 0.3
    if (!isFailing) continue

    const meta = ATTRIBUTE_META[key]
    if (!meta) continue // attribute not mapped — skip

    gaps.push({
      attribute: meta.label,
      shopify_field: meta.shopify_field,
      current_value: result.value,
      fix_hint: meta.hint(result.value),
      criticality: meta.criticality,
    })
  }

  // Sort: ULTRA → HIGH → MEDIUM
  const order = { ULTRA: 0, HIGH: 1, MEDIUM: 2 }
  gaps.sort((a, b) => order[a.criticality] - order[b.criticality])

  return gaps
}

/**
 * Convenience: add to your existing audit save call
 * 
 * BEFORE (your current code probably looks like this):
 *   await supabase.from('pdp_audits').upsert({
 *     brand_id, product_id, product_title,
 *     core_score, full_score, scored_at: new Date().toISOString()
 *   })
 * 
 * AFTER (add gaps):
 *   import { extractGaps } from '@/lib/audit-gap-extractor'
 *   const gaps = extractGaps(scorerOutput)
 *   await supabase.from('pdp_audits').upsert({
 *     brand_id, product_id, product_title,
 *     core_score, full_score, gaps,           // <-- add this
 *     scored_at: new Date().toISOString()
 *   })
 */
