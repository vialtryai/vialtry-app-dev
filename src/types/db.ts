export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export interface Database {
  public: {
    Tables: {
      brands: {
        Row: {
          id: string
          created_at: string
          user_id: string
          name: string
          shopify_domain: string
          shopify_access_token: string | null
          plan: 'free' | 'growth' | 'professional' | 'enterprise'
          status: 'active' | 'inactive' | 'pending'
          last_audit_at: string | null
        }
        Insert: {
          id?: string
          created_at?: string
          user_id: string
          name: string
          shopify_domain: string
          shopify_access_token?: string | null
          plan?: 'free' | 'growth' | 'professional' | 'enterprise'
          status?: 'active' | 'inactive' | 'pending'
          last_audit_at?: string | null
        }
        Update: Partial<Database['public']['Tables']['brands']['Insert']>
      }
      products: {
        Row: {
          id: string
          created_at: string
          brand_id: string
          shopify_product_id: string
          title: string
          handle: string
          product_type: string | null
          vendor: string | null
          raw_data: Json
          last_synced_at: string
        }
        Insert: {
          id?: string
          created_at?: string
          brand_id: string
          shopify_product_id: string
          title: string
          handle: string
          product_type?: string | null
          vendor?: string | null
          raw_data: Json
          last_synced_at?: string
        }
        Update: Partial<Database['public']['Tables']['products']['Insert']>
      }
      audits: {
        Row: {
          id: string
          created_at: string
          brand_id: string
          product_id: string
          core_score: number
          full_score: number
          category_scores: Json
          gaps: Json
          recommendations: Json
          status: 'pending' | 'running' | 'complete' | 'failed'
        }
        Insert: {
          id?: string
          created_at?: string
          brand_id: string
          product_id: string
          core_score?: number
          full_score?: number
          category_scores?: Json
          gaps?: Json
          recommendations?: Json
          status?: 'pending' | 'running' | 'complete' | 'failed'
        }
        Update: Partial<Database['public']['Tables']['audits']['Insert']>
      }
      sov_results: {
        Row: {
          id: string
          created_at: string
          brand_id: string
          prompt: string
          ai_engine: 'chatgpt' | 'gemini' | 'perplexity'
          brand_mentioned: boolean
          position: number | null
          competitors_mentioned: Json
          raw_response: string | null
        }
        Insert: {
          id?: string
          created_at?: string
          brand_id: string
          prompt: string
          ai_engine: 'chatgpt' | 'gemini' | 'perplexity'
          brand_mentioned?: boolean
          position?: number | null
          competitors_mentioned?: Json
          raw_response?: string | null
        }
        Update: Partial<Database['public']['Tables']['sov_results']['Insert']>
      }
    }
  }
}
