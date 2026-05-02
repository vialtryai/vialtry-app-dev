'use client'
import { useState, useEffect } from 'react'

const CATEGORIES = ['protein supplements','whey protein','pre-workout supplements','skincare products','face serum','moisturizer','sunscreen','hair care products','shampoo','hair oil','fitness equipment','yoga mat','resistance bands','pet food','dog food','cat food','home decor','bedding','mattress','mens grooming','beard oil','face wash for men','womens fashion','ethnic wear','kurta']

interface Brand{id:string;name:string;shopify_domain:string}

export default function VisibilityPage(){
  const [brands,setBrands]=useState<Brand[]>([])
  const [selectedBrand,setSelectedBrand]=useState<Brand|null>(null)
  const [category,setCategory]=useState('')
  const [promptCount,setPromptCount]=useState(5)
  const [running,setRunning]=useState(false)
  const [status,setStatus]=useState('')
  const [summary,setSummary]=useState<any>(null)
  const [history,setHistory]=useState<any>(null)
  const [activeTab,setActiveTab]=useState<'run'|'history'>('run')

  useEffect(()=>{
    fetch('/api/brands').then(r=>r.json()).then(d=>{setBrands(d.brands||[]);if(d.brands?.length>0)setSelectedBrand(d.brands[0])})
  },[])

  useEffect(()=>{if(selectedBrand&&activeTab==='history')loadHistory()},[selectedBrand,activeTab])

  async function loadHistory(){
    if(!selectedBrand)return
    const res=await fetch(`/api/sov/history?brandId=${selectedBrand.id}`)
    setHistory(await res.json())
  }

  async function runSOV(){
    if(!selectedBrand||!category.trim())return
    setRunning(true);setSummary(null)
    setStatus(`Running ${promptCount} prompts for "${category}"... (~${promptCount*2}s)`)
    const res=await fetch('/api/sov/run',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({brandId:selectedBrand.id,category:category.trim(),promptCount})})
    const data=await res.json();setRunning(false)
    if(data.success){setSummary(data.summary);setStatus('')}else setStatus(`✗ ${data.error}`)
  }

  return(
    <div className="p-8">
      <div className="mb-8"><h1 className="text-white text-2xl font-bold">AI Visibility</h1><p className="text-gray-400 text-sm mt-1">Is your brand showing up when AI recommends products?</p></div>
      <div className="flex gap-1 mb-6 bg-gray-900 border border-gray-800 rounded-lg p-1 w-fit">
        {(['run','history']as const).map(tab=>(
          <button key={tab} onClick={()=>setActiveTab(tab)} className={`px-4 py-1.5 rounded-md text-sm font-medium transition-colors capitalize ${activeTab===tab?'bg-gray-700 text-white':'text-gray-400 hover:text-white'}`}>{tab==='run'?'▶ Run Check':'📊 History'}</button>
        ))}
      </div>
      {activeTab==='run'&&(
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
          <div className="space-y-5">
            {brands.length>1&&(
              <div>
                <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Brand</label>
                <select value={selectedBrand?.id||''} onChange={e=>setSelectedBrand(brands.find(b=>b.id===e.target.value)||null)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500">
                  {brands.map(b=><option key={b.id} value={b.id}>{b.name}</option>)}
                </select>
              </div>
            )}
            <div>
              <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Product Category</label>
              <input type="text" value={category} onChange={e=>setCategory(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500" placeholder="e.g. whey protein, face serum" list="cats"/>
              <datalist id="cats">{CATEGORIES.map(c=><option key={c} value={c}/>)}</datalist>
              <p className="text-gray-600 text-xs mt-1">Be specific — "whey protein" better than "supplements"</p>
            </div>
            <div>
              <label className="text-gray-400 text-xs uppercase tracking-wider mb-2 block">Prompts — <span className="text-white">{promptCount}</span><span className="text-gray-600 ml-2">(~{promptCount*2}s)</span></label>
              <input type="range" min={3} max={10} value={promptCount} onChange={e=>setPromptCount(Number(e.target.value))} className="w-full"/>
              <div className="flex justify-between text-gray-600 text-xs mt-1"><span>3 quick</span><span>10 thorough</span></div>
            </div>
            <button onClick={runSOV} disabled={running||!category.trim()||!selectedBrand} className="w-full bg-violet-600 hover:bg-violet-500 disabled:bg-gray-800 disabled:text-gray-600 disabled:cursor-not-allowed text-white font-medium rounded-lg py-2.5 text-sm transition-colors">{running?'Running...':'▶ Run SOV check'}</button>
            {status&&<div className="bg-gray-900 border border-gray-700 rounded-lg px-4 py-3 text-sm text-gray-300">{status}</div>}
          </div>
          <div>
            {summary?(
              <div className="space-y-4">
                <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
                  <p className="text-gray-400 text-xs uppercase tracking-wider mb-2">SOV for "{summary.brand_name}"</p>
                  <div className="flex items-end gap-3 mb-3">
                    <span className={`text-5xl font-bold ${summary.sov_percentage>=60?'text-green-400':summary.sov_percentage>=30?'text-yellow-400':'text-red-400'}`}>{summary.sov_percentage}%</span>
                    <span className="text-gray-400 text-sm mb-2">{summary.mentions}/{summary.total_prompts} prompts</span>
                  </div>
                  <div className="w-full bg-gray-800 rounded-full h-2"><div className={`h-2 rounded-full ${summary.sov_percentage>=60?'bg-green-500':summary.sov_percentage>=30?'bg-yellow-500':'bg-red-500'}`} style={{width:`${summary.sov_percentage}%`}}/></div>
                  <p className="text-gray-500 text-xs mt-2">{summary.sov_percentage>=60?'Strong AI presence':summary.sov_percentage>=30?'Moderate — needs improvement':'Weak — brand nearly invisible to AI'}</p>
                </div>
                {summary.top_competitors?.length>0&&(
                  <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
                    <p className="text-gray-400 text-xs uppercase tracking-wider mb-3">Who AI recommends instead</p>
                    <div className="space-y-2">{summary.top_competitors.map((c:any)=>(<div key={c.name} className="flex items-center justify-between"><p className="text-gray-300 text-sm capitalize">{c.name}</p><span className="text-orange-400 text-xs">{c.count} mentions</span></div>))}</div>
                  </div>
                )}
                <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
                  <p className="text-gray-400 text-xs uppercase tracking-wider mb-3">Prompt by prompt</p>
                  <div className="space-y-2">{summary.results.map((r:any,i:number)=>(<div key={i} className="flex items-start gap-2"><span className={`shrink-0 text-xs px-1.5 py-0.5 rounded font-medium mt-0.5 ${r.brand_mentioned?'bg-green-500/10 text-green-400':'bg-red-500/10 text-red-400'}`}>{r.brand_mentioned?'✓':'✗'}</span><p className="text-gray-400 text-xs">{r.prompt}</p></div>))}</div>
                </div>
              </div>
            ):(
              <div className="border border-dashed border-gray-700 rounded-xl p-8 text-center"><div className="text-3xl mb-3">◎</div><p className="text-gray-400 text-sm">Results will appear here</p></div>
            )}
          </div>
        </div>
      )}
      {activeTab==='history'&&(
        <div>
          {!history?<div className="text-gray-400 text-sm">Loading...</div>:history.total===0?(
            <div className="border border-dashed border-gray-700 rounded-xl p-12 text-center max-w-lg"><p className="text-gray-400 text-sm">No checks run yet.</p></div>
          ):(
            <div className="space-y-6">
              <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
                {[{label:'Total prompts',value:history.total},{label:'Brand mentions',value:history.mentions},{label:'SOV %',value:`${history.sov_percentage}%`},{label:'Top competitor',value:history.top_competitors?.[0]?.name||'—'}].map(s=>(
                  <div key={s.label} className="bg-gray-900 border border-gray-800 rounded-xl p-4"><p className="text-gray-500 text-xs uppercase tracking-wider mb-1">{s.label}</p><p className="text-xl font-bold text-white">{s.value}</p></div>
                ))}
              </div>
              {history.top_competitors?.length>0&&(
                <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
                  <p className="text-gray-400 text-xs uppercase tracking-wider mb-4">Competitor SOV</p>
                  <div className="space-y-3">{history.top_competitors.map((c:any)=>(<div key={c.name} className="flex items-center gap-3"><p className="text-gray-300 text-sm w-32 shrink-0 capitalize">{c.name}</p><div className="flex-1 bg-gray-800 rounded-full h-1.5"><div className="h-1.5 rounded-full bg-orange-500" style={{width:`${Math.round(c.count/history.total*100)}%`}}/></div><p className="text-gray-400 text-xs w-8 text-right">{Math.round(c.count/history.total*100)}%</p></div>))}</div>
                </div>
              )}
              <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
                <p className="text-gray-400 text-xs uppercase tracking-wider mb-4">Recent Prompts</p>
                <div className="space-y-2">{history.results.slice(0,10).map((r:any)=>(<div key={r.id} className="flex items-start gap-3 py-2 border-b border-gray-800 last:border-0"><span className={`shrink-0 mt-0.5 text-xs px-1.5 py-0.5 rounded font-medium ${r.brand_mentioned?'bg-green-500/10 text-green-400':'bg-red-500/10 text-red-400'}`}>{r.brand_mentioned?'✓':'✗'}</span><p className="text-gray-300 text-xs flex-1">{r.prompt}</p>{r.position&&<span className="text-gray-500 text-xs shrink-0">#{r.position}</span>}</div>))}</div>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
