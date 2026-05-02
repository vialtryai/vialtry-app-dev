'use client'
import { useState } from 'react'
import { useRouter } from 'next/navigation'

export default function OnboardingPage() {
  const [step, setStep] = useState(1)
  const [brandName, setBrandName] = useState('')
  const [shopDomain, setShopDomain] = useState('')
  const [error, setError] = useState('')

  function handleConnectShopify() {
    const domain = shopDomain.replace('https://','').replace('http://','').replace(/\/$/,'').trim()
    if (!domain.includes('.myshopify.com')) {
      setError('Enter valid .myshopify.com domain')
      return
    }
    sessionStorage.setItem('vialtry_brand_name', brandName)
    window.location.href = `/api/shopify/oauth/start?shop=${domain}`
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
              <input type="text" value={brandName} onChange={e=>setBrandName(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="e.g. Iron Asylum"/>
            </div>
            <button onClick={()=>setStep(2)} disabled={!brandName.trim()} className="w-full bg-violet-600 hover:bg-violet-500 disabled:bg-gray-800 disabled:text-gray-600 disabled:cursor-not-allowed text-white font-medium rounded-lg py-2.5 text-sm transition-colors">Continue</button>
          </>}
          {step===2 && <>
            <div><h2 className="text-white font-semibold text-lg mb-1">Connect Shopify</h2><p className="text-gray-400 text-sm">Enter your store domain.</p></div>
            {error && <div className="bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2 text-red-400 text-sm">{error}</div>}
            <div>
              <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Shopify domain</label>
              <input type="text" value={shopDomain} onChange={e=>setShopDomain(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="yourstore.myshopify.com"/>
            </div>
            <div className="flex gap-3">
              <button onClick={()=>setStep(1)} className="px-4 py-2.5 text-gray-400 hover:text-white text-sm transition-colors">Back</button>
              <button onClick={handleConnectShopify} disabled={!shopDomain.trim()} className="flex-1 bg-violet-600 hover:bg-violet-500 disabled:bg-gray-800 disabled:text-gray-600 disabled:cursor-not-allowed text-white font-medium rounded-lg py-2.5 text-sm transition-colors">Connect with Shopify</button>
            </div>
          </>}
        </div>
        <p className="text-gray-600 text-xs text-center mt-4">Read-only access. We never modify your store.</p>
      </div>
    </div>
  )
}
