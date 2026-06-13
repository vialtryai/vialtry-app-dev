import { NextResponse } from 'next/server'

export async function GET() {
  const content = `# Vialtry - AI Commerce Readiness Platform
> Vialtry helps Shopify brands optimize their product listings for AI shopping assistants like ChatGPT, Google AI Mode, Amazon Rufus, Perplexity, Meta AI, and Bing Copilot.

## What Vialtry Does
- Audits product detail pages (PDPs) for AI visibility gaps
- Scores products across 3000+ attributes and 9 verticals
- Generates fix recommendations with auto-fix instructions
- Tracks Share of Voice (SOV) across AI platforms
- Supports verticals: Fashion, Beauty, Home, Sports, Health, Baby, Pet, Electronics, Automotive

## Key URLs
- App: https://vialtry-app.vercel.app
- Grader: https://vialtryaudit.com
- Homepage: https://vialtry.com
- Docs: https://vialtry.com/docs
- Privacy: https://vialtry.com/privacy
- Terms: https://vialtry.com/terms

## Supported AI Platforms
ChatGPT (ACP), Google AI Mode (UCP), Amazon Rufus, Perplexity, Meta AI, Bing Copilot

## Pricing
- Free: 10 product audits/month
- Growth: $19/month (Shopify Billing)
- Pro: $79/month

## Contact
support@vialtry.com
`

  return new NextResponse(content, {
    headers: {
      'Content-Type': 'text/plain; charset=utf-8',
      'Cache-Control': 'public, max-age=86400',
    },
  })
}
