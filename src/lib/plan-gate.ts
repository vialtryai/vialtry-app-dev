/**
 * Plan gating helper — checks product limits before running agents
 * Free plan: 10 products max
 * Paid plans: unlimited (product_limit = -1)
 */
import { SupabaseClient } from '@supabase/supabase-js'

export const PLAN_LIMITS: Record<string, number> = {
  free:         10,
  starter:      50,
  growth:       200,
  professional: -1,   // unlimited
  enterprise:   -1,
}

export async function checkProductLimit(
  supabase: SupabaseClient,
  brand_id: string,
  requestedCount: number = 1
): Promise<{ allowed: boolean; plan: string; limit: number; reason?: string }> {
  const { data: brand } = await supabase
    .from('brands')
    .select('plan, product_limit')
    .eq('id', brand_id)
    .single()

  if (!brand) return { allowed: false, plan: 'unknown', limit: 0, reason: 'Brand not found' }

  const limit = brand.product_limit ?? PLAN_LIMITS[brand.plan] ?? 10

  if (limit === -1) return { allowed: true, plan: brand.plan, limit: -1 }

  // Count existing audited products for this brand
  const { count } = await supabase
    .from('pdp_audits')
    .select('*', { count: 'exact', head: true })
    .eq('brand_id', brand_id)

  const used = count ?? 0

  if (used + requestedCount > limit) {
    return {
      allowed: false,
      plan: brand.plan,
      limit,
      reason: `Plan limit reached: ${used}/${limit} products used. Upgrade to audit more.`,
    }
  }

  return { allowed: true, plan: brand.plan, limit }
}
