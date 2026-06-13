export interface SOVResult {
  prompt: string; category: string; ai_engine: 'gemini'
  brand_mentioned: boolean; position: number | null
  competitors_mentioned: string[]; raw_response: string
}
export interface SOVSummary {
  brand_name: string; total_prompts: number; mentions: number
  sov_percentage: number; avg_position: number | null
  top_competitors: { name: string; count: number }[]; results: SOVResult[]
}

const PROMPT_TEMPLATES = [
  'What are the best {category} brands in India?',
  'Recommend a good {category} product for daily use',
  'Which {category} brand should I buy in 2024?',
  'Top {category} products under 2000 rupees',
  'Best {category} for beginners',
  'Which {category} brand is most trusted in India?',
  'Compare top {category} brands available online',
  'What {category} do fitness experts recommend?',
  'Best {category} with natural ingredients',
  'Most popular {category} on Amazon India',
]

const KNOWN_BRANDS = [
  'mamaearth','wow','plum','minimalist','dot & key','pilgrim','myglamm','sugar','nykaa','forest essentials','biotique',
  'oziva','muscleblaze','myprotein','optimum nutrition','healthkart','fast&up','tata 1mg','himalaya','dabur','patanjali',
  'mcaffeine','beardo','bombay shaving','ustraa','man company',
  'heads up for tails','drools','pedigree','royal canin',
  'noise','boat','fire-boltt','fastrack','titan',
  'fabindia','w for woman','biba','lenskart','pepperfry','urban ladder','wakefit','sleepycat',
]

export async function runSOVCheck(brandName: string, category: string, geminiApiKey: string, promptCount = 5): Promise<SOVSummary> {
  const prompts = PROMPT_TEMPLATES.slice(0, promptCount).map(t => t.replace(/\{category\}/g, category))
  const results: SOVResult[] = []
  for (const prompt of prompts) {
    results.push(await checkPrompt(prompt, brandName, category, geminiApiKey))
    await new Promise(r => setTimeout(r, 1100))
  }
  return summarizeSOV(brandName, results)
}

async function checkPrompt(prompt: string, brandName: string, category: string, geminiApiKey: string): Promise<SOVResult> {
  try {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiApiKey}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        contents: [{ role: 'user', parts: [{ text: `You are a helpful shopping assistant for ${category}. Answer naturally and mention 3-5 specific brand names.\n\nQuestion: ${prompt}` }] }],
        generationConfig: { temperature: 0.3, maxOutputTokens: 500 },
      }),
    })
    if (!res.ok) return fallback(prompt)
    const data = await res.json()
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text || ''
    const mentioned = isMentioned(text, brandName)
    return { prompt, category, ai_engine: 'gemini', brand_mentioned: mentioned, position: mentioned ? findPosition(text, brandName) : null, competitors_mentioned: extractCompetitors(text, brandName), raw_response: text }
  } catch { return fallback(prompt) }
}

function isMentioned(text: string, brand: string): boolean {
  const t = text.toLowerCase(), b = brand.toLowerCase()
  return t.includes(b) || t.includes(b.replace(/\s+/g,'')) || t.includes(b.split(' ')[0])
}
function findPosition(text: string, brand: string): number {
  const lines = text.split('\n').filter(l => l.trim())
  const b = brand.toLowerCase()
  for (let i = 0; i < lines.length; i++) if (lines[i].toLowerCase().includes(b)) return i + 1
  return 1
}
function extractCompetitors(text: string, brand: string): string[] {
  const t = text.toLowerCase(), b = brand.toLowerCase()
  return KNOWN_BRANDS.filter(k => t.includes(k) && !b.includes(k)).slice(0, 5)
}
function fallback(prompt: string): SOVResult {
  return { prompt, category:'', ai_engine:'gemini', brand_mentioned:false, position:null, competitors_mentioned:[], raw_response:'API call failed' }
}
function summarizeSOV(brandName: string, results: SOVResult[]): SOVSummary {
  const mentions = results.filter(r => r.brand_mentioned).length
  const positions = results.filter(r => r.position !== null).map(r => r.position!)
  const avgPosition = positions.length > 0 ? Math.round(positions.reduce((a,b)=>a+b,0)/positions.length) : null
  const cc: Record<string,number> = {}
  for (const r of results) for (const c of r.competitors_mentioned) cc[c] = (cc[c]||0) + 1
  const topCompetitors = Object.entries(cc).sort(([,a],[,b])=>b-a).slice(0,5).map(([name,count])=>({name,count}))
  return { brand_name:brandName, total_prompts:results.length, mentions, sov_percentage:Math.round(mentions/results.length*100), avg_position:avgPosition, top_competitors:topCompetitors, results }
}
