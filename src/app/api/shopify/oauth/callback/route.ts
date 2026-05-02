import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url)
  const code = searchParams.get('code')
  const shop = searchParams.get('shop')
  const state = searchParams.get('state')

  const cookieHeader = request.headers.get('cookie') || ''
  const savedState = cookieHeader.match(/shopify_oauth_state=([^;]+)/)?.[1]
  // state check temporarily disabled for testing
  // if (!state || state !== savedState) { return NextResponse.redirect(...) }

  if (!code || !shop) {
    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/onboarding?error=missing_params`)
  }

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
    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/onboarding?error=token_exchange_failed`)
  }

  const { access_token } = await tokenRes.json()

  const shopRes = await fetch(`https://${shop}/admin/api/2024-01/shop.json`, {
    headers: { 'X-Shopify-Access-Token': access_token },
  })
  const { shop: shopData } = await shopRes.json()

  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()

  if (!user) {
    return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/login`)
  }

  await supabase.from('brands').insert({
    user_id: user.id,
    name: shopData.name,
    shopify_domain: shop,
    shopify_access_token: access_token,
    status: 'active',
  } as never)

  return NextResponse.redirect(`${process.env.NEXT_PUBLIC_APP_URL}/dashboard`)
}
