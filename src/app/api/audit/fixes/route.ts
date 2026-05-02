import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
export async function GET(request: Request) {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) return NextResponse.json({error:'Unauthorized'},{status:401})
  const brandId = new URL(request.url).searchParams.get('brandId')
  if(!brandId) return NextResponse.json({error:'brandId required'},{status:400})
  const {data:audits,error} = await supabase.from('audits').select('id,product_id,recommendations,gaps,products(title)').eq('brand_id',brandId).eq('status','complete').order('created_at',{ascending:false})
  if(error) return NextResponse.json({error:error.message},{status:500})
  const fixes:any[]=[];let gid=0
  for(const audit of(audits||[])){
    const recs=Array.isArray(audit.recommendations)?audit.recommendations:[]
    for(const rec of recs){fixes.push({id:`${audit.id}-${gid++}`,product_title:(audit.products as any)?.title||'Unknown',product_id:audit.product_id,rank:rec.rank,attribute:rec.attribute,category:rec.category,criticality:rec.criticality,action:rec.action,ai_impact:rec.ai_impact,status:'pending'})}
  }
  const seen=new Map<string,any>()
  for(const fix of fixes)if(!seen.has(fix.attribute))seen.set(fix.attribute,fix)
  const order={ULTRA:0,HIGH:1,MEDIUM:2,LOW:3}
  const deduped=Array.from(seen.values()).sort((a,b)=>order[a.criticality as keyof typeof order]-order[b.criticality as keyof typeof order])
  return NextResponse.json({fixes:deduped,total:deduped.length})
}
