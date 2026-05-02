import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'
export default async function DashboardPage(){
  const supabase=await createClient()
  const {data:{user}}=await supabase.auth.getUser()
  if(!user)redirect('/login')
  const {data:brands}=await supabase.from('brands').select('*').eq('user_id',user.id)
  if(!brands||brands.length===0)redirect('/onboarding')
  const brand=brands[0]
  const {data:audits}=await supabase.from('audits').select('*,products(title)').eq('brand_id',brand.id).eq('status','complete').order('created_at',{ascending:false}).limit(10)
  const {data:sovResults}=await supabase.from('sov_results').select('brand_mentioned,created_at').eq('brand_id',brand.id).order('created_at',{ascending:false}).limit(30)
  const avgCoreScore=audits&&audits.length>0?Math.round(audits.reduce((s,a)=>s+a.core_score,0)/audits.length):null
  const totalGaps=audits?audits.reduce((s,a)=>s+(Array.isArray(a.gaps)?a.gaps.length:0),0):0
  const ultraGaps=audits?audits.reduce((s,a)=>s+(Array.isArray(a.gaps)?a.gaps.filter((g:any)=>g.criticality==='ULTRA').length:0),0):0
  const sovMentions=sovResults?.filter(r=>r.brand_mentioned).length||0
  const sovTotal=sovResults?.length||0
  const sovPct=sovTotal>0?Math.round(sovMentions/sovTotal*100):null
  const allGaps:any[]=[];for(const audit of(audits||[])){if(Array.isArray(audit.gaps)){for(const gap of audit.gaps.slice(0,3))allGaps.push({...gap,product:(audit.products as any)?.title})}}
  const topGaps=allGaps.filter(g=>g.criticality==='ULTRA'||g.criticality==='HIGH').slice(0,5)
  const worstProducts=[...(audits||[])].sort((a,b)=>a.core_score-b.core_score).slice(0,3)
  const metrics=[
    {label:'Avg Core Score',value:avgCoreScore!==null?`${avgCoreScore}%`:'—',sub:audits?.length?`${audits.length} products`:'Run audit',href:'/dashboard/audit',color:avgCoreScore!==null?(avgCoreScore>=70?'green':avgCoreScore>=40?'yellow':'red'):undefined},
    {label:'AI Visibility',value:sovPct!==null?`${sovPct}%`:'—',sub:sovTotal?`${sovMentions}/${sovTotal} prompts`:'Run SOV',href:'/dashboard/visibility',color:sovPct!==null?(sovPct>=50?'green':sovPct>=25?'yellow':'red'):undefined},
    {label:'ULTRA Gaps',value:ultraGaps,sub:'Critical fixes',href:'/dashboard/recommendations',color:ultraGaps>0?'red':'green'},
    {label:'Total Fixes',value:totalGaps,sub:'All products',href:'/dashboard/recommendations',color:undefined},
  ]
  const colorMap:{[k:string]:string}={green:'text-green-400',yellow:'text-yellow-400',red:'text-red-400'}
  return(
    <div className="p-8">
      <div className="mb-8"><h1 className="text-white text-2xl font-bold">Overview</h1><p className="text-gray-400 text-sm mt-1">{brand.name} · {brand.shopify_domain}</p></div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        {metrics.map(m=>(
          <Link key={m.label} href={m.href} className="bg-gray-900 border border-gray-800 hover:border-gray-700 rounded-xl p-4 block transition-colors">
            <p className="text-gray-500 text-xs uppercase tracking-wider mb-1">{m.label}</p>
            <p className={`text-2xl font-bold ${m.color?colorMap[m.color]:'text-white'}`}>{m.value}</p>
            <p className="text-gray-600 text-xs mt-1">{m.sub}</p>
          </Link>
        ))}
      </div>
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
          <div className="flex items-center justify-between mb-4"><p className="text-gray-400 text-xs uppercase tracking-wider">Needs Most Work</p><Link href="/dashboard/audit" className="text-violet-400 text-xs">View all →</Link></div>
          {worstProducts.length===0?<div className="text-center py-4"><p className="text-gray-500 text-sm">No data yet</p><Link href="/dashboard/audit" className="text-violet-400 text-xs">Run audit →</Link></div>:(
            <div className="space-y-3">{worstProducts.map(a=>(
              <div key={a.id} className="flex items-center gap-3">
                <div className="flex-1 min-w-0"><p className="text-white text-sm truncate">{(a.products as any)?.title}</p><div className="w-full bg-gray-800 rounded-full h-1 mt-1.5"><div className={`h-1 rounded-full ${a.core_score>=70?'bg-green-500':a.core_score>=40?'bg-yellow-500':'bg-red-500'}`} style={{width:`${a.core_score}%`}}/></div></div>
                <span className={`text-sm font-bold shrink-0 ${a.core_score>=70?'text-green-400':a.core_score>=40?'text-yellow-400':'text-red-400'}`}>{a.core_score}%</span>
              </div>
            ))}</div>
          )}
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
          <div className="flex items-center justify-between mb-4"><p className="text-gray-400 text-xs uppercase tracking-wider">Top Priority Fixes</p><Link href="/dashboard/recommendations" className="text-violet-400 text-xs">Fix queue →</Link></div>
          {topGaps.length===0?<div className="text-center py-4"><p className="text-gray-500 text-sm">No gaps yet</p><Link href="/dashboard/audit" className="text-violet-400 text-xs">Run audit →</Link></div>:(
            <div className="space-y-2">{topGaps.map((gap,i)=>(
              <div key={i} className="flex items-start gap-2.5">
                <span className={`shrink-0 text-xs px-1.5 py-0.5 rounded font-medium mt-0.5 ${gap.criticality==='ULTRA'?'bg-red-500/20 text-red-400':'bg-orange-500/20 text-orange-400'}`}>{gap.criticality}</span>
                <div><p className="text-white text-xs">{gap.why_it_matters}</p><p className="text-gray-500 text-xs">{gap.product}</p></div>
              </div>
            ))}</div>
          )}
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
          <p className="text-gray-400 text-xs uppercase tracking-wider mb-4">Quick Actions</p>
          <div className="grid grid-cols-2 gap-3">
            {[{href:'/dashboard/audit',icon:'⊙',label:'PDP Audit',desc:'Score products'},{href:'/dashboard/visibility',icon:'◎',label:'AI SOV',desc:'Check visibility'},{href:'/dashboard/recommendations',icon:'⊕',label:'Fix Queue',desc:'Prioritized fixes'},{href:'/onboarding',icon:'🔌',label:'Add Brand',desc:'Connect store'}].map(a=>(
              <Link key={a.href} href={a.href} className="bg-gray-800 hover:bg-gray-700 border border-gray-700 rounded-lg p-3 block transition-colors">
                <p className="text-lg mb-1">{a.icon}</p><p className="text-white text-xs font-medium">{a.label}</p><p className="text-gray-500 text-xs">{a.desc}</p>
              </Link>
            ))}
          </div>
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-5">
          <div className="flex items-center justify-between mb-4"><p className="text-gray-400 text-xs uppercase tracking-wider">Recent SOV</p><Link href="/dashboard/visibility" className="text-violet-400 text-xs">Run check →</Link></div>
          {!sovResults||sovResults.length===0?<div className="text-center py-4"><p className="text-gray-500 text-sm">No checks yet</p><Link href="/dashboard/visibility" className="text-violet-400 text-xs">Run SOV →</Link></div>:(
            <div className="space-y-2">
              {sovResults.slice(0,8).map((r,i)=>(<div key={i} className="flex items-center gap-2"><span className={`text-xs w-4 shrink-0 ${r.brand_mentioned?'text-green-400':'text-red-400'}`}>{r.brand_mentioned?'✓':'✗'}</span><div className="flex-1 bg-gray-800 rounded-full h-1"><div className={`h-1 rounded-full ${r.brand_mentioned?'bg-green-500':'bg-transparent'}`} style={{width:'100%'}}/></div></div>))}
              <p className="text-gray-500 text-xs mt-2">{sovMentions}/{sovTotal} prompts mentioned your brand</p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
