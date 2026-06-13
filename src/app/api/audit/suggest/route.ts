import { NextResponse } from 'next/server'
export async function POST(request: Request) {
  const {attribute,product_title,action} = await request.json()
  const geminiKey = process.env.GEMINI_API_KEY
  if(!geminiKey) return NextResponse.json({error:'Gemini API key not configured'},{status:500})
  const prompts:Record<string,string> = {
    sku_exists:`For "${product_title}", write 3 specific SKU examples following format: [BRAND]-[CATEGORY]-[COLOR]-[SIZE]. Example: VT-HOODIE-BLU-M. Make them unique and descriptive for AI agent discoverability.`,
    has_faq:`Write a 5-question FAQ section for "${product_title}". Format as Q: / A: pairs. Make answers helpful for AI shopping queries.`,
    desc_has_ingredients:`Write a concise "Ingredients & Materials" section for "${product_title}". 3-5 sentences, factual and specific.`,
    desc_has_benefits:`Write a "Key Benefits" section for "${product_title}" with 4-5 bullet points. Focus on outcomes AI agents match to queries.`,
    desc_has_usage:`Write a "How to Use" section for "${product_title}" with 4-6 clear steps.`,
    desc_has_who_for:`Write a 2-3 sentence "Who Is This For?" section for "${product_title}". Be specific about the target customer.`,
    has_specifications:`Write a specifications list for "${product_title}". Key: value pairs for dimensions, weight, materials, sizes.`,
    has_certifications:`Write 2-3 sentences about certifications for "${product_title}". Include FSSAI, ISO, lab-tested, GMP as relevant.`,
    title_has_material:`Suggest 3 improved titles for "${product_title}" that include main material/ingredient. Under 70 chars each.`,
    images_alt_text:`Write 3 descriptive alt text examples for "${product_title}" product images. 1 sentence each, include product name.`,
    tags_exist:`Suggest 10 Shopify product tags for "${product_title}". Match how customers search on AI shopping agents. Comma-separated.`,
  }
  const prompt = prompts[attribute] || `${action} for "${product_title}". Write ready-to-use copy that improves AI visibility. Concise and specific.`
  try {
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${geminiKey}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({contents:[{role:'user',parts:[{text:prompt}]}],generationConfig:{temperature:0.4,maxOutputTokens:800},thinkingConfig:{thinkingBudget:0},thinkingConfig:{thinkingBudget:0}})})
    if(!res.ok) return NextResponse.json({error:'Gemini API error'},{status:500})
    const data = await res.json()
    return NextResponse.json({suggestion:data.candidates?.[0]?.content?.parts?.[0]?.text||'Could not generate'})
  } catch { return NextResponse.json({error:'Failed to generate'},{status:500}) }
}
