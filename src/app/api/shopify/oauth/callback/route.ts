import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const code = searchParams.get('code')
  const shop = searchParams.get('shop')

  if (!code || !shop) {
    return NextResponse.redirect(
      `${process.env.NEXT_PUBLIC_APP_URL}/onboarding?error=missing_params`
    )
  }

  // 1. Token exchange
  const tokenRes = await fetch(`https://${shop}/admin/oauth/access_token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      client_id: process.env.SHOPIFY_CLIENT_ID,
      client_secret: process.env.SHOPIFY_CLIENT_SECRET,
      code,
    }),
  })

  if (!tokenRes.ok) {
    return NextResponse.redirect(
      `${process.env.NEXT_PUBLIC_APP_URL}/onboarding?error=token_failed`
    )
  }

  const { access_token } = await tokenRes.json()

  // 2. Shop data fetch
  const shopRes = await fetch(`https://${shop}/admin/api/2024-01/shop.json`, {
    headers: { 'X-Shopify-Access-Token': access_token },
  })

  if (!shopRes.ok) {
    return NextResponse.redirect(
      `${process.env.NEXT_PUBLIC_APP_URL}/onboarding?error=shop_fetch_failed`
    )
  }

  const { shop: shopData } = await shopRes.json()

  // 3. Supabase insert — service role, no RLS issues
  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!
  )

  // Duplicate check — same shop already connected?
  const { data: existing } = await supabase
    .from('brands')
    .select('id')
    .eq('shopify_domain', shop)
    .single()

  if (!existing) {
    const { error: insertError } = await supabase.from('brands').insert({
      name: shopData.name,
      shopify_domain: shop,
      shopify_access_token: access_token,
      status: 'active',
    })

    if (insertError) {
      console.error('Brand insert failed:', insertError.message)
      return NextResponse.redirect(
        `${process.env.NEXT_PUBLIC_APP_URL}/onboarding?error=${encodeURIComponent(insertError.message)}`
      )
    }
  }

  // 4. Dashboard pe bhejo — no token in URL
  return NextResponse.redirect(
    `${process.env.NEXT_PUBLIC_APP_URL}/dashboard`
  )
}
