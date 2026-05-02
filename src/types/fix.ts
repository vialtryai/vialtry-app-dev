export type FixStatus = 'generated' | 'pushed' | 'reverted' | 'failed'

export interface FixHistoryRow {
  id: string
  brand_id: string
  product_id: string
  product_title?: string
  attribute: string
  old_value?: string
  new_value: string
  shopify_field: string
  pushed_at?: string
  reverted_at?: string
  status: FixStatus
  error_message?: string
  created_at: string
}

// Payload from PDP audit — what needs fixing
export interface FixTarget {
  product_id: string
  product_title: string
  attribute: string          // human label: "SEO Description"
  shopify_field: string      // Shopify API field: "body_html" | "title" | "tags" etc
  current_value?: string
  fix_hint?: string          // context for Gemini: why this is failing
}

export interface GenerateFixResponse {
  fix_id: string             // inserted fix_history row id (status=generated)
  attribute: string
  new_value: string
  explanation: string
}

export interface PushFixResponse {
  fix_id: string
  shopify_product_id: string
  attribute: string
  status: 'pushed' | 'failed'
  error?: string
}
