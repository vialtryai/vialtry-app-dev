'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

export default function OnboardingPage() {
  const [step, setStep] = useState(1)
  const [brandName, setBrandName] = useState('')
  const [shopifyDomain, setShopifyDomain] = useState('')
  const [accessToken, setAccessToken] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  async function handleConnect() {
    setLoading(true)
    setError('')
    const domain = shopifyDomain.replace('https://','').replace('http://','').replace(/\/$/,'').trim()
    const res = await fetch('/api/shopify/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ domain, accessToken }),
    })
    const data = await res.json()
    if (!res.ok) { setError(data.error || 'Could not connect'); setLoading(false); return }
    const { data: { user } } = await supabase.auth.getUser()
    const { error: dbError } = await supabase.from('brands').insert({
      user_id: user!.id,
      name: brandName || data.shopName,
      shopify_domain: domain,
      shopify_access_token: accessToken,
      status: 'active',
    })
    if (dbError) { setError(dbError.message); setLoading(false); return }
    router.push('/dashboard')
  }

  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center px-4">
      <div className="w-full max-w-lg">
        <div className="mb-8 text-center">
          <h1 className="text-2xl font-bold text-white tracking-tight">vialtry</h1>
          <p className="text-gray-400 text-sm mt-1">Connect your Shopify store</p>
        </div>
        <div className="flex items-center justify-center gap-2 mb-8">
          {[1,2].map(s => <div key={s} className={`h-1.5 w-12 rounded-full transition-colors ${step>=s?'bg-violet-500':'bg-gray-800'}`}/>)}
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-5">
          {step===1 && <>
            <div><h2 className="text-white font-semibold text-lg mb-1">Your brand</h2><p className="text-gray-400 text-sm">What should we call your brand?</p></div>
            <div>
              <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Brand name</label>
              <input type="text" value={brandName} onChange={e=>setBrandName(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="e.g. TDK Supplements"/>
            </div>
            <button onClick={()=>setStep(2)} disabled={!brandName.trim()} className="w-full bg-violet-600 hover:bg-violet-500 disabled:bg-gray-800 disabled:text-gray-600 disabled:cursor-not-allowed text-white font-medium rounded-lg py-2.5 text-sm transition-colors">Continue →</button>
          </>}
          {step===2 && <>
            <div><h2 className="text-white font-semibold text-lg mb-1">Connect Shopify</h2><p className="text-gray-400 text-sm">We need read access to your products.</p></div>
            <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-4 space-y-2">
              <p className="text-gray-300 text-xs font-medium uppercase tracking-wider">How to get your API token</p>
              <ol className="text-gray-400 text-xs space-y-1.5 list-decimal list-inside">
                <li>Shopify Admin → Settings → Apps and sales channels</li>
                <li>Click <span className="text-white">Develop apps</span> → Create an app</li>
                <li>Configure Admin API scopes: <span className="text-violet-400">read_products, read_inventory</span></li>
                <li>Install app → Copy <span className="text-white">Admin API access token</span></li>
              </ol>
            </div>
            {error && <div className="bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2 text-red-400 text-sm">{error}</div>}
            <div className="space-y-3">
              <div>
                <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Shopify domain</label>
                <input type="text" value={shopifyDomain} onChange={e=>setShopifyDomain(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="yourstore.myshopify.com"/>
              </div>
              <div>
                <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Admin API access token</label>
                <input type="password" value={accessToken} onChange={e=>setAccessToken(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="shpat_xxxxxxxxxxxx"/>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={()=>setStep(1)} className="px-4 py-2.5 text-gray-400 hover:text-white text-sm transition-colors">← Back</button>
              <button onClick={handleConnect} disabled={loading||!shopifyDomain.trim()||!accessToken.trim()} className="flex-1 bg-violet-600 hover:bg-violet-500 disabled:bg-gray-800 disabled:text-gray-600 disabled:cursor-not-allowed text-white font-medium rounded-lg py-2.5 text-sm transition-colors">{loading?'Connecting...':'Connect store'}</button>
            </div>
          </>}
        </div>
        <p className="text-gray-600 text-xs text-center mt-4">Your token is encrypted and stored securely. Read-only access only.</p>
      </div>
    </div>
  )
}
