import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AuditClient from './AuditClient'
export default async function AuditPage() {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) redirect('/login')
  const {data:brands} = await supabase.from('brands').select('*').eq('user_id',user.id)
  if(!brands||brands.length===0) redirect('/onboarding')
  const brand = brands[0]
  const audits = ((await supabase.from('audits').select('*, products(title,handle,shopify_product_id)').eq('brand_id',brand.id).eq('status','complete').order('created_at',{ascending:false})) as any).data
  return <AuditClient brand={brand} audits={audits||[]} />
}
