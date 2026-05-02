export interface AuditResult {
  core_score: number; full_score: number
  category_scores: Record<string, CategoryScore>
  gaps: Gap[]; recommendations: Recommendation[]
}
export interface CategoryScore { name: string; score: number; max_score: number; percentage: number; gaps_count: number }
export interface Gap { category: string; attribute: string; criticality: 'ULTRA'|'HIGH'|'MEDIUM'|'LOW'; current_value: string|null; why_it_matters: string }
export interface Recommendation { rank: number; attribute: string; category: string; criticality: 'ULTRA'|'HIGH'|'MEDIUM'|'LOW'; action: string; ai_impact: string }

interface AttributeDef { category: string; attribute: string; label: string; criticality: 'ULTRA'|'HIGH'|'MEDIUM'|'LOW'; check: (p: any) => boolean }
const CRITICALITY_WEIGHT = { ULTRA: 4, HIGH: 3, MEDIUM: 2, LOW: 1 }

const ATTRIBUTES: AttributeDef[] = [
  { category:'Title', attribute:'title_exists', label:'Title exists', criticality:'ULTRA', check:(p)=>!!p.title?.trim() },
  { category:'Title', attribute:'title_length', label:'Title 40-80 chars', criticality:'ULTRA', check:(p)=>p.title?.length>=40&&p.title?.length<=80 },
  { category:'Title', attribute:'title_has_material', label:'Title has material', criticality:'HIGH', check:(p)=>/whey|protein|cotton|leather|steel|organic|natural|nylon|polyester|wool|silk/i.test(p.title) },
  { category:'Title', attribute:'title_has_brand', label:'Title has brand name', criticality:'HIGH', check:(p)=>!!p.vendor&&p.title?.toLowerCase().includes(p.vendor?.toLowerCase()) },
  { category:'Title', attribute:'title_no_caps_spam', label:'No ALL CAPS spam', criticality:'MEDIUM', check:(p)=>!/[A-Z]{5,}/.test(p.title) },
  { category:'Description', attribute:'desc_exists', label:'Description exists', criticality:'ULTRA', check:(p)=>!!p.body_html?.trim() },
  { category:'Description', attribute:'desc_length', label:'Description 300+ words', criticality:'ULTRA', check:(p)=>wordCount(p.body_html)>=300 },
  { category:'Description', attribute:'desc_has_ingredients', label:'Ingredients/materials mentioned', criticality:'HIGH', check:(p)=>/ingredient|material|made from|contain|composition|fabric/i.test(stripHtml(p.body_html)) },
  { category:'Description', attribute:'desc_has_benefits', label:'Benefits clearly stated', criticality:'HIGH', check:(p)=>/benefit|help|support|improve|boost|reduce|increase/i.test(stripHtml(p.body_html)) },
  { category:'Description', attribute:'desc_has_usage', label:'Usage mentioned', criticality:'HIGH', check:(p)=>/how to use|directions|apply|take|use|serving/i.test(stripHtml(p.body_html)) },
  { category:'Description', attribute:'desc_has_who_for', label:'Target audience mentioned', criticality:'MEDIUM', check:(p)=>/for men|for women|for athletes|ideal for|designed for|suitable for/i.test(stripHtml(p.body_html)) },
  { category:'Images', attribute:'images_exist', label:'Images exist', criticality:'ULTRA', check:(p)=>p.images?.length>0 },
  { category:'Images', attribute:'images_3plus', label:'3+ images', criticality:'HIGH', check:(p)=>p.images?.length>=3 },
  { category:'Images', attribute:'images_alt_text', label:'Alt text on images', criticality:'HIGH', check:(p)=>p.images?.some((img:any)=>!!img.alt?.trim()) },
  { category:'Images', attribute:'images_6plus', label:'6+ images', criticality:'MEDIUM', check:(p)=>p.images?.length>=6 },
  { category:'Variants', attribute:'variants_exist', label:'Variants defined', criticality:'ULTRA', check:(p)=>p.variants?.length>0 },
  { category:'Variants', attribute:'variants_have_sku', label:'SKUs on all variants', criticality:'HIGH', check:(p)=>p.variants?.every((v:any)=>!!v.sku?.trim()) },
  { category:'Variants', attribute:'variants_have_weight', label:'Weight on all variants', criticality:'HIGH', check:(p)=>p.variants?.every((v:any)=>v.grams>0) },
  { category:'Variants', attribute:'variants_have_price', label:'Price on all variants', criticality:'ULTRA', check:(p)=>p.variants?.every((v:any)=>parseFloat(v.price)>0) },
  { category:'Metadata', attribute:'product_type', label:'Product type set', criticality:'ULTRA', check:(p)=>!!p.product_type?.trim() },
  { category:'Metadata', attribute:'vendor_set', label:'Vendor set', criticality:'HIGH', check:(p)=>!!p.vendor?.trim() },
  { category:'Metadata', attribute:'tags_exist', label:'Tags exist', criticality:'HIGH', check:(p)=>p.tags?.length>0 },
  { category:'Metadata', attribute:'tags_5plus', label:'5+ tags', criticality:'MEDIUM', check:(p)=>p.tags?.split(',').filter(Boolean).length>=5 },
  { category:'Metadata', attribute:'handle_clean', label:'Clean URL handle', criticality:'MEDIUM', check:(p)=>/^[a-z0-9-]+$/.test(p.handle)&&!p.handle.includes('copy') },
  { category:'Schema', attribute:'has_structured_data', label:'Schema.org markup', criticality:'ULTRA', check:()=>false },
  { category:'Schema', attribute:'has_brand_schema', label:'Brand in schema', criticality:'HIGH', check:()=>false },
  { category:'AI Signals', attribute:'has_faq', label:'FAQ section', criticality:'ULTRA', check:(p)=>/faq|frequently asked|q:|question/i.test(stripHtml(p.body_html)) },
  { category:'AI Signals', attribute:'has_specifications', label:'Specs present', criticality:'HIGH', check:(p)=>/specification|spec:|dimensions|weight:|size:/i.test(stripHtml(p.body_html)) },
  { category:'AI Signals', attribute:'has_certifications', label:'Certifications mentioned', criticality:'HIGH', check:(p)=>/certified|fssai|iso|organic certified|gmp|lab tested/i.test(stripHtml(p.body_html)) },
  { category:'AI Signals', attribute:'has_comparison', label:'Comparison language', criticality:'MEDIUM', check:(p)=>/vs|versus|compared to|better than|unlike/i.test(stripHtml(p.body_html)) },
  { category:'AI Signals', attribute:'has_social_proof', label:'Social proof', criticality:'MEDIUM', check:(p)=>/trusted|customers|sold|reviews|rated|award/i.test(stripHtml(p.body_html)) },
]

