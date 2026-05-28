import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'

export const runtime = 'edge'

export async function GET(request: Request) {
  // Verify cron secret
  const authHeader = request.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const supabase = await createClient()

  // Get all brands
  const { data: brands } = await supabase
    .from('brands')
    .select('id, name')

  if (!brands || brands.length === 0) {
    return NextResponse.json({ message: 'No brands found' })
  }

  const results = []

  for (const brand of brands) {
    // Get active prompts for this brand
    const { data: prompts } = await supabase
      .from('user_prompts')
      .select('*')
      .eq('brand_id', brand.id)
      .eq('is_active', true)

    if (!prompts || prompts.length === 0) continue

    // Create a sov_run record
    const { data: run } = await supabase
      .from('sov_runs')
      .insert({
        brand_id: brand.id,
        status: 'running',
        started_at: new Date().toISOString()
      })
      .select()
      .single()

    if (!run) continue

    let completed = 0

    for (const prompt of prompts) {
      try {
        // Call existing SOV run endpoint
        const res = await fetch(`${process.env.NEXT_PUBLIC_APP_URL}/api/sov/run`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            brandId: brand.id,
            query: prompt.prompt_text
          })
        })

        const data = await res.json()

        // Save result
        await supabase.from('sov_results').insert({
          run_id: run.id,
          brand_id: brand.id,
          prompt_text: prompt.prompt_text,
          ai_tool: 'multi',
          mentioned: data.mentioned || false,
          rank_position: data.rank || null
        })

        completed++
      } catch (err) {
        console.error('SOV check failed for prompt', prompt.id, err)
      }
    }

    // Update run status
    await supabase
      .from('sov_runs')
      .update({
        status: 'completed',
        completed_at: new Date().toISOString()
      })
      .eq('id', run.id)

    results.push({ brand: brand.name, prompts_run: completed })
  }

  return NextResponse.json({
    success: true,
    ran_at: new Date().toISOString(),
    results
  })
}
