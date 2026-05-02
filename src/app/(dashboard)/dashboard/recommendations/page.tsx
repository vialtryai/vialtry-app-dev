'use client'
import { useState, useEffect } from 'react'
interface Fix{id:string;product_title:string;product_id:string;rank:number;attribute:string;category:string;criticality:'ULTRA'|'HIGH'|'MEDIUM'|'LOW';action:string;ai_impact:string}
interface Brand{id:string;name:string}
const CRIT_ORDER={ULTRA:0,HIGH:1,MEDIUM:2,LOW:3}
export default function RecommendationsPage(){
  const [brands,setBrands]=useState<Brand[]>([])
  const [selectedBrand,setSelectedBrand]=useState<Brand|null>(null)
  const [fixes,setFixes]=useState<Fix[]>([])
  const [loading,setLoading]=useState(true)
  const [filter,setFilter]=useState<'all'|'ULTRA'|'HIGH'|'MEDIUM'>('all')
  const [done,setDone]=useState<Set<string>>(new Set())
  const [generating,setGenerating]=useState<string|null>(null)
  const [suggestions,setSuggestions]=useState<Record<string,string>>({})
  const [expanded,setExpanded]=useState<Set<string>>(new Set())

  useEffect(()=>{fetch('/api/brands').then(r=>r.json()).then(d=>{setBrands(d.brands||[]);if(d.brands?.length>0)setSelectedBrand(d.brands[0])})},[])
  useEffect(()=>{if(selectedBrand)loadFixes(selectedBrand.id)},[selectedBrand])

  async function loadFixes(brandId:string){
    setLoading(true)
    const res=await fetch(`/api/audit/fixes?brandId=${brandId}`)
    const data=await res.json()
    setFixes(data.fixes||[]);setLoading(false)
  }

  async function generateSuggestion(fix:Fix){
    setGenerating(fix.id)
    const res=await fetch('/api/audit/suggest',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({attribute:fix.attribute,product_title:fix.product_title,action:fix.action})})
    const data=await res.json()
    setSuggestions(prev=>({...prev,[fix.id]:data.suggestion}))
    setGenerating(null)
  }

  function toggleExpand(id:string){
    setExpanded(prev=>{const n=new Set(prev);n.has(id)?n.delete(id):n.add(id);return n})
  }

  const filtered=fixes.filter(f=>filter==='all'||f.criticality===filter).sort((a,b)=>CRIT_ORDER[a.criticality]-CRIT_ORDER[b.criticality])
  const ultraCount=fixes.filter(f=>f.criticality==='ULTRA').length
  const highCount=fixes.filter(f=>f.criticality==='HIGH').length

  return(
    <div className="p-8">
      <div className="flex items-center justify-between mb-8">
        <div><h1 className="text-white text-2xl font-bold">Fix Queue</h1><p className="text-gray-400 text-sm mt-1">Prioritized by AI visibility impact</p></div>
        {brands.length>1&&<select value={selectedBrand?.id||''} onChange={e=>setSelectedBrand(brands.find(b=>b.id===e.target.value)||null)} className="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none">{brands.map(b=><option key={b.id} value={b.id}>{b.name}</option>)}</select>}
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        {[{label:'Total fixes',val:fixes.length,c:undefined},{label:'ULTRA',val:ultraCount,c:'red'},{label:'HIGH',val:highCount,c:'orange'},{label:'Completed',val:done.size,c:'green'}].map(s=>(
          <div key={s.label} className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <p className="text-gray-500 text-xs uppercase tracking-wider mb-1">{s.label}</p>
            <p className={`text-2xl font-bold ${{red:'text-red-400',orange:'text-orange-400',green:'text-green-400'}[s.c||'']||'text-white'}`}>{s.val}</p>
          </div>
        ))}
      </div>
      <div className="flex gap-1 mb-6 bg-gray-900 border border-gray-800 rounded-lg p-1 w-fit">
        {(['all','ULTRA','HIGH','MEDIUM']as const).map(f=>(
          <button key={f} onClick={()=>setFilter(f)} className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${filter===f?'bg-gray-700 text-white':'text-gray-400 hover:text-white'}`}>{f==='all'?`All (${fixes.length})`:f}</button>
        ))}
      </div>
      {loading?<div className="text-gray-400 text-sm">Loading...</div>:fixes.length===0?(
        <div className="border border-dashed border-gray-700 rounded-xl p-12 text-center max-w-lg">
          <div className="text-4xl mb-4">⊕</div>
          <h2 className="text-white font-semibold text-lg mb-2">No fixes yet</h2>
          <p className="text-gray-400 text-sm mb-4">Run a PDP audit first.</p>
          <a href="/dashboard/audit" className="text-violet-400 hover:text-violet-300 text-sm">Go to PDP Audit →</a>
        </div>
      ):(
        <div className="space-y-3">
          {filtered.map(fix=>{
            const isExpanded=expanded.has(fix.id)
            const isDone=done.has(fix.id)
            const critColor={ULTRA:'bg-red-500/20 text-red-400 border-red-500/20',HIGH:'bg-orange-500/20 text-orange-400 border-orange-500/20',MEDIUM:'bg-yellow-500/20 text-yellow-400 border-yellow-500/20',LOW:'bg-gray-500/20 text-gray-400 border-gray-500/20'}[fix.criticality]
            return(
              <div key={fix.id} className={`bg-gray-900 border rounded-xl transition-all ${isDone?'border-gray-800 opacity-50':'border-gray-800 hover:border-gray-700'}`}>
                <div className="p-4">
                  <div className="flex items-start gap-3">
                    <button onClick={()=>setDone(prev=>{const n=new Set(prev);n.has(fix.id)?n.delete(fix.id):n.add(fix.id);return n})} className={`shrink-0 mt-0.5 w-4 h-4 rounded border transition-colors flex items-center justify-center ${isDone?'bg-green-500 border-green-500':'border-gray-600 hover:border-gray-400'}`}>
                      {isDone&&<span className="text-white text-xs">✓</span>}
                    </button>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1 flex-wrap">
                        <span className={`text-xs px-1.5 py-0.5 rounded border font-medium ${critColor}`}>{fix.criticality}</span>
                        <span className="text-gray-500 text-xs">{fix.category}</span>
                        <span className="text-gray-600 text-xs">·</span>
                        <span className="text-gray-500 text-xs truncate">{fix.product_title}</span>
                      </div>
                      <p className={`text-sm font-medium ${isDone?'line-through text-gray-500':'text-white'}`}>{fix.action}</p>
                      <p className="text-gray-500 text-xs mt-0.5">{fix.ai_impact}</p>
                    </div>
                    <button onClick={()=>{toggleExpand(fix.id);if(!suggestions[fix.id]&&!isExpanded)generateSuggestion(fix)}} disabled={generating===fix.id} className="text-xs px-2.5 py-1 bg-violet-600/20 hover:bg-violet-600/30 text-violet-400 rounded-lg border border-violet-500/20 transition-colors disabled:opacity-50 shrink-0">
                      {generating===fix.id?'...':isExpanded?'Hide':'✦ AI suggest'}
                    </button>
                  </div>
                  {isExpanded&&(
                    <div className="mt-3 ml-7">
                      {generating===fix.id?<div className="bg-gray-800 rounded-lg p-3 text-gray-400 text-xs">Generating...</div>:suggestions[fix.id]?(
                        <div className="bg-gray-800 rounded-lg p-3">
                          <p className="text-gray-300 text-xs leading-relaxed whitespace-pre-wrap">{suggestions[fix.id]}</p>
                          <button onClick={()=>{navigator.clipboard.writeText(suggestions[fix.id])}} className="mt-2 text-xs text-gray-500 hover:text-gray-300 transition-colors">⎘ Copy</button>
                        </div>
                      ):<div className="bg-gray-800 rounded-lg p-3 text-gray-500 text-xs">Loading suggestion...</div>}
                    </div>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
