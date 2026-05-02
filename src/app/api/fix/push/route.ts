/**
 * POST /api/fix/push
 * Pushes generated fix to Shopify product via Admin API
 * Body: { fix_id }
 * Returns: { fix_id, shopify_product_id, attribute, status }
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
  if (!fix_id) return NextResponse.json({ error: 'fix_id required' }, { status: 400 })

  // Load fix row + brand in one query
  const { data: fix } = await supabase
    .from('fix_history')
    .select(`
      id, product_id, attribute, shopify_field, new_value, status,
      brands!inner(id, shop_domain, access_token, user_id)
    `)
    .eq('id', fix_id)
    .single()

  if (!fix) return NextResponse.json({ error: 'Fix not found' }, { status: 404 })
  if ((fix.brands as any).user_id !== session.user.id)
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  if (fix.status === 'pushed')
    return NextResponse.json({ error: 'Already pushed' }, { status: 409 })

  const brand = fix.brands as any

  // Build Shopify field update payload
  // Note: metafields (seo_title, seo_description) need separate endpoint — handled below
  const isMetafield = fix.shopify_field === 'metafields'
  let shopifyResult: { success: boolean; error?: string }

  if (isMetafield) {
    // SEO metafields use a different Shopify endpoint
    shopifyResult = await pushMetafield(
      brand.shop_domain,
      brand.access_token,
      fix.product_id,
      fix.attribute,
      fix.new_value
    )
  } else {
    shopifyResult = await updateShopifyProduct(
      brand.shop_domain,
      brand.access_token,
      fix.product_id,
      { [fix.shopify_field]: fix.new_value }
    )
  }

  const newStatus = shopifyResult.success ? 'pushed' : 'failed'

  await supabase
    .from('fix_history')
    .update({
      status: newStatus,
      pushed_at: shopifyResult.success ? new Date().toISOString() : null,
      error_message: shopifyResult.error || null,
    })
    .eq('id', fix_id)

  return NextResponse.json({
    fix_id,
    shopify_product_id: fix.product_id,
    attribute: fix.attribute,
    status: newStatus,
    error: shopifyResult.error,
  })
}

async function pushMetafield(
  shopDomain: string,
  accessToken: string,
  productId: string,
  attribute: string,
  value: string
): Promise<{ success: boolean; error?: string }> {
  const numericId = productId.replace(/\D/g, '')
  const namespace = 'global'
  const key = attribute === 'seo_title' ? 'title_tag' : 'description_tag'

  const url = `https://${shopDomain}/admin/api/2024-01/products/${numericId}/metafields.json`
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': accessToken,
    },
    body: JSON.stringify({
      metafield: { namespace, key, value, type: 'single_line_text_field' }
    }),
  })

  if (!res.ok) {
    const err = await res.text()
    return { success: false, error: `Metafield ${res.status}: ${err}` }
  }
  return { success: true }
}
