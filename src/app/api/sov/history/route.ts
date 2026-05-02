import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
export async function GET(request: Request) {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) return NextResponse.json({error:'Unauthorized'},{status:401})
  const brandId = new URL(request.url).searchParams.get('brandId')
  if(!brandId) return NextResponse.json({error:'brandId required'},{status:400})
  const {data,error} = await supabase.from('sov_results').select('*').eq('brand_id',brandId).order('created_at',{ascending:false}).limit(50)
  if(error) return NextResponse.json({error:error.message},{status:500})
  const total=data.length, mentions=data.filter(r=>r.brand_mentioned).length
  const cc:Record<string,number>={}
  for(const r of data){const comps=Array.isArray(r.competitors_mentioned)?r.competitors_mentioned:[];for(const c of comps)cc[c]=(cc[c]||0)+1}
  const topCompetitors=Object.entries(cc).sort(([,a],[,b])=>b-a).slice(0,5).map(([name,count])=>({name,count}))
  return NextResponse.json({total,mentions,sov_percentage:total>0?Math.round(mentions/total*100):0,top_competitors:topCompetitors,results:data})
}
