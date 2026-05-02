import { NextResponse } from 'next/server'

export async function POST(request: Request) {
  const { domain, accessToken } = await request.json()
  if (!domain || !accessToken) {
    return NextResponse.json({ error: 'Domain and access token required' }, { status: 400 })
  }
  try {
    const res = await fetch(`https://${domain}/admin/api/2024-01/shop.json`, {
      headers: { 'X-Shopify-Access-Token': accessToken, 'Content-Type': 'application/json' },
    })
    if (!res.ok) return NextResponse.json({ error: 'Invalid domain or access token' }, { status: 400 })
    const { shop } = await res.json()
    return NextResponse.json({ success: true, shopName: shop.name })
  } catch (err) {
    return NextResponse.json({ error: 'Could not reach Shopify' }, { status: 500 })
  }
}
