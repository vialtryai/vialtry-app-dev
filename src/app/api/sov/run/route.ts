import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { runSOVCheck } from '@/lib/agents/sov'

export async function POST(request: Request) {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) return NextResponse.json({error:'Unauthorized'},{status:401})
  
  const {brandId,category,promptCount=5} = await request.json()
  
  const {data:brand} = await supabase.from('brands').select('*').eq('id',brandId).single()
  if(!brand) return NextResponse.json({error:'Brand not found'},{status:404})
  
  const geminiKey = process.env.GEMINI_API_KEY
  if(!geminiKey) return NextResponse.json({error:'Gemini API key not configured'},{status:500})
  
  try {
    const summary = await runSOVCheck(brand.name, category, geminiKey, promptCount)
    await supabase.from('sov_results').insert(summary.results.map(r=>({brand_id:brandId,prompt:r.prompt,ai_engine:r.ai_engine,brand_mentioned:r.brand_mentioned,position:r.position,competitors_mentioned:r.competitors_mentioned,raw_response:r.raw_response})))
    return NextResponse.json({success:true,summary})
  } catch(err:any) {
    return NextResponse.json({error:err.message||'SOV check failed'},{status:500})
  }
}
