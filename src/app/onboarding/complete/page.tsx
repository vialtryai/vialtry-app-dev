'use client'
import { useEffect } from 'react'
import { useRouter, useSearchParams } from 'next/navigation'
import { createClient } from '@/lib/supabase/client'

export default function OnboardingCompletePage() {
  const router = useRouter()
  const searchParams = useSearchParams()
  const supabase = createClient()

  useEffect(() => {
    async function saveStore() {
      const shop = searchParams.get('shop')
      const token = searchParams.get('token')
      const shopName = searchParams.get('shopName')

      if (!shop || !token) {
        router.push('/onboarding?error=missing_params')
        return
      }

      const { data: { user } } = await supabase.auth.getUser()

      if (!user) {
        router.push('/login')
        return
      }

      const { error } = await supabase.from('brands').insert({
        user_id: user.id,
        name: shopName || shop,
        shopify_domain: shop,
        shopify_access_token: token,
        status: 'active',
      } as never)

      if (error) {
        router.push('/onboarding?error=save_failed')
        return
      }

      router.push('/dashboard')
    }

    saveStore()
  }, [])

  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center">
      <div className="text-center">
        <div className="w-8 h-8 border-2 border-violet-500 border-t-transparent rounded-full animate-spin mx-auto mb-4"></div>
        <p className="text-gray-400 text-sm">Connecting your store...</p>
      </div>
    </div>
  )
}
