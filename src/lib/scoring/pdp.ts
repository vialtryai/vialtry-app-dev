// Vialtry Scoring Engine — North America Edition
// Orchestrator: detects vertical, runs universal + vertical-specific attributes

import { universalAttributes } from './universal'
import { fashionAttributes } from './verticals/fashion'
import { beautyAttributes } from './verticals/beauty'
import { homeAttributes } from './verticals/home'
import { sportsAttributes } from './verticals/sports'
import { healthAttributes } from './verticals/health'
import { babyAttributes } from './verticals/baby'
import { petAttributes } from './verticals/pet'
import { electronicsAttributes } from './verticals/electronics'
import { automotiveAttributes } from './verticals/automotive'

export interface AuditResult {
  core_score: number; full_score: number; vertical: string
  category_scores: Record<string, CategoryScore>
  gaps: Gap[]; recommendations: Recommendation[]
}
export interface CategoryScore { name: string; score: number; max_score: number; percentage: number; gaps_count: number }
export interface Gap { category: string; attribute: string; criticality: 'ULTRA'|'HIGH'|'MEDIUM'|'LOW'; current_value: string|null; why_it_matters: string; auto_fix_instruction: string }
export interface Recommendation { rank: number; attribute: string; category: string; criticality: 'ULTRA'|'HIGH'|'MEDIUM'|'LOW'; action: string; ai_impact: string; auto_fix_instruction: string }
export interface AttributeDef { category: string; attribute: string; label: string; ai_weight: number; required: 'Required'|'Recommended'|'Optional'; auto_fix: string; check: (p: any) => boolean }

export const WEIGHT: Record<'Required'|'Recommended'|'Optional', number> = { Required: 3, Recommended: 2, Optional: 1 }

export function getCriticality(weight: number, required: string): 'ULTRA'|'HIGH'|'MEDIUM'|'LOW' {
  if (required === 'Required' && weight >= 10) return 'ULTRA'
  if (required === 'Required' && weight >= 8) return 'HIGH'
  if (weight >= 7) return 'MEDIUM'
  return 'LOW'
}

function detectVertical(product: any): string {
  const combined = `${product.product_type||''} ${product.tags||''} ${product.title||''}`.toLowerCase()
  if (/running shoe|athletic shoe|trail shoe|basketball shoe|tennis shoe|cycling shoe|running|yoga|gym|cycling|swimming|hiking|tennis|basketball|football|dumbbell|barbell|kettlebell|treadmill|fitness|workout|sport|athletic|exercise/i.test(combined)) return 'sports'
  if (/serum|moisturizer|moisturiser|cleanser|sunscreen|spf|skincare|skin care|shampoo|conditioner|hair|makeup|lipstick|foundation|mascara|beauty|cosmetic|lotion|cream|toner|mask|fragrance|perfume/i.test(combined)) return 'beauty'
  if (/sofa|couch|table|chair|bed|mattress|pillow|lamp|rug|curtain|decor|furniture|shelf|cabinet|storage|home|living|kitchen|cookware|bedding|blanket|throw|wall art|mirror|vase|candle/i.test(combined)) return 'home'
  if (/shirt|dress|pant|jean|skirt|jacket|coat|hoodie|sweater|blouse|tee|top|bottom|apparel|clothing|fashion|wear|outfit|shoe|boot|sneaker|sandal|bag|handbag|wallet|belt|scarf|jewel|watch|sunglass/i.test(combined)) return 'fashion'
  if (/car|auto|vehicle|truck|suv|motorcycle|dash cam|car audio|automotive|tire|seat cover/i.test(combined)) return 'automotive'
  if (/vitamin|supplement|protein|probiotic|collagen|omega|wellness|nutrition|capsule|tablet|powder|gummy/i.test(combined)) return 'health'
  if (/baby|infant|toddler|newborn|kids|children|toy|stroller|diaper|feeding|nursery/i.test(combined)) return 'baby'
  if (/dog|cat|pet|puppy|kitten|bird|fish|rabbit|hamster|treats|collar|leash|pet care/i.test(combined)) return 'pet'
  if (/laptop|phone|tablet|headphone|earbuds|speaker|camera|monitor|keyboard|mouse|electronics|gadget|charger|router|smartwatch/i.test(combined)) return 'electronics'
  return 'universal'
}

