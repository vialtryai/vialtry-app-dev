/**
 * POST /api/fix/revert
 * Reverts a pushed fix by writing old_value back to Shopify
 * Body: { fix_id }
 */
import { NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'

import { cookies } from 'next/headers'
import { updateShopifyProduct } from '@/lib/shopify-admin'

export async function POST(req: NextRequest) {
  const cookieStore = await cookies()
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll(), setAll: () => {} } }
  )
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { fix_id } = await req.json()

  const { data: fix } = await supabase
    .from('fix_history')
    .select(`
      id, product_id, attribute, shopify_field, old_value, status,
      brands!inner(shop_domain, access_token, user_id)
    `)
    .eq('id', fix_id)
    .single()

  if (!fix) return NextResponse.json({ error: 'Fix not found' }, { status: 404 })
  if ((fix.brands as any).user_id !== session.user.id)
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  if (fix.status !== 'pushed')
    return NextResponse.json({ error: 'Can only revert pushed fixes' }, { status: 409 })

  const brand = fix.brands as any
  const revertValue = fix.old_value ?? ''  // empty string if no old value existed

  const result = await updateShopifyProduct(
    brand.shop_domain,
    brand.access_token,
    fix.product_id,
    { [fix.shopify_field]: revertValue }
  )

  const newStatus = result.success ? 'reverted' : 'failed'

  await supabase
    .from('fix_history')
    .update({
      status: newStatus,
      reverted_at: result.success ? new Date().toISOString() : null,
      error_message: result.error || null,
    })
    .eq('id', fix_id)

  return NextResponse.json({
    fix_id,
    status: newStatus,
    error: result.error,
  })
}
