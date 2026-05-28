import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function POST(request: Request) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  
  const { brandId } = await request.json()
  
  const { data: brand } = await supabase.from('brands').select('*').eq('id', brandId).single()
  if (!brand) return NextResponse.json({ error: 'Brand not found' }, { status: 404 })
  
  try {
    const res = await fetch(
      `https://${brand.shopify_domain}/admin/api/2024-01/products.json?limit=10&status=active&fields=id,title,handle,product_type,vendor,variants,images,body_html,tags`,
      { headers: { 'X-Shopify-Access-Token': brand.shopify_access_token, 'Content-Type': 'application/json' } }
    )
    if (!res.ok) return NextResponse.json({ error: 'Shopify API error' }, { status: 500 })
    const { products } = await res.json()
    const upsertData = products.map((p: any) => ({
      brand_id: brandId,
      shopify_product_id: String(p.id),
      title: p.title,
      handle: p.handle,
      product_type: p.product_type || null,
      vendor: p.vendor || null,
      raw_data: p,
      last_synced_at: new Date().toISOString(),
    }))
    const { error: upsertError } = await supabase.from('products').upsert(upsertData, { onConflict: 'brand_id,shopify_product_id' })
    if (upsertError) return NextResponse.json({ error: upsertError.message }, { status: 500 })
    await supabase.from('brands').update({ last_audit_at: new Date().toISOString() }).eq('id', brandId)
    return NextResponse.json({ success: true, count: products.length })
  } catch {
    return NextResponse.json({ error: 'Failed to fetch products' }, { status: 500 })
  }
}
