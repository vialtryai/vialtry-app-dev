import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import RecommendationsClient from './RecommendationsClient'

export default async function RecommendationsPage() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')
  const { data: brands } = await supabase.from('brands').select('id,name').limit(10)
  if (!brands || brands.length === 0) redirect('/onboarding')
  return <RecommendationsClient brands={brands} />
}
