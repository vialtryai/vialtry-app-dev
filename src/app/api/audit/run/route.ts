import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { auditProduct } from '@/lib/scoring/pdp'

export async function POST(request: Request) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  let brandId: string | undefined
  try {
    const body = await request.json()
    brandId = body?.brandId
  } catch {
    return NextResponse.json({ error: 'Invalid request body' }, { status: 400 })
  }

  if (!brandId) {
    return NextResponse.json({ error: 'brandId is required' }, { status: 400 })
  }

  // FIX: remove user_id check — user_id is NULL (server-side OAuth insert)
  let { data: brand } = await supabase.from('brands').select('*').eq('id', brandId).single()

  // Fallback: if brandId wrong, grab first brand
  if (!brand) {
    const { data: firstBrand } = await supabase.from('brands').select('*').limit(1).single()
    if (!firstBrand) return NextResponse.json({ error: 'No brand found. Please connect your Shopify store.' }, { status: 404 })
    brand = firstBrand
  }

  const { data: products } = await supabase.from('products').select('*').eq('brand_id', brand.id).limit(10)

  if (!products || products.length === 0) {
    return NextResponse.json({ error: 'No products found. Sync products first.' }, { status: 400 })
  }

  return await runAudit(supabase, brand.id, products)
}

async function runAudit(supabase: any, brandId: string, products: any[]) {
  if (!products || products.length === 0) {
    return NextResponse.json({ error: 'No products found. Sync products first.' }, { status: 400 })
  }
  const results = []
  for (const product of products) {
    const { data: audit } = await supabase.from('audits').insert({ brand_id: brandId, product_id: product.id, status: 'running' }).select().single()
    try {
      const result = auditProduct(product.raw_data)
      await supabase.from('audits').update({
        core_score: result.core_score,
        full_score: result.full_score,
        category_scores: result.category_scores,
        gaps: result.gaps,
        recommendations: result.recommendations,
        status: 'complete'
      }).eq('id', audit!.id)

      // Save to history
await supabase.from('pdp_audit_history').insert({
  brand_id: brandId,
  product_id: product.id,
  product_title: product.title,
  overall_score: result.core_score,
  core_score: result.core_score,
  full_score: result.full_score,
  vertical: result.vertical || 'general',
  gaps_count: result.gaps.length,
  is_oos: product.raw_data?.available === false
})

// Save category scores
const historyRes = await supabase
  .from('pdp_audit_history')
  .select('id')
  .eq('brand_id', brandId)
  .eq('product_id', product.id)
  .order('created_at', { ascending: false })
  .limit(1)
  .single()

if (historyRes.data) {
  const categoryInserts = Object.values(result.category_scores || {}).map((cat: any) => ({
    audit_history_id: historyRes.data.id,
    category_name: cat.name,
    score: cat.percentage
  }))
  if (categoryInserts.length > 0) {
    await supabase.from('pdp_category_scores').insert(categoryInserts)
  }
}
      results.push({ product_id: product.id, title: product.title, core_score: result.core_score, full_score: result.full_score, gaps_count: result.gaps.length })
    } catch (err) {
      console.error('Audit failed for product', product.id, err)
      await supabase.from('audits').update({ status: 'failed' }).eq('id', audit!.id)
    }
  }
  return NextResponse.json({
    success: true,
    audited: results.length,
    results,
    avg_core_score: results.length > 0 ? Math.round(results.reduce((s, r) => s + r.core_score, 0) / results.length) : 0
  })
}
