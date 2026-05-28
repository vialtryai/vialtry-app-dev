// Vialtry — Fashion & Apparel Vertical Attributes (North America)
// Category-specific attributes on top of universal 44

import { AttributeDef, stripHtml } from '../pdp'

export const fashionAttributes: AttributeDef[] = [
  // PHYSICAL ATTRIBUTES
  { category:'Fashion', attribute:'fabric_material', label:'Fabric / Material Composition', ai_weight:10, required:'Required', auto_fix:'Add fabric composition: e.g. "100% Organic Cotton" or "60% Cotton, 40% Polyester". Required for US textile labeling.', check:(p)=>/cotton|polyester|nylon|wool|silk|linen|rayon|spandex|lycra|fleece|denim|leather|suede|velvet|modal|bamboo|hemp/i.test(stripHtml(p.body_html)) },
  { category:'Fashion', attribute:'fabric_type', label:'Fabric Type', ai_weight:10, required:'Required', auto_fix:'Add fabric type tag: jersey, woven, knit, fleece, denim, twill, satin etc.', check:(p)=>/jersey|woven|knit|fleece|denim|twill|satin|chiffon|canvas|mesh|terry|velour/i.test(p.tags?.toLowerCase()||p.body_html?.toLowerCase()||'') },
  { category:'Fashion', attribute:'colour_name', label:'Colour Name', ai_weight:10, required:'Required', auto_fix:'Add specific colour name to title and tags: e.g. "Midnight Navy" not just "Blue".', check:(p)=>p.variants?.some((v:any)=>!!v.option1?.trim())||/color|colour/i.test(p.tags||'') },
  { category:'Fashion', attribute:'print_pattern', label:'Print / Pattern', ai_weight:9, required:'Required', auto_fix:'Add print/pattern tag: solid, stripe, floral, plaid, graphic, abstract, animal print etc.', check:(p)=>/solid|stripe|floral|plaid|check|graphic|abstract|print|pattern|geometric|polka/i.test(p.tags?.toLowerCase()||stripHtml(p.body_html).toLowerCase()) },

  // SIZING & FIT
  { category:'Fashion', attribute:'size_guide', label:'Size Guide URL', ai_weight:10, required:'Required', auto_fix:'Add size guide link. US sizing must include: XS/S/M/L/XL + inch measurements for chest/waist/hip.', check:(p)=>/size guide|size chart|measurements|sizing/i.test(stripHtml(p.body_html)) },
  { category:'Fashion', attribute:'available_sizes', label:'Available Sizes', ai_weight:10, required:'Required', auto_fix:'Add all available sizes as variants. Include US sizing (XS-XXL or numeric 0-20).', check:(p)=>p.variants?.length>1||/xs|small|medium|large|xl|xxl|\bsize\b/i.test(p.tags||'') },
  { category:'Fashion', attribute:'size_system', label:'Size System (US)', ai_weight:10, required:'Required', auto_fix:'Specify US size system. Add "US sizing" to description and size guide.', check:(p)=>/us size|us sizing|us standard|american size/i.test(stripHtml(p.body_html))||p.variants?.length>1 },
  { category:'Fashion', attribute:'fit_type', label:'Fit Type', ai_weight:10, required:'Required', auto_fix:'Add fit type: slim fit, regular fit, relaxed fit, oversized, fitted, loose. Critical for AI size queries.', check:(p)=>/slim fit|regular fit|relaxed|oversized|fitted|loose|tailored|straight|skinny|wide leg/i.test(stripHtml(p.body_html)) },
  { category:'Fashion', attribute:'model_size', label:'Model Size Worn', ai_weight:10, required:'Required', auto_fix:'Add "Model is 5\'10" and wearing size M" to description. Helps AI answer fit queries.', check:(p)=>/model is|model wears|model wearing|worn by model|shown in size/i.test(stripHtml(p.body_html)) },
  { category:'Fashion', attribute:'silhouette', label:'Silhouette', ai_weight:9, required:'Recommended', auto_fix:'Add silhouette description: A-line, straight, bodycon, wrap, boxy, cropped, maxi etc.', check:(p)=>/a-line|straight|bodycon|wrap|boxy|cropped|maxi|mini|midi|empire|shift/i.test(stripHtml(p.body_html)) },
  { category:'Fashion', attribute:'neckline', label:'Neckline (Tops)', ai_weight:9, required:'Recommended', auto_fix:'Add neckline type: crew neck, V-neck, scoop, turtleneck, off-shoulder, square neck etc.', check:(p)=>/crew neck|v.neck|scoop|turtleneck|off.shoulder|square neck|mock neck|cowl|halter|strapless/i.test(stripHtml(p.body_html)) },
  { category:'Fashion', attribute:'sleeve_type', label:'Sleeve Type', ai_weight:9, required:'Recommended', auto_fix:'Add sleeve type: short sleeve, long sleeve, 3/4 sleeve, sleeveless, raglan, flutter etc.', check:(p)=>/short sleeve|long sleeve|sleeveless|3\/4|raglan|flutter|puff sleeve|cap sleeve|bell sleeve/i.test(stripHtml(p.body_html)) },

  // CARE & MAINTENANCE
  { category:'Fashion', attribute:'wash_care', label:'Wash Care Instructions', ai_weight:10, required:'Required', auto_fix:'Add wash care: Machine wash cold, tumble dry low, do not bleach. Required for US textile labeling law.', check:(p)=>/machine wash|hand wash|dry clean|tumble dry|cold wash|warm wash|wash care|care instruction/i.test(stripHtml(p.body_html)) },
  { category:'Fashion', attribute:'wash_temperature', label:'Wash Temperature', ai_weight:10, required:'Required', auto_fix:'Specify wash temperature: cold (30°C/86°F), warm (40°C/104°F), or hand wash only.', check:(p)=>/cold|warm|hot|\d+°|\d+f|\d+c/i.test(stripHtml(p.body_html)) },

  // PERFORMANCE
  { category:'Fashion', attribute:'moisture_wicking', label:'Moisture Wicking (Activewear)', ai_weight:9, required:'Recommended', auto_fix:'Add performance features for activewear: moisture-wicking, quick-dry, anti-odor, UPF rating.', check:(p)=>{ const isActive=/activewear|athletic|gym|sport|running|yoga|workout/i.test(p.product_type||p.tags||''); if(!isActive)return true; return /moisture.wick|quick.dry|anti.odor|sweat|breathable/i.test(stripHtml(p.body_html)) } },

  // OCCASION & TREND
  { category:'Fashion', attribute:'occasion', label:'Occasion', ai_weight:10, required:'Required', auto_fix:'Add occasion tags: casual, formal, work, party, wedding, beach, gym, outdoor etc.', check:(p)=>/casual|formal|work|office|party|wedding|beach|gym|outdoor|date|brunch|vacation/i.test(p.tags?.toLowerCase()||stripHtml(p.body_html).toLowerCase()) },
  { category:'Fashion', attribute:'season', label:'Season / Suitable Weather', ai_weight:9, required:'Required', auto_fix:'Add season tags: spring, summer, fall, winter, all-season. Helps AI seasonal queries.', check:(p)=>/spring|summer|fall|autumn|winter|all.season|year.round/i.test(p.tags?.toLowerCase()||stripHtml(p.body_html).toLowerCase()) },
  { category:'Fashion', attribute:'aesthetic', label:'Aesthetic / Style Vibe', ai_weight:10, required:'Required', auto_fix:'Add style aesthetic tags: minimalist, bohemian, streetwear, preppy, cottagecore, Y2K, classic etc.', check:(p)=>/minimalist|bohemian|boho|streetwear|preppy|classic|vintage|modern|casual|chic|edgy/i.test(p.tags?.toLowerCase()||stripHtml(p.body_html).toLowerCase()) },

  // COMPLIANCE — US Specific
  { category:'Fashion', attribute:'fiber_content', label:'Fiber Content Label (FTC Required)', ai_weight:9, required:'Required', auto_fix:'Add exact fiber % breakdown per FTC Textile Labeling Act. e.g. "55% Cotton, 45% Polyester".', check:(p)=>/\d+%\s*(cotton|polyester|nylon|wool|silk|linen|rayon|spandex)/i.test(stripHtml(p.body_html)) },
  { category:'Fashion', attribute:'azo_free', label:'Azo Dye Free / OEKO-TEX', ai_weight:9, required:'Recommended', auto_fix:'Add OEKO-TEX or azo-free certification if available. Growing importance in US market.', check:(p)=>/oeko.tex|azo.free|gots|bluesign|certified|sustainable/i.test(stripHtml(p.body_html))||true },

  // AI COMMERCE
  { category:'Fashion', attribute:'style_match', label:'Celebrity / Influencer Style Match', ai_weight:7, required:'Optional', auto_fix:'Add style match tags for AI fashion discovery: e.g. "as seen on TikTok", "street style inspiration".', check:(p)=>/style|inspired|trend|tiktok|instagram|influencer|celebrity|as seen/i.test(p.tags?.toLowerCase()||'')||true },
]
