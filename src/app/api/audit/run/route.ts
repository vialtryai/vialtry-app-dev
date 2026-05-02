import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { auditProduct } from '@/lib/scoring/pdp'
export async function POST(request: Request) {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) return NextResponse.json({error:'Unauthorized'},{status:401})
  const {brandId} = await request.json()
  const {data:brand} = await supabase.from('brands').select('*').eq('id',brandId).eq('user_id',user.id).single()
  if(!brand) return NextResponse.json({error:'Brand not found'},{status:404})
  const {data:products} = await supabase.from('products').select('*').eq('brand_id',brandId).limit(10)
  if(!products||products.length===0) return NextResponse.json({error:'No products found. Sync products first.'},{status:400})
  const results=[]
  for(const product of products){
    const {data:audit} = await supabase.from('audits').insert({brand_id:brandId,product_id:product.id,status:'running'}).select().single()
    try{
      const result=auditProduct(product.raw_data)
      await supabase.from('audits').update({core_score:result.core_score,full_score:result.full_score,category_scores:result.category_scores,gaps:result.gaps,recommendations:result.recommendations,status:'complete'}).eq('id',audit!.id)
      results.push({product_id:product.id,title:product.title,core_score:result.core_score,full_score:result.full_score,gaps_count:result.gaps.length})
    }catch{
      await supabase.from('audits').update({status:'failed'}).eq('id',audit!.id)
    }
  }
  return NextResponse.json({success:true,audited:results.length,results,avg_core_score:Math.round(results.reduce((s,r)=>s+r.core_score,0)/results.length)})
}
