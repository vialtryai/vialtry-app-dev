'use client'
import { useState } from 'react'
interface Brand{id:string;name:string;shopify_domain:string}
interface Audit{id:string;core_score:number;full_score:number;gaps:any[];recommendations:any[];category_scores:Record<string,any>;products:{title:string;handle:string}}
export default function AuditClient({brand,audits:initialAudits}:{brand:Brand;audits:Audit[]}){
  const [audits,setAudits]=useState(initialAudits)
  const [syncing,setSyncing]=useState(false)
  const [running,setRunning]=useState(false)
  const [status,setStatus]=useState('')
  const [selected,setSelected]=useState<Audit|null>(null)
  async function syncProducts(){
    setSyncing(true);setStatus('Syncing products from Shopify...')
    const res=await fetch('/api/shopify/products',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({brandId:brand.id})})
    const data=await res.json();setSyncing(false)
    if(data.success)setStatus(`✓ Synced ${data.count} products`);else setStatus(`✗ ${data.error}`)
  }
  async function runAudit(){
    setRunning(true);setStatus('Running PDP audit...')
    const res=await fetch('/api/audit/run',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({brandId:brand.id})})
    const data=await res.json();setRunning(false)
    if(data.success){setStatus(`✓ Audited ${data.audited} products — avg score: ${data.avg_core_score}%`);window.location.reload()}
    else setStatus(`✗ ${data.error}`)
  }
  return(
    <div className="p-8">
      <div className="flex items-center justify-between mb-8">
        <div><h1 className="text-white text-2xl font-bold">PDP Audit</h1><p className="text-gray-400 text-sm mt-1">{brand.name} · {brand.shopify_domain}</p></div>
        <div className="flex gap-3">
          <button onClick={syncProducts} disabled={syncing} className="px-4 py-2 bg-gray-800 hover:bg-gray-700 disabled:opacity-50 text-white text-sm rounded-lg border border-gray-700">{syncing?'Syncing...':'↻ Sync products'}</button>
          <button onClick={runAudit} disabled={running} className="px-4 py-2 bg-violet-600 hover:bg-violet-500 disabled:opacity-50 text-white text-sm rounded-lg">{running?'Running...':'▶ Run audit'}</button>
        </div>
      </div>
      {status&&<div className="mb-6 bg-gray-900 border border-gray-700 rounded-lg px-4 py-2.5 text-sm text-gray-300">{status}</div>}
      {audits.length===0?(
        <div className="border border-dashed border-gray-700 rounded-xl p-12 text-center max-w-lg mx-auto mt-8"><div className="text-4xl mb-4">⊙</div><h2 className="text-white font-semibold text-lg mb-2">No audits yet</h2><p className="text-gray-400 text-sm">Sync products then run audit.</p></div>
      ):(
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="space-y-3">
            {audits.map(audit=>(
              <div key={audit.id} onClick={()=>setSelected(audit)} className={`bg-gray-900 border rounded-xl p-4 cursor-pointer transition-colors ${selected?.id===audit.id?'border-violet-500':'border-gray-800 hover:border-gray-700'}`}>
                <div className="flex items-center justify-between mb-3">
                  <p className="text-white text-sm font-medium truncate flex-1 mr-4">{audit.products?.title}</p>
                  <span className={`text-sm font-bold px-2 py-0.5 rounded ${audit.core_score>=70?'text-green-400 bg-green-500/10':audit.core_score>=40?'text-yellow-400 bg-yellow-500/10':'text-red-400 bg-red-500/10'}`}>{audit.core_score}%</span>
                </div>
                <div className="flex gap-4 items-center">
                  <div><p className="text-gray-500 text-xs mb-1">Core</p><div className="w-20 bg-gray-800 rounded-full h-1"><div className="h-1 rounded-full bg-violet-500" style={{width:`${audit.core_score}%`}}/></div></div>
                  <div><p className="text-gray-500 text-xs mb-1">Full</p><div className="w-20 bg-gray-800 rounded-full h-1"><div className="h-1 rounded-full bg-teal-500" style={{width:`${audit.full_score}%`}}/></div></div>
                  <div className="ml-auto text-right"><p className="text-gray-500 text-xs">Gaps</p><p className="text-red-400 text-sm font-medium">{audit.gaps?.length||0}</p></div>
                </div>
              </div>
            ))}
          </div>
          {selected&&(
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-5 space-y-5">
              <h3 className="text-white font-semibold">{selected.products?.title}</h3>
              <div>
                <p className="text-gray-400 text-xs uppercase tracking-wider mb-3">Category Scores</p>
                <div className="space-y-2">
                  {Object.values(selected.category_scores||{}).map((cat:any)=>(
                    <div key={cat.name} className="flex items-center gap-3">
                      <p className="text-gray-300 text-xs w-24 shrink-0">{cat.name}</p>
                      <div className="flex-1 bg-gray-800 rounded-full h-1.5"><div className={`h-1.5 rounded-full ${cat.percentage>=70?'bg-green-500':cat.percentage>=40?'bg-yellow-500':'bg-red-500'}`} style={{width:`${cat.percentage}%`}}/></div>
                      <p className="text-gray-400 text-xs w-8 text-right">{cat.percentage}%</p>
                    </div>
                  ))}
                </div>
              </div>
              <div>
                <p className="text-gray-400 text-xs uppercase tracking-wider mb-3">Top Fixes</p>
                <div className="space-y-2">
                  {(selected.recommendations||[]).slice(0,5).map((rec:any)=>(
                    <div key={rec.rank} className="flex gap-3 bg-gray-800/50 rounded-lg p-3">
                      <span className={`text-xs px-1.5 py-0.5 rounded font-medium shrink-0 ${rec.criticality==='ULTRA'?'bg-red-500/20 text-red-400':rec.criticality==='HIGH'?'bg-orange-500/20 text-orange-400':'bg-yellow-500/20 text-yellow-400'}`}>{rec.criticality}</span>
                      <div><p className="text-white text-xs font-medium">{rec.action}</p><p className="text-gray-500 text-xs mt-0.5">{rec.ai_impact}</p></div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