export function auditProduct(product: any): AuditResult {
  const categoryMap: Record<string,{score:number;max:number;gaps:Gap[]}> = {}
  let coreScore=0,coreMax=0,fullScore=0,fullMax=0
  for (const attr of ATTRIBUTES) {
    const weight=CRITICALITY_WEIGHT[attr.criticality]
    const passed=attr.check(product)
    fullMax+=weight; if(passed) fullScore+=weight
    if(attr.criticality==='ULTRA'||attr.criticality==='HIGH'){coreMax+=weight;if(passed)coreScore+=weight}
    if(!categoryMap[attr.category]) categoryMap[attr.category]={score:0,max:0,gaps:[]}
    categoryMap[attr.category].max+=weight
    if(passed) categoryMap[attr.category].score+=weight
    else categoryMap[attr.category].gaps.push({category:attr.category,attribute:attr.attribute,criticality:attr.criticality,current_value:null,why_it_matters:getWhyItMatters(attr.attribute)})
  }
  const category_scores: Record<string,CategoryScore>={}
  for(const [cat,data] of Object.entries(categoryMap)){
    category_scores[cat]={name:cat,score:data.score,max_score:data.max,percentage:Math.round(data.score/data.max*100),gaps_count:data.gaps.length}
  }
  const gaps=Object.values(categoryMap).flatMap(d=>d.gaps).sort((a,b)=>CRITICALITY_WEIGHT[b.criticality]-CRITICALITY_WEIGHT[a.criticality])
  const recommendations=gaps.slice(0,10).map((gap,i)=>({rank:i+1,attribute:gap.attribute,category:gap.category,criticality:gap.criticality,action:getAction(gap.attribute),ai_impact:getAiImpact(gap.attribute)}))
  return {core_score:Math.round(coreScore/coreMax*100),full_score:Math.round(fullScore/fullMax*100),category_scores,gaps,recommendations}
}

function stripHtml(html:string):string{if(!html)return'';return html.replace(/<[^>]*>/g,' ').replace(/\s+/g,' ').trim()}
function wordCount(html:string):number{const t=stripHtml(html);if(!t)return 0;return t.split(/\s+/).filter(Boolean).length}

function getWhyItMatters(a:string):string{
  const m:Record<string,string>={title_exists:'No title = invisible to AI agents',title_length:'Short titles lack context',desc_exists:'No description = AI cannot understand product',desc_length:'Short descriptions miss AI training signals',desc_has_ingredients:'Ingredient queries are top AI shopping intent',has_faq:'FAQ format directly answers conversational AI queries',has_structured_data:'Schema markup is how AI agents read product data',product_type:'Product type is primary AI categorization signal'}
  return m[a]||'Missing attribute reduces AI visibility score'
}
function getAction(a:string):string{
  const m:Record<string,string>={title_exists:'Add a descriptive product title',title_length:'Expand title to 40-80 characters',title_has_material:'Add main material or ingredient to title',desc_exists:'Write a product description (min 300 words)',desc_length:'Expand description to 300+ words',desc_has_ingredients:'Add ingredients/materials section',desc_has_benefits:'Add clear benefits section',desc_has_usage:'Add "How to use" section',has_faq:'Add FAQ section with top 5 customer questions',has_structured_data:'Add Schema.org Product JSON-LD markup',product_type:'Set product type in Shopify',vendor_set:'Set vendor/brand name in Shopify',tags_exist:'Add relevant tags',images_alt_text:'Add descriptive alt text to all images',variants_have_sku:'Add SKU codes to all variants'}
  return m[a]||'Fix this attribute to improve AI visibility'
}
function getAiImpact(a:string):string{
  const hi=['has_faq','has_structured_data','desc_has_ingredients','desc_length','has_certifications','title_has_material']
  const mid=['desc_has_benefits','images_alt_text','product_type','desc_has_usage']
  if(hi.includes(a))return 'High — directly improves AI agent discoverability'
  if(mid.includes(a))return 'Medium — improves AI recommendation matching'
  return 'Low — incremental visibility improvement'
}
