/**
 * POST /api/fix/generate
 */
import { NextRequest, NextResponse } from 'next/server'
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { GoogleGenerativeAI } from '@google/generative-ai'
import type { FixTarget, GenerateFixResponse } from '@/types/fix'

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!)
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash-lite' })

export async function POST(req: NextRequest) {
  const cookieStore = await cookies()
  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    { cookies: { getAll: () => cookieStore.getAll(), setAll: () => {} } }
  )

  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const body: FixTarget = await req.json()
  const { brand_id, product_id, product_title, attribute, shopify_field, current_value, fix_hint } = body

  const { data: brand } = await supabase
    .from('brands')
    .select('id, shop_domain, plan, product_limit')
    .eq('id', brand_id)
    .eq('user_id', session.user.id)
    .single()

  if (!brand) return NextResponse.json({ error: 'Brand not found' }, { status: 404 })

  const prompt = `You are an expert e-commerce catalog writer optimizing product data for AI shopping agents (ChatGPT, Gemini, Perplexity, Amazon Rufus).
Product: "${product_title}"
Attribute to fix: ${attribute}
Shopify field: ${shopify_field}
Current value: ${current_value || '(empty)'}
Why it's failing: ${fix_hint || 'Missing or insufficient content'}
Write an optimized value for this attribute. Rules:
- For descriptions: 150-300 words, include material, use case, key features. No marketing fluff. Structured for AI parsing.
- For titles: Under 70 chars, include product type + key differentiator. No brand name repetition.
- For tags: Comma-separated, 8-15 relevant tags covering category, material, use case, occasion.
- For SEO fields: Follow standard meta best practices.
Respond ONLY in this JSON format, no markdown:
{
  "new_value": "the optimized content here",
  "explanation": "one sentence why this is better for AI visibility"
}`

  let new_value = ''
  let explanation = ''
  try {
    const result = await model.generateContent(prompt)
    const text = result.response.text().trim()
    const parsed = JSON.parse(text)
    new_value = parsed.new_value
    explanation = parsed.explanation
  } catch (err) {
    return NextResponse.json({ error: 'Gemini generation failed', detail: String(err) }, { status: 500 })
  }

  const { data: fixRow, error: dbErr } = await supabase
    .from('fix_history')
    .insert({ brand_id, product_id, product_title, attribute, shopify_field, old_value: current_value || null, new_value, status: 'generated' })
    .select('id')
    .single()

  if (dbErr) return NextResponse.json({ error: 'DB insert failed' }, { status: 500 })

  const response: GenerateFixResponse = { fix_id: fixRow.id, attribute, new_value, explanation }
  return NextResponse.json(response)
}
