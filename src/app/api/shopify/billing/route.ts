import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export async function POST(request: Request) {
  const { shop, accessToken } = await request.json()

  if (!shop || !accessToken) {
    return NextResponse.json({ error: 'Missing shop or accessToken' }, { status: 400 })
  }

  const charge = {
    recurring_application_charge: {
      name: 'Vialtry Growth',
      price: 19.00,
      return_url: `${process.env.NEXT_PUBLIC_APP_URL}/api/shopify/billing/confirm?shop=${shop}`,
      test: process.env.NODE_ENV !== 'production',
      trial_days: 7,
    }
  }

  const res = await fetch(`https://${shop}/admin/api/2024-01/recurring_application_charges.json`, {
    method: 'POST',
    headers: {
      'X-Shopify-Access-Token': accessToken,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(charge),
  })

  if (!res.ok) {
    const err = await res.text()
    return NextResponse.json({ error: err }, { status: 500 })
  }

  const data = await res.json()
  const confirmationUrl = data.recurring_application_charge.confirmation_url

  return NextResponse.json({ confirmationUrl })
}