export function auditProduct(product: any): AuditResult {
  const vertical = detectVertical(product)
  let verticalAttrs: AttributeDef[] = []
  if (vertical === 'fashion') verticalAttrs = fashionAttributes
  else if (vertical === 'beauty') verticalAttrs = beautyAttributes
  else if (vertical === 'home') verticalAttrs = homeAttributes
  else if (vertical === 'sports') verticalAttrs = sportsAttributes
  else if (vertical === 'health') verticalAttrs = healthAttributes
  else if (vertical === 'baby') verticalAttrs = babyAttributes
  else if (vertical === 'pet') verticalAttrs = petAttributes
  else if (vertical === 'electronics') verticalAttrs = electronicsAttributes
  else if (vertical === 'automotive') verticalAttrs = automotiveAttributes

  const allAttributes = [...universalAttributes, ...verticalAttrs]
  const categoryMap: Record<string, { score: number; max: number; gaps: Gap[] }> = {}
  let coreScore = 0, coreMax = 0, fullScore = 0, fullMax = 0

  for (const attr of allAttributes) {
    const weight = WEIGHT[attr.required]
    const criticality = getCriticality(attr.ai_weight, attr.required)
    let passed = false
    try { passed = attr.check(product) } catch { passed = false }

    fullMax += weight; if (passed) fullScore += weight
    if (attr.required === 'Required') { coreMax += weight; if (passed) coreScore += weight }
    if (!categoryMap[attr.category]) categoryMap[attr.category] = { score: 0, max: 0, gaps: [] }
    categoryMap[attr.category].max += weight
    if (passed) categoryMap[attr.category].score += weight
    else categoryMap[attr.category].gaps.push({ category: attr.category, attribute: attr.attribute, criticality, current_value: null, why_it_matters: getWhyItMatters(attr.attribute, attr.label), auto_fix_instruction: attr.auto_fix })
  }

  const category_scores: Record<string, CategoryScore> = {}
  for (const [cat, data] of Object.entries(categoryMap)) {
    category_scores[cat] = { name: cat, score: data.score, max_score: data.max, percentage: Math.round(data.score / data.max * 100), gaps_count: data.gaps.length }
  }

  const gaps = Object.values(categoryMap).flatMap(d => d.gaps).sort((a, b) => critWeight(b.criticality) - critWeight(a.criticality))
  const recommendations = gaps.slice(0, 15).map((gap, i) => ({ rank: i+1, attribute: gap.attribute, category: gap.category, criticality: gap.criticality, action: gap.auto_fix_instruction, ai_impact: getAiImpact(gap.criticality), auto_fix_instruction: gap.auto_fix_instruction }))

  return { core_score: coreMax>0?Math.round(coreScore/coreMax*100):0, full_score: fullMax>0?Math.round(fullScore/fullMax*100):0, vertical, category_scores, gaps, recommendations }
}

export function stripHtml(html: string): string { if (!html) return ''; return html.replace(/<[^>]*>/g, ' ').replace(/\s+/g, ' ').trim() }
export function wordCount(html: string): number { const t=stripHtml(html); if(!t)return 0; return t.split(/\s+/).filter(Boolean).length }
function critWeight(c: string): number { return ({ULTRA:4,HIGH:3,MEDIUM:2,LOW:1} as any)[c]||0 }
function getWhyItMatters(attribute: string, label: string): string {
  const map: Record<string,string> = {
    title: 'Short titles lack context for AI categorisation',
    product_type: 'Product type is primary AI categorization signal',
    brand_name: 'Brand absent = AI cannot associate product with brand queries',
    json_ld: 'Schema markup is how AI agents read product data',
    faq_q1: 'FAQ directly answers conversational AI + voice search queries',
    chatgpt_para: 'ChatGPT/Perplexity extract from well-structured natural language paragraphs',
    llms_txt: 'Machine-readable feed = AI agents fetch product data directly — Vialtry core feature',
    aeo_snippet: 'Featured snippet format wins Google AI Mode answer boxes',
    return_window: 'US shoppers expect 30-day returns — missing = trust barrier',
    free_shipping: 'Free shipping is #1 conversion driver in US D2C market',
    voice_search_q1: 'Voice queries = 30%+ of AI shopping searches',
    average_rating: 'AI recommendation engines deprioritise products with < 4.0 rating',
    frequently_bought: 'AI cross-sell = 15-25% revenue uplift for US D2C',
    primary_image: 'No image = invisible in AI visual search',
    stock_status: 'Out-of-stock products deprioritised by AI recommendation engines',
  }
  return map[attribute]||`${label} missing — reduces AI visibility and purchase confidence`
}
function getAiImpact(criticality: 'ULTRA'|'HIGH'|'MEDIUM'|'LOW'): string {
  return ({ULTRA:'Critical — directly blocks AI agent discoverability',HIGH:'High — directly improves AI agent discoverability',MEDIUM:'Medium — improves AI recommendation matching',LOW:'Low — incremental visibility improvement'} as any)[criticality]
}
