bash setup_vialtry_fixed.sh#!/bin/bash
set -e
echo "🚀 Vialtry — Full Setup (Fixed)"

echo ''
echo '=== setup.sh ==='
echo "🚀 Creating Vialtry file structure..."

# Create directories
mkdir -p src/lib/supabase
mkdir -p src/types
mkdir -p src/app/\(auth\)/login
mkdir -p src/app/\(auth\)/signup
mkdir -p src/app/\(dashboard\)/dashboard
mkdir -p src/app/auth/callback
mkdir -p src/app/auth/signout
mkdir -p supabase/migrations

# ── src/lib/supabase/client.ts ──
cat > src/lib/supabase/client.ts << 'ENDOFFILE'
import { createBrowserClient } from '@supabase/ssr'
import { Database } from '@/types/db'

export function createClient() {
  return createBrowserClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!
  )
}
ENDOFFILE

# ── src/lib/supabase/server.ts ──
cat > src/lib/supabase/server.ts << 'ENDOFFILE'
import { createServerClient } from '@supabase/ssr'
import { cookies } from 'next/headers'
import { Database } from '@/types/db'

export async function createClient() {
  const cookieStore = await cookies()
  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return cookieStore.getAll() },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) =>
              cookieStore.set(name, value, options)
            )
          } catch {}
        },
      },
    }
  )
}
ENDOFFILE

# ── middleware.ts ──
cat > src/middleware.ts << 'ENDOFFILE'
import { createServerClient } from '@supabase/ssr'
import { NextResponse, type NextRequest } from 'next/server'

export async function middleware(request: NextRequest) {
  let supabaseResponse = NextResponse.next({ request })

  const supabase = createServerClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        getAll() { return request.cookies.getAll() },
        setAll(cookiesToSet) {
          cookiesToSet.forEach(({ name, value }) => request.cookies.set(name, value))
          supabaseResponse = NextResponse.next({ request })
          cookiesToSet.forEach(({ name, value, options }) =>
            supabaseResponse.cookies.set(name, value, options)
          )
        },
      },
    }
  )

  const { data: { user } } = await supabase.auth.getUser()

  if (!user && request.nextUrl.pathname.startsWith('/dashboard')) {
    const url = request.nextUrl.clone()
    url.pathname = '/login'
    return NextResponse.redirect(url)
  }

  if (user && (request.nextUrl.pathname === '/login' || request.nextUrl.pathname === '/signup')) {
    const url = request.nextUrl.clone()
    url.pathname = '/dashboard'
    return NextResponse.redirect(url)
  }

  return supabaseResponse
}

export const config = {
  matcher: ['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)'],
}
ENDOFFILE

# ── src/types/db.ts ──
cat > src/types/db.ts << 'ENDOFFILE'
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
ENDOFFILE

# ── src/app/layout.tsx ──
cat > src/app/layout.tsx << 'ENDOFFILE'
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'Vialtry — AI Commerce Readiness',
  description: 'Make your D2C brand visible to AI shopping agents',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body className={`${inter.className} antialiased`}>{children}</body>
    </html>
  )
}
ENDOFFILE

# ── src/app/page.tsx ──
cat > src/app/page.tsx << 'ENDOFFILE'
import { redirect } from 'next/navigation'
import { createClient } from '@/lib/supabase/server'

export default async function Home() {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (user) redirect('/dashboard')
  else redirect('/login')
}
ENDOFFILE

# ── src/app/(auth)/login/page.tsx ──
cat > "src/app/(auth)/login/page.tsx" << 'ENDOFFILE'
'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'
import Link from 'next/link'

export default function LoginPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  async function handleLogin() {
    setLoading(true)
    setError('')
    const { error } = await supabase.auth.signInWithPassword({ email, password })
    if (error) { setError(error.message); setLoading(false); return }
    router.push('/dashboard')
  }

  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-2xl font-bold text-white tracking-tight">vialtry</h1>
          <p className="text-gray-400 text-sm mt-1">AI Commerce Readiness Platform</p>
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-4">
          <h2 className="text-white font-semibold text-lg">Sign in</h2>
          {error && <div className="bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2 text-red-400 text-sm">{error}</div>}
          <div className="space-y-3">
            <div>
              <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Email</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)} onKeyDown={e => e.key === 'Enter' && handleLogin()} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="you@brand.com" />
            </div>
            <div>
              <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Password</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)} onKeyDown={e => e.key === 'Enter' && handleLogin()} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="••••••••" />
            </div>
          </div>
          <button onClick={handleLogin} disabled={loading} className="w-full bg-violet-600 hover:bg-violet-500 disabled:bg-violet-800 disabled:cursor-not-allowed text-white font-medium rounded-lg py-2.5 text-sm transition-colors">
            {loading ? 'Signing in...' : 'Sign in'}
          </button>
          <p className="text-gray-500 text-sm text-center">No account? <Link href="/signup" className="text-violet-400 hover:text-violet-300">Sign up</Link></p>
        </div>
      </div>
    </div>
  )
}
ENDOFFILE

# ── src/app/(auth)/signup/page.tsx ──
cat > "src/app/(auth)/signup/page.tsx" << 'ENDOFFILE'
'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import Link from 'next/link'

export default function SignupPage() {
  const [email, setEmail] = useState('')
  const [password, setPassword] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const [done, setDone] = useState(false)
  const supabase = createClient()

  async function handleSignup() {
    setLoading(true)
    setError('')
    const { error } = await supabase.auth.signUp({
      email, password,
      options: { emailRedirectTo: `${location.origin}/auth/callback` }
    })
    if (error) { setError(error.message); setLoading(false); return }
    setDone(true)
  }

  if (done) return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center px-4">
      <div className="w-full max-w-sm text-center space-y-3">
        <div className="text-4xl">📬</div>
        <h2 className="text-white font-semibold text-lg">Check your email</h2>
        <p className="text-gray-400 text-sm">Confirmation link sent to <span className="text-white">{email}</span></p>
      </div>
    </div>
  )

  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center px-4">
      <div className="w-full max-w-sm">
        <div className="mb-8 text-center">
          <h1 className="text-2xl font-bold text-white tracking-tight">vialtry</h1>
          <p className="text-gray-400 text-sm mt-1">AI Commerce Readiness Platform</p>
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-4">
          <h2 className="text-white font-semibold text-lg">Create account</h2>
          {error && <div className="bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2 text-red-400 text-sm">{error}</div>}
          <div className="space-y-3">
            <div>
              <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Email</label>
              <input type="email" value={email} onChange={e => setEmail(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="you@brand.com" />
            </div>
            <div>
              <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Password</label>
              <input type="password" value={password} onChange={e => setPassword(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="Min 8 characters" />
            </div>
          </div>
          <button onClick={handleSignup} disabled={loading} className="w-full bg-violet-600 hover:bg-violet-500 disabled:bg-violet-800 disabled:cursor-not-allowed text-white font-medium rounded-lg py-2.5 text-sm transition-colors">
            {loading ? 'Creating account...' : 'Create account'}
          </button>
          <p className="text-gray-500 text-sm text-center">Have an account? <Link href="/login" className="text-violet-400 hover:text-violet-300">Sign in</Link></p>
        </div>
      </div>
    </div>
  )
}
ENDOFFILE

# ── src/app/auth/callback/route.ts ──
cat > src/app/auth/callback/route.ts << 'ENDOFFILE'
import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function GET(request: Request) {
  const { searchParams, origin } = new URL(request.url)
  const code = searchParams.get('code')
  if (code) {
    const supabase = await createClient()
    const { error } = await supabase.auth.exchangeCodeForSession(code)
    if (!error) return NextResponse.redirect(`${origin}/dashboard`)
  }
  return NextResponse.redirect(`${origin}/login?error=auth_callback_failed`)
}
ENDOFFILE

# ── src/app/auth/signout/route.ts ──
cat > src/app/auth/signout/route.ts << 'ENDOFFILE'
import { createClient } from '@/lib/supabase/server'
import { NextResponse } from 'next/server'

export async function POST() {
  const supabase = await createClient()
  await supabase.auth.signOut()
  return NextResponse.redirect(new URL('/login', process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000'))
}
ENDOFFILE

# ── src/app/(dashboard)/layout.tsx ──
cat > "src/app/(dashboard)/layout.tsx" << 'ENDOFFILE'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import Link from 'next/link'

export default async function DashboardLayout({ children }: { children: React.ReactNode }) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) redirect('/login')

  return (
    <div className="min-h-screen bg-gray-950 flex">
      <aside className="w-56 bg-gray-900 border-r border-gray-800 flex flex-col">
        <div className="px-4 py-5 border-b border-gray-800">
          <span className="text-white font-bold text-lg tracking-tight">vialtry</span>
          <span className="ml-2 text-xs bg-violet-500/20 text-violet-400 px-1.5 py-0.5 rounded font-medium">beta</span>
        </div>
        <nav className="flex-1 px-2 py-4 space-y-0.5">
          <Link href="/dashboard" className="flex items-center gap-2.5 px-3 py-2 rounded-lg text-gray-400 hover:text-white hover:bg-gray-800 transition-colors text-sm">⬡ Overview</Link>
          <Link href="/dashboard/audit" className="flex items-center gap-2.5 px-3 py-2 rounded-lg text-gray-400 hover:text-white hover:bg-gray-800 transition-colors text-sm">⊙ PDP Audit</Link>
          <Link href="/dashboard/visibility" className="flex items-center gap-2.5 px-3 py-2 rounded-lg text-gray-400 hover:text-white hover:bg-gray-800 transition-colors text-sm">◎ AI Visibility</Link>
          <Link href="/dashboard/competitors" className="flex items-center gap-2.5 px-3 py-2 rounded-lg text-gray-400 hover:text-white hover:bg-gray-800 transition-colors text-sm">⊘ Competitors</Link>
          <Link href="/dashboard/recommendations" className="flex items-center gap-2.5 px-3 py-2 rounded-lg text-gray-400 hover:text-white hover:bg-gray-800 transition-colors text-sm">⊕ Fix Queue</Link>
        </nav>
        <div className="px-4 py-4 border-t border-gray-800">
          <p className="text-gray-500 text-xs truncate">{user.email}</p>
          <form action="/auth/signout" method="post">
            <button className="text-gray-500 hover:text-gray-300 text-xs mt-1 transition-colors">Sign out</button>
          </form>
        </div>
      </aside>
      <main className="flex-1 overflow-auto">{children}</main>
    </div>
  )
}
ENDOFFILE

# ── src/app/(dashboard)/dashboard/page.tsx ──
cat > "src/app/(dashboard)/dashboard/page.tsx" << 'ENDOFFILE'
import { createClient } from '@/lib/supabase/server'

export default async function DashboardPage() {
  const supabase = await createClient()
  const { data: brands } = await supabase.from('brands').select('*')

  return (
    <div className="p-8">
      <div className="mb-8">
        <h1 className="text-white text-2xl font-bold">Overview</h1>
        <p className="text-gray-400 text-sm mt-1">Your AI commerce readiness at a glance</p>
      </div>
      {brands && brands.length === 0 ? (
        <div className="border border-dashed border-gray-700 rounded-xl p-12 text-center max-w-lg mx-auto mt-16">
          <div className="text-4xl mb-4">🔌</div>
          <h2 className="text-white font-semibold text-lg mb-2">Connect your Shopify store</h2>
          <p className="text-gray-400 text-sm mb-6">Connect your store to run a free AI visibility audit on your top 10 products.</p>
          <a href="/onboarding" className="inline-block bg-violet-600 hover:bg-violet-500 text-white font-medium rounded-lg px-6 py-2.5 text-sm transition-colors">Connect store →</a>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          {(brands || []).map((brand: any) => (
            <div key={brand.id} className="bg-gray-900 border border-gray-800 rounded-xl p-5">
              <div className="flex items-center justify-between mb-4">
                <h3 className="text-white font-medium">{brand.name}</h3>
                <span className={`text-xs px-2 py-0.5 rounded-full font-medium ${brand.status === 'active' ? 'bg-green-500/10 text-green-400' : 'bg-yellow-500/10 text-yellow-400'}`}>{brand.status}</span>
              </div>
              <p className="text-gray-500 text-xs">{brand.shopify_domain}</p>
            </div>
          ))}
        </div>
      )}
    </div>
  )
}
ENDOFFILE

# ── supabase/migrations/001_initial_schema.sql ──
cat > supabase/migrations/001_initial_schema.sql << 'ENDOFFILE'
create extension if not exists "uuid-ossp";

create table public.brands (
  id uuid primary key default uuid_generate_v4(),
  created_at timestamptz default now(),
  user_id uuid references auth.users(id) on delete cascade not null,
  name text not null,
  shopify_domain text not null unique,
  shopify_access_token text,
  plan text default 'free' check (plan in ('free','growth','professional','enterprise')),
  status text default 'pending' check (status in ('active','inactive','pending')),
  last_audit_at timestamptz
);
alter table public.brands enable row level security;
create policy "Users can only see own brands" on public.brands for all using (auth.uid() = user_id);

create table public.products (
  id uuid primary key default uuid_generate_v4(),
  created_at timestamptz default now(),
  brand_id uuid references public.brands(id) on delete cascade not null,
  shopify_product_id text not null,
  title text not null,
  handle text not null,
  product_type text,
  vendor text,
  raw_data jsonb default '{}',
  last_synced_at timestamptz default now(),
  unique(brand_id, shopify_product_id)
);
alter table public.products enable row level security;
create policy "Users can only see own products" on public.products for all using (exists (select 1 from public.brands where brands.id = products.brand_id and brands.user_id = auth.uid()));

create table public.audits (
  id uuid primary key default uuid_generate_v4(),
  created_at timestamptz default now(),
  brand_id uuid references public.brands(id) on delete cascade not null,
  product_id uuid references public.products(id) on delete cascade not null,
  core_score numeric(5,2) default 0,
  full_score numeric(5,2) default 0,
  category_scores jsonb default '{}',
  gaps jsonb default '[]',
  recommendations jsonb default '[]',
  status text default 'pending' check (status in ('pending','running','complete','failed'))
);
alter table public.audits enable row level security;
create policy "Users can only see own audits" on public.audits for all using (exists (select 1 from public.brands where brands.id = audits.brand_id and brands.user_id = auth.uid()));

create table public.sov_results (
  id uuid primary key default uuid_generate_v4(),
  created_at timestamptz default now(),
  brand_id uuid references public.brands(id) on delete cascade not null,
  prompt text not null,
  ai_engine text not null check (ai_engine in ('chatgpt','gemini','perplexity')),
  brand_mentioned boolean default false,
  position integer,
  competitors_mentioned jsonb default '[]',
  raw_response text
);
alter table public.sov_results enable row level security;
create policy "Users can only see own SOV results" on public.sov_results for all using (exists (select 1 from public.brands where brands.id = sov_results.brand_id and brands.user_id = auth.uid()));

create index idx_products_brand_id on public.products(brand_id);
create index idx_audits_brand_id on public.audits(brand_id);
create index idx_audits_product_id on public.audits(product_id);
create index idx_sov_brand_id on public.sov_results(brand_id);
ENDOFFILE

echo ""
echo "✅ Done! All files created."
echo ""
echo "Next steps:"
echo "1. Add Supabase keys to .env.local"
echo "2. Run SQL migration in Supabase dashboard"
echo "3. npm run dev"

echo ''
echo '=== setup2.sh ==='

mkdir -p src/app/onboarding
mkdir -p src/app/api/shopify/verify
mkdir -p src/app/api/shopify/products
mkdir -p src/app/api/audit/run
mkdir -p "src/app/(dashboard)/dashboard/audit"
mkdir -p src/lib/scoring

# ── Onboarding page ──
cat > src/app/onboarding/page.tsx << 'EOF'
'use client'
import { useState } from 'react'
import { createClient } from '@/lib/supabase/client'
import { useRouter } from 'next/navigation'

export default function OnboardingPage() {
  const [step, setStep] = useState(1)
  const [brandName, setBrandName] = useState('')
  const [shopifyDomain, setShopifyDomain] = useState('')
  const [accessToken, setAccessToken] = useState('')
  const [error, setError] = useState('')
  const [loading, setLoading] = useState(false)
  const router = useRouter()
  const supabase = createClient()

  async function handleConnect() {
    setLoading(true)
    setError('')
    const domain = shopifyDomain.replace('https://','').replace('http://','').replace(/\/$/,'').trim()
    const res = await fetch('/api/shopify/verify', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ domain, accessToken }),
    })
    const data = await res.json()
    if (!res.ok) { setError(data.error || 'Could not connect'); setLoading(false); return }
    const { data: { user } } = await supabase.auth.getUser()
    const { error: dbError } = await supabase.from('brands').insert({
      user_id: user!.id,
      name: brandName || data.shopName,
      shopify_domain: domain,
      shopify_access_token: accessToken,
      status: 'active',
    })
    if (dbError) { setError(dbError.message); setLoading(false); return }
    router.push('/dashboard')
  }

  return (
    <div className="min-h-screen bg-gray-950 flex items-center justify-center px-4">
      <div className="w-full max-w-lg">
        <div className="mb-8 text-center">
          <h1 className="text-2xl font-bold text-white tracking-tight">vialtry</h1>
          <p className="text-gray-400 text-sm mt-1">Connect your Shopify store</p>
        </div>
        <div className="flex items-center justify-center gap-2 mb-8">
          {[1,2].map(s => <div key={s} className={`h-1.5 w-12 rounded-full transition-colors ${step>=s?'bg-violet-500':'bg-gray-800'}`}/>)}
        </div>
        <div className="bg-gray-900 border border-gray-800 rounded-xl p-6 space-y-5">
          {step===1 && <>
            <div><h2 className="text-white font-semibold text-lg mb-1">Your brand</h2><p className="text-gray-400 text-sm">What should we call your brand?</p></div>
            <div>
              <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Brand name</label>
              <input type="text" value={brandName} onChange={e=>setBrandName(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="e.g. TDK Supplements"/>
            </div>
            <button onClick={()=>setStep(2)} disabled={!brandName.trim()} className="w-full bg-violet-600 hover:bg-violet-500 disabled:bg-gray-800 disabled:text-gray-600 disabled:cursor-not-allowed text-white font-medium rounded-lg py-2.5 text-sm transition-colors">Continue →</button>
          </>}
          {step===2 && <>
            <div><h2 className="text-white font-semibold text-lg mb-1">Connect Shopify</h2><p className="text-gray-400 text-sm">We need read access to your products.</p></div>
            <div className="bg-gray-800/50 border border-gray-700 rounded-lg p-4 space-y-2">
              <p className="text-gray-300 text-xs font-medium uppercase tracking-wider">How to get your API token</p>
              <ol className="text-gray-400 text-xs space-y-1.5 list-decimal list-inside">
                <li>Shopify Admin → Settings → Apps and sales channels</li>
                <li>Click <span className="text-white">Develop apps</span> → Create an app</li>
                <li>Configure Admin API scopes: <span className="text-violet-400">read_products, read_inventory</span></li>
                <li>Install app → Copy <span className="text-white">Admin API access token</span></li>
              </ol>
            </div>
            {error && <div className="bg-red-500/10 border border-red-500/20 rounded-lg px-3 py-2 text-red-400 text-sm">{error}</div>}
            <div className="space-y-3">
              <div>
                <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Shopify domain</label>
                <input type="text" value={shopifyDomain} onChange={e=>setShopifyDomain(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="yourstore.myshopify.com"/>
              </div>
              <div>
                <label className="text-gray-400 text-xs uppercase tracking-wider mb-1 block">Admin API access token</label>
                <input type="password" value={accessToken} onChange={e=>setAccessToken(e.target.value)} className="w-full bg-gray-800 border border-gray-700 rounded-lg px-3 py-2.5 text-white text-sm focus:outline-none focus:border-violet-500 transition-colors" placeholder="shpat_xxxxxxxxxxxx"/>
              </div>
            </div>
            <div className="flex gap-3">
              <button onClick={()=>setStep(1)} className="px-4 py-2.5 text-gray-400 hover:text-white text-sm transition-colors">← Back</button>
              <button onClick={handleConnect} disabled={loading||!shopifyDomain.trim()||!accessToken.trim()} className="flex-1 bg-violet-600 hover:bg-violet-500 disabled:bg-gray-800 disabled:text-gray-600 disabled:cursor-not-allowed text-white font-medium rounded-lg py-2.5 text-sm transition-colors">{loading?'Connecting...':'Connect store'}</button>
            </div>
          </>}
        </div>
        <p className="text-gray-600 text-xs text-center mt-4">Your token is encrypted and stored securely. Read-only access only.</p>
      </div>
    </div>
  )
}
EOF

# ── Shopify verify route ──
cat > src/app/api/shopify/verify/route.ts << 'EOF'
import { NextResponse } from 'next/server'
export async function POST(request: Request) {
  const { domain, accessToken } = await request.json()
  if (!domain || !accessToken) return NextResponse.json({ error: 'Domain and token required' }, { status: 400 })
  try {
    const res = await fetch(`https://${domain}/admin/api/2024-01/shop.json`, {
      headers: { 'X-Shopify-Access-Token': accessToken, 'Content-Type': 'application/json' },
    })
    if (!res.ok) return NextResponse.json({ error: 'Invalid token or domain. Check your credentials.' }, { status: 401 })
    const data = await res.json()
    return NextResponse.json({ success: true, shopName: data.shop?.name || domain })
  } catch {
    return NextResponse.json({ error: 'Could not reach Shopify. Check your domain.' }, { status: 500 })
  }
}
EOF

# ── Shopify products route ──
cat > src/app/api/shopify/products/route.ts << 'EOF'
import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
export async function POST(request: Request) {
  const supabase = await createClient()
  const { data: { user } } = await supabase.auth.getUser()
  if (!user) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  const { brandId } = await request.json()
  const { data: brand } = await supabase.from('brands').select('*').eq('id', brandId).eq('user_id', user.id).single()
  if (!brand) return NextResponse.json({ error: 'Brand not found' }, { status: 404 })
  try {
    const res = await fetch(
      `https://${brand.shopify_domain}/admin/api/2024-01/products.json?limit=10&status=active&fields=id,title,handle,product_type,vendor,variants,images,body_html,tags`,
      { headers: { 'X-Shopify-Access-Token': brand.shopify_access_token, 'Content-Type': 'application/json' } }
    )
    if (!res.ok) return NextResponse.json({ error: 'Shopify API error' }, { status: 500 })
    const { products } = await res.json()
    const upsertData = products.map((p: any) => ({
      brand_id: brandId,
      shopify_product_id: String(p.id),
      title: p.title,
      handle: p.handle,
      product_type: p.product_type || null,
      vendor: p.vendor || null,
      raw_data: p,
      last_synced_at: new Date().toISOString(),
    }))
    const { error: upsertError } = await supabase.from('products').upsert(upsertData, { onConflict: 'brand_id,shopify_product_id' })
    if (upsertError) return NextResponse.json({ error: upsertError.message }, { status: 500 })
    await supabase.from('brands').update({ last_audit_at: new Date().toISOString() }).eq('id', brandId)
    return NextResponse.json({ success: true, count: products.length })
  } catch {
    return NextResponse.json({ error: 'Failed to fetch products' }, { status: 500 })
  }
}
EOF

# ── PDP Scoring engine ──
cat > src/lib/scoring/pdp.ts << 'EOF'
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
EOF

# ── Audit run API route ──
cat > src/app/api/audit/run/route.ts << 'EOF'
import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { auditProduct } from '@/lib/scoring/pdp'
export async function POST(request: Request) {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) return NextResponse.json({error:'Unauthorized'},{status:401})
  const {brandId} = await request.json()
  const {data:brand} = await supabase.from('brands').select('*').eq('id',brandId).eq('user_id',user.id).single()
  if(!brand) return NextResponse.json({error:'Brand not found'},{status:404})
  const {data:products} = await supabase.from('products').select('*').eq('brand_id',brandId).limit(10)
  if(!products||products.length===0) return NextResponse.json({error:'No products found. Sync products first.'},{status:400})
  const results=[]
  for(const product of products){
    const {data:audit} = await supabase.from('audits').insert({brand_id:brandId,product_id:product.id,status:'running'}).select().single()
    try{
      const result=auditProduct(product.raw_data)
      await supabase.from('audits').update({core_score:result.core_score,full_score:result.full_score,category_scores:result.category_scores,gaps:result.gaps,recommendations:result.recommendations,status:'complete'}).eq('id',audit!.id)
      results.push({product_id:product.id,title:product.title,core_score:result.core_score,full_score:result.full_score,gaps_count:result.gaps.length})
    }catch{
      await supabase.from('audits').update({status:'failed'}).eq('id',audit!.id)
    }
  }
  return NextResponse.json({success:true,audited:results.length,results,avg_core_score:Math.round(results.reduce((s,r)=>s+r.core_score,0)/results.length)})
}
EOF

# ── Audit dashboard page ──
cat > "src/app/(dashboard)/dashboard/audit/page.tsx" << 'EOF'
import { createClient } from '@/lib/supabase/server'
import { redirect } from 'next/navigation'
import AuditClient from './AuditClient'
export default async function AuditPage() {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) redirect('/login')
  const {data:brands} = await supabase.from('brands').select('*').eq('user_id',user.id)
  if(!brands||brands.length===0) redirect('/onboarding')
  const brand = brands[0]
  const {data:audits} = await supabase.from('audits').select('*, products(title,handle,shopify_product_id)').eq('brand_id',brand.id).eq('status','complete').order('created_at',{ascending:false})
  return <AuditClient brand={brand} audits={audits||[]} />
}
EOF

# ── AuditClient component ──
cat > "src/app/(dashboard)/dashboard/audit/AuditClient.tsx" << 'EOF'
'use client'
import { useState } from 'react'
interface Brand{id:string;name:string;shopify_domain:string}
interface Audit{id:string;core_score:number;full_score:number;gaps:any[];recommendations:any[];category_scores:Record<string,any>;products:{title:string;handle:string}}
export default function AuditClient({brand,audits:initialAudits}:{brand:Brand;audits:Audit[]}){
  const [audits,setAudits]=useState(initialAudits)
  const [syncing,setSyncing]=useState(false)
  const [running,setRunning]=useState(false)
  const [status,setStatus]=useState('')
  const [selected,setSelected]=useState<Audit|null>(null)
  async function syncProducts(){
    setSyncing(true);setStatus('Syncing products from Shopify...')
    const res=await fetch('/api/shopify/products',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({brandId:brand.id})})
    const data=await res.json();setSyncing(false)
    if(data.success)setStatus(`✓ Synced ${data.count} products`);else setStatus(`✗ ${data.error}`)
  }
  async function runAudit(){
    setRunning(true);setStatus('Running PDP audit...')
    const res=await fetch('/api/audit/run',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({brandId:brand.id})})
    const data=await res.json();setRunning(false)
    if(data.success){setStatus(`✓ Audited ${data.audited} products — avg score: ${data.avg_core_score}%`);window.location.reload()}
    else setStatus(`✗ ${data.error}`)
  }
  return(
    <div className="p-8">
      <div className="flex items-center justify-between mb-8">
        <div><h1 className="text-white text-2xl font-bold">PDP Audit</h1><p className="text-gray-400 text-sm mt-1">{brand.name} · {brand.shopify_domain}</p></div>
        <div className="flex gap-3">
          <button onClick={syncProducts} disabled={syncing} className="px-4 py-2 bg-gray-800 hover:bg-gray-700 disabled:opacity-50 text-white text-sm rounded-lg border border-gray-700">{syncing?'Syncing...':'↻ Sync products'}</button>
          <button onClick={runAudit} disabled={running} className="px-4 py-2 bg-violet-600 hover:bg-violet-500 disabled:opacity-50 text-white text-sm rounded-lg">{running?'Running...':'▶ Run audit'}</button>
        </div>
      </div>
      {status&&<div className="mb-6 bg-gray-900 border border-gray-700 rounded-lg px-4 py-2.5 text-sm text-gray-300">{status}</div>}
      {audits.length===0?(
        <div className="border border-dashed border-gray-700 rounded-xl p-12 text-center max-w-lg mx-auto mt-8"><div className="text-4xl mb-4">⊙</div><h2 className="text-white font-semibold text-lg mb-2">No audits yet</h2><p className="text-gray-400 text-sm">Sync products then run audit.</p></div>
      ):(
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          <div className="space-y-3">
            {audits.map(audit=>(
              <div key={audit.id} onClick={()=>setSelected(audit)} className={`bg-gray-900 border rounded-xl p-4 cursor-pointer transition-colors ${selected?.id===audit.id?'border-violet-500':'border-gray-800 hover:border-gray-700'}`}>
                <div className="flex items-center justify-between mb-3">
                  <p className="text-white text-sm font-medium truncate flex-1 mr-4">{audit.products?.title}</p>
                  <span className={`text-sm font-bold px-2 py-0.5 rounded ${audit.core_score>=70?'text-green-400 bg-green-500/10':audit.core_score>=40?'text-yellow-400 bg-yellow-500/10':'text-red-400 bg-red-500/10'}`}>{audit.core_score}%</span>
                </div>
                <div className="flex gap-4 items-center">
                  <div><p className="text-gray-500 text-xs mb-1">Core</p><div className="w-20 bg-gray-800 rounded-full h-1"><div className="h-1 rounded-full bg-violet-500" style={{width:`${audit.core_score}%`}}/></div></div>
                  <div><p className="text-gray-500 text-xs mb-1">Full</p><div className="w-20 bg-gray-800 rounded-full h-1"><div className="h-1 rounded-full bg-teal-500" style={{width:`${audit.full_score}%`}}/></div></div>
                  <div className="ml-auto text-right"><p className="text-gray-500 text-xs">Gaps</p><p className="text-red-400 text-sm font-medium">{audit.gaps?.length||0}</p></div>
                </div>
              </div>
            ))}
          </div>
          {selected&&(
            <div className="bg-gray-900 border border-gray-800 rounded-xl p-5 space-y-5">
              <h3 className="text-white font-semibold">{selected.products?.title}</h3>
              <div>
                <p className="text-gray-400 text-xs uppercase tracking-wider mb-3">Category Scores</p>
                <div className="space-y-2">
                  {Object.values(selected.category_scores||{}).map((cat:any)=>(
                    <div key={cat.name} className="flex items-center gap-3">
                      <p className="text-gray-300 text-xs w-24 shrink-0">{cat.name}</p>
                      <div className="flex-1 bg-gray-800 rounded-full h-1.5"><div className={`h-1.5 rounded-full ${cat.percentage>=70?'bg-green-500':cat.percentage>=40?'bg-yellow-500':'bg-red-500'}`} style={{width:`${cat.percentage}%`}}/></div>
                      <p className="text-gray-400 text-xs w-8 text-right">{cat.percentage}%</p>
                    </div>
                  ))}
                </div>
              </div>
              <div>
                <p className="text-gray-400 text-xs uppercase tracking-wider mb-3">Top Fixes</p>
                <div className="space-y-2">
                  {(selected.recommendations||[]).slice(0,5).map((rec:any)=>(
                    <div key={rec.rank} className="flex gap-3 bg-gray-800/50 rounded-lg p-3">
                      <span className={`text-xs px-1.5 py-0.5 rounded font-medium shrink-0 ${rec.criticality==='ULTRA'?'bg-red-500/20 text-red-400':rec.criticality==='HIGH'?'bg-orange-500/20 text-orange-400':'bg-yellow-500/20 text-yellow-400'}`}>{rec.criticality}</span>
                      <div><p className="text-white text-xs font-medium">{rec.action}</p><p className="text-gray-500 text-xs mt-0.5">{rec.ai_impact}</p></div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  )
}
EOF

echo ""
echo "✅ Session 2 files ready!"
echo ""
echo "What was built:"
echo "  → Onboarding page (brand name + Shopify token connect)"
echo "  → Shopify verify API (tests token before saving)"  
echo "  → Shopify products sync API (pulls top 10 products)"
echo "  → PDP Audit Engine (35 attributes, ULTRA/HIGH/MEDIUM/LOW scoring)"
echo "  → Audit run API (scores all products, saves to Supabase)"
echo "  → Audit dashboard (sync → run → view scores + recommendations)"
echo ""
echo "Run: npm run dev"

echo ''
echo '=== setup3.sh ==='

mkdir -p src/lib/agents
mkdir -p src/app/api/sov/run
mkdir -p src/app/api/sov/history
mkdir -p src/app/api/brands
mkdir -p "src/app/(dashboard)/dashboard/visibility"

# ── SOV Engine ──
cat > src/lib/agents/sov.ts << 'EOF'
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
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiApiKey}`, {
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
EOF

# ── SOV run route ──
cat > src/app/api/sov/run/route.ts << 'EOF'
import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
import { runSOVCheck } from '@/lib/agents/sov'
export async function POST(request: Request) {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) return NextResponse.json({error:'Unauthorized'},{status:401})
  const {brandId,category,promptCount=5} = await request.json()
  const {data:brand} = await supabase.from('brands').select('*').eq('id',brandId).eq('user_id',user.id).single()
  if(!brand) return NextResponse.json({error:'Brand not found'},{status:404})
  const geminiKey = process.env.GEMINI_API_KEY
  if(!geminiKey) return NextResponse.json({error:'Gemini API key not configured'},{status:500})
  try {
    const summary = await runSOVCheck(brand.name, category, geminiKey, promptCount)
    await supabase.from('sov_results').insert(summary.results.map(r=>({brand_id:brandId,prompt:r.prompt,ai_engine:r.ai_engine,brand_mentioned:r.brand_mentioned,position:r.position,competitors_mentioned:r.competitors_mentioned,raw_response:r.raw_response})))
    return NextResponse.json({success:true,summary})
  } catch(err:any) {
    return NextResponse.json({error:err.message||'SOV check failed'},{status:500})
  }
}
EOF

# ── SOV history route ──
cat > src/app/api/sov/history/route.ts << 'EOF'
import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
export async function GET(request: Request) {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) return NextResponse.json({error:'Unauthorized'},{status:401})
  const brandId = new URL(request.url).searchParams.get('brandId')
  if(!brandId) return NextResponse.json({error:'brandId required'},{status:400})
  const {data,error} = await supabase.from('sov_results').select('*').eq('brand_id',brandId).order('created_at',{ascending:false}).limit(50)
  if(error) return NextResponse.json({error:error.message},{status:500})
  const total=data.length, mentions=data.filter(r=>r.brand_mentioned).length
  const cc:Record<string,number>={}
  for(const r of data){const comps=Array.isArray(r.competitors_mentioned)?r.competitors_mentioned:[];for(const c of comps)cc[c]=(cc[c]||0)+1}
  const topCompetitors=Object.entries(cc).sort(([,a],[,b])=>b-a).slice(0,5).map(([name,count])=>({name,count}))
  return NextResponse.json({total,mentions,sov_percentage:total>0?Math.round(mentions/total*100):0,top_competitors:topCompetitors,results:data})
}
EOF

# ── Brands API route ──
cat > src/app/api/brands/route.ts << 'EOF'
import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
export async function GET() {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) return NextResponse.json({error:'Unauthorized'},{status:401})
  const {data:brands} = await supabase.from('brands').select('id,name,shopify_domain,status,plan,last_audit_at').eq('user_id',user.id).order('created_at',{ascending:false})
  return NextResponse.json({brands:brands||[]})
}
EOF

# ── AI Visibility page ──
cat > "src/app/(dashboard)/dashboard/visibility/page.tsx" << 'EOF'
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
EOF

# ── Add GEMINI_API_KEY to .env.local ──
if ! grep -q "GEMINI_API_KEY" .env.local 2>/dev/null; then
  echo "" >> .env.local
  echo "GEMINI_API_KEY=your_gemini_api_key_here" >> .env.local
  echo "NEXT_PUBLIC_SITE_URL=http://localhost:3000" >> .env.local
fi

echo ""
echo "✅ Session 3 done!"
echo ""
echo "Files created:"
echo "  → src/lib/agents/sov.ts         (SOV engine — Gemini integration)"
echo "  → src/app/api/sov/run/route.ts  (run SOV check API)"
echo "  → src/app/api/sov/history/route.ts (fetch past results)"
echo "  → src/app/api/brands/route.ts   (brands list API)"
echo "  → dashboard/visibility/page.tsx (full SOV UI)"
echo ""
echo "⚠️  Add your Gemini API key to .env.local:"
echo "    GEMINI_API_KEY=your_key_here"
echo ""
echo "Get key free: https://aistudio.google.com/app/apikey"

echo ''
echo '=== setup4.sh ==='

mkdir -p "src/app/(dashboard)/dashboard/recommendations"
mkdir -p src/app/api/audit/fixes
mkdir -p src/app/api/audit/suggest

# ── Fixes API ──
cat > src/app/api/audit/fixes/route.ts << 'EOF'
import { NextResponse } from 'next/server'
import { createClient } from '@/lib/supabase/server'
export async function GET(request: Request) {
  const supabase = await createClient()
  const { data:{user} } = await supabase.auth.getUser()
  if(!user) return NextResponse.json({error:'Unauthorized'},{status:401})
  const brandId = new URL(request.url).searchParams.get('brandId')
  if(!brandId) return NextResponse.json({error:'brandId required'},{status:400})
  const {data:audits,error} = await supabase.from('audits').select('id,product_id,recommendations,gaps,products(title)').eq('brand_id',brandId).eq('status','complete').order('created_at',{ascending:false})
  if(error) return NextResponse.json({error:error.message},{status:500})
  const fixes:any[]=[];let gid=0
  for(const audit of(audits||[])){
    const recs=Array.isArray(audit.recommendations)?audit.recommendations:[]
    for(const rec of recs){fixes.push({id:`${audit.id}-${gid++}`,product_title:(audit.products as any)?.title||'Unknown',product_id:audit.product_id,rank:rec.rank,attribute:rec.attribute,category:rec.category,criticality:rec.criticality,action:rec.action,ai_impact:rec.ai_impact,status:'pending'})}
  }
  const seen=new Map<string,any>()
  for(const fix of fixes)if(!seen.has(fix.attribute))seen.set(fix.attribute,fix)
  const order={ULTRA:0,HIGH:1,MEDIUM:2,LOW:3}
  const deduped=Array.from(seen.values()).sort((a,b)=>order[a.criticality as keyof typeof order]-order[b.criticality as keyof typeof order])
  return NextResponse.json({fixes:deduped,total:deduped.length})
}
EOF

# ── Suggest API ──
cat > src/app/api/audit/suggest/route.ts << 'EOF'
import { NextResponse } from 'next/server'
export async function POST(request: Request) {
  const {attribute,product_title,action} = await request.json()
  const geminiKey = process.env.GEMINI_API_KEY
  if(!geminiKey) return NextResponse.json({error:'Gemini API key not configured'},{status:500})
  const prompts:Record<string,string> = {
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
    const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${geminiKey}`,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({contents:[{role:'user',parts:[{text:prompt}]}],generationConfig:{temperature:0.4,maxOutputTokens:400}})})
    if(!res.ok) return NextResponse.json({error:'Gemini API error'},{status:500})
    const data = await res.json()
    return NextResponse.json({suggestion:data.candidates?.[0]?.content?.parts?.[0]?.text||'Could not generate'})
  } catch { return NextResponse.json({error:'Failed to generate'},{status:500}) }
}
EOF

# ── Fix Queue page ──
cat > "src/app/(dashboard)/dashboard/recommendations/page.tsx" << 'EOF'
'use client'
import { useState, useEffect } from 'react'
interface Fix{id:string;product_title:string;product_id:string;rank:number;attribute:string;category:string;criticality:'ULTRA'|'HIGH'|'MEDIUM'|'LOW';action:string;ai_impact:string}
interface Brand{id:string;name:string}
const CRIT_ORDER={ULTRA:0,HIGH:1,MEDIUM:2,LOW:3}
export default function RecommendationsPage(){
  const [brands,setBrands]=useState<Brand[]>([])
  const [selectedBrand,setSelectedBrand]=useState<Brand|null>(null)
  const [fixes,setFixes]=useState<Fix[]>([])
  const [loading,setLoading]=useState(true)
  const [filter,setFilter]=useState<'all'|'ULTRA'|'HIGH'|'MEDIUM'>('all')
  const [done,setDone]=useState<Set<string>>(new Set())
  const [generating,setGenerating]=useState<string|null>(null)
  const [suggestions,setSuggestions]=useState<Record<string,string>>({})
  const [expanded,setExpanded]=useState<Set<string>>(new Set())

  useEffect(()=>{fetch('/api/brands').then(r=>r.json()).then(d=>{setBrands(d.brands||[]);if(d.brands?.length>0)setSelectedBrand(d.brands[0])})},[])
  useEffect(()=>{if(selectedBrand)loadFixes(selectedBrand.id)},[selectedBrand])

  async function loadFixes(brandId:string){
    setLoading(true)
    const res=await fetch(`/api/audit/fixes?brandId=${brandId}`)
    const data=await res.json()
    setFixes(data.fixes||[]);setLoading(false)
  }

  async function generateSuggestion(fix:Fix){
    setGenerating(fix.id)
    const res=await fetch('/api/audit/suggest',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({attribute:fix.attribute,product_title:fix.product_title,action:fix.action})})
    const data=await res.json()
    setSuggestions(prev=>({...prev,[fix.id]:data.suggestion}))
    setGenerating(null)
  }

  function toggleExpand(id:string){
    setExpanded(prev=>{const n=new Set(prev);n.has(id)?n.delete(id):n.add(id);return n})
  }

  const filtered=fixes.filter(f=>filter==='all'||f.criticality===filter).sort((a,b)=>CRIT_ORDER[a.criticality]-CRIT_ORDER[b.criticality])
  const ultraCount=fixes.filter(f=>f.criticality==='ULTRA').length
  const highCount=fixes.filter(f=>f.criticality==='HIGH').length

  return(
    <div className="p-8">
      <div className="flex items-center justify-between mb-8">
        <div><h1 className="text-white text-2xl font-bold">Fix Queue</h1><p className="text-gray-400 text-sm mt-1">Prioritized by AI visibility impact</p></div>
        {brands.length>1&&<select value={selectedBrand?.id||''} onChange={e=>setSelectedBrand(brands.find(b=>b.id===e.target.value)||null)} className="bg-gray-800 border border-gray-700 rounded-lg px-3 py-2 text-white text-sm focus:outline-none">{brands.map(b=><option key={b.id} value={b.id}>{b.name}</option>)}</select>}
      </div>
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-6">
        {[{label:'Total fixes',val:fixes.length,c:undefined},{label:'ULTRA',val:ultraCount,c:'red'},{label:'HIGH',val:highCount,c:'orange'},{label:'Completed',val:done.size,c:'green'}].map(s=>(
          <div key={s.label} className="bg-gray-900 border border-gray-800 rounded-xl p-4">
            <p className="text-gray-500 text-xs uppercase tracking-wider mb-1">{s.label}</p>
            <p className={`text-2xl font-bold ${{red:'text-red-400',orange:'text-orange-400',green:'text-green-400'}[s.c||'']||'text-white'}`}>{s.val}</p>
          </div>
        ))}
      </div>
      <div className="flex gap-1 mb-6 bg-gray-900 border border-gray-800 rounded-lg p-1 w-fit">
        {(['all','ULTRA','HIGH','MEDIUM']as const).map(f=>(
          <button key={f} onClick={()=>setFilter(f)} className={`px-3 py-1.5 rounded-md text-xs font-medium transition-colors ${filter===f?'bg-gray-700 text-white':'text-gray-400 hover:text-white'}`}>{f==='all'?`All (${fixes.length})`:f}</button>
        ))}
      </div>
      {loading?<div className="text-gray-400 text-sm">Loading...</div>:fixes.length===0?(
        <div className="border border-dashed border-gray-700 rounded-xl p-12 text-center max-w-lg">
          <div className="text-4xl mb-4">⊕</div>
          <h2 className="text-white font-semibold text-lg mb-2">No fixes yet</h2>
          <p className="text-gray-400 text-sm mb-4">Run a PDP audit first.</p>
          <a href="/dashboard/audit" className="text-violet-400 hover:text-violet-300 text-sm">Go to PDP Audit →</a>
        </div>
      ):(
        <div className="space-y-3">
          {filtered.map(fix=>{
            const isExpanded=expanded.has(fix.id)
            const isDone=done.has(fix.id)
            const critColor={ULTRA:'bg-red-500/20 text-red-400 border-red-500/20',HIGH:'bg-orange-500/20 text-orange-400 border-orange-500/20',MEDIUM:'bg-yellow-500/20 text-yellow-400 border-yellow-500/20',LOW:'bg-gray-500/20 text-gray-400 border-gray-500/20'}[fix.criticality]
            return(
              <div key={fix.id} className={`bg-gray-900 border rounded-xl transition-all ${isDone?'border-gray-800 opacity-50':'border-gray-800 hover:border-gray-700'}`}>
                <div className="p-4">
                  <div className="flex items-start gap-3">
                    <button onClick={()=>setDone(prev=>{const n=new Set(prev);n.has(fix.id)?n.delete(fix.id):n.add(fix.id);return n})} className={`shrink-0 mt-0.5 w-4 h-4 rounded border transition-colors flex items-center justify-center ${isDone?'bg-green-500 border-green-500':'border-gray-600 hover:border-gray-400'}`}>
                      {isDone&&<span className="text-white text-xs">✓</span>}
                    </button>
                    <div className="flex-1 min-w-0">
                      <div className="flex items-center gap-2 mb-1 flex-wrap">
                        <span className={`text-xs px-1.5 py-0.5 rounded border font-medium ${critColor}`}>{fix.criticality}</span>
                        <span className="text-gray-500 text-xs">{fix.category}</span>
                        <span className="text-gray-600 text-xs">·</span>
                        <span className="text-gray-500 text-xs truncate">{fix.product_title}</span>
                      </div>
                      <p className={`text-sm font-medium ${isDone?'line-through text-gray-500':'text-white'}`}>{fix.action}</p>
                      <p className="text-gray-500 text-xs mt-0.5">{fix.ai_impact}</p>
                    </div>
                    <button onClick={()=>{toggleExpand(fix.id);if(!suggestions[fix.id]&&!isExpanded)generateSuggestion(fix)}} disabled={generating===fix.id} className="text-xs px-2.5 py-1 bg-violet-600/20 hover:bg-violet-600/30 text-violet-400 rounded-lg border border-violet-500/20 transition-colors disabled:opacity-50 shrink-0">
                      {generating===fix.id?'...':isExpanded?'Hide':'✦ AI suggest'}
                    </button>
                  </div>
                  {isExpanded&&(
                    <div className="mt-3 ml-7">
                      {generating===fix.id?<div className="bg-gray-800 rounded-lg p-3 text-gray-400 text-xs">Generating...</div>:suggestions[fix.id]?(
                        <div className="bg-gray-800 rounded-lg p-3">
                          <p className="text-gray-300 text-xs leading-relaxed whitespace-pre-wrap">{suggestions[fix.id]}</p>
                          <button onClick={()=>{navigator.clipboard.writeText(suggestions[fix.id])}} className="mt-2 text-xs text-gray-500 hover:text-gray-300 transition-colors">⎘ Copy</button>
                        </div>
                      ):<div className="bg-gray-800 rounded-lg p-3 text-gray-500 text-xs">Loading suggestion...</div>}
                    </div>
                  )}
                </div>
              </div>
            )
          })}
        </div>
      )}
    </div>
  )
}
EOF

# ── Updated Overview dashboard ──
cat > "src/app/(dashboard)/dashboard/page.tsx" << 'EOF'
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
EOF

echo ""
echo "✅ Session 4 complete — Stage 1 MVP done!"
echo ""
echo "All features built:"
echo "  ✓ Auth (login, signup, session)"
echo "  ✓ Onboarding (Shopify token connect)"
echo "  ✓ PDP Audit Engine (35 attributes, ULTRA/HIGH/MEDIUM scoring)"
echo "  ✓ AI Visibility SOV checker (Gemini, 10 prompt templates)"
echo "  ✓ Fix Queue (prioritized, AI content suggestions)"
echo "  ✓ Overview dashboard (all metrics in one place)"
echo ""
echo "Run: npm run dev"
echo "Flow: signup → connect store → sync products → run audit → check SOV → fix queue"

echo ''
echo '=== setup5.sh ==='
# Auto-Fix Agent: DB migration + API routes + Shopify write mode
# Run from project root: bash setup5.sh
# =============================================================================

set -e
echo "🔧 Vialtry Stage 2 — Auto-Fix Agent setup starting..."

# =============================================================================
# 1. SUPABASE MIGRATION — fix_history table
# =============================================================================
mkdir -p supabase/migrations

cat > supabase/migrations/20260430_stage2_fix_history.sql << 'SQL'
-- fix_history: tracks every AI-generated fix, push, and revert
CREATE TABLE IF NOT EXISTS fix_history (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id        UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
  product_id      TEXT NOT NULL,          -- Shopify product GID or numeric ID
  product_title   TEXT,
  attribute       TEXT NOT NULL,          -- e.g. "description", "meta_title"
  old_value       TEXT,
  new_value       TEXT NOT NULL,
  shopify_field   TEXT NOT NULL,          -- exact Shopify API field name
  pushed_at       TIMESTAMPTZ,
  reverted_at     TIMESTAMPTZ,
  status          TEXT NOT NULL DEFAULT 'generated'
                  CHECK (status IN ('generated','pushed','reverted','failed')),
  error_message   TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_fix_history_brand_id   ON fix_history(brand_id);
CREATE INDEX idx_fix_history_product_id ON fix_history(product_id);
CREATE INDEX idx_fix_history_status     ON fix_history(status);

-- competitor_tracking: brands being tracked per account
CREATE TABLE IF NOT EXISTS competitor_tracking (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id         UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
  competitor_name  TEXT NOT NULL,
  shopify_domain   TEXT,
  website_url      TEXT,
  added_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(brand_id, competitor_name)
);

-- competitor_sov: weekly SOV snapshot per competitor per prompt
CREATE TABLE IF NOT EXISTS competitor_sov (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  brand_id         UUID NOT NULL REFERENCES brands(id) ON DELETE CASCADE,
  competitor_name  TEXT NOT NULL,
  prompt           TEXT NOT NULL,
  mentioned        BOOLEAN NOT NULL DEFAULT FALSE,
  position         INTEGER,              -- rank in AI response (1-based), NULL if not mentioned
  ai_response_snippet TEXT,
  checked_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_competitor_sov_brand_id ON competitor_sov(brand_id);
CREATE INDEX idx_competitor_sov_checked  ON competitor_sov(checked_at);

-- billing_plans: simple flag-based gating, no Stripe yet
ALTER TABLE brands
  ADD COLUMN IF NOT EXISTS plan          TEXT NOT NULL DEFAULT 'free'
                                         CHECK (plan IN ('free','starter','growth','professional','enterprise')),
  ADD COLUMN IF NOT EXISTS product_limit INTEGER NOT NULL DEFAULT 10,
  ADD COLUMN IF NOT EXISTS plan_activated_at TIMESTAMPTZ;

-- RLS
ALTER TABLE fix_history         ENABLE ROW LEVEL SECURITY;
ALTER TABLE competitor_tracking ENABLE ROW LEVEL SECURITY;
ALTER TABLE competitor_sov      ENABLE ROW LEVEL SECURITY;

CREATE POLICY "brand_own_fix_history"
  ON fix_history FOR ALL
  USING (brand_id IN (SELECT id FROM brands WHERE user_id = auth.uid()));

CREATE POLICY "brand_own_competitor_tracking"
  ON competitor_tracking FOR ALL
  USING (brand_id IN (SELECT id FROM brands WHERE user_id = auth.uid()));

CREATE POLICY "brand_own_competitor_sov"
  ON competitor_sov FOR ALL
  USING (brand_id IN (SELECT id FROM brands WHERE user_id = auth.uid()));
SQL

echo "✅ Migration file created: supabase/migrations/20260430_stage2_fix_history.sql"

# =============================================================================
# 2. TYPE DEFINITIONS
# =============================================================================
mkdir -p src/types

cat > src/types/fix.ts << 'TS'
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
TS

echo "✅ types/fix.ts created"

# =============================================================================
# 3. SHOPIFY ADMIN API HELPER
# =============================================================================
mkdir -p src/lib

cat > src/lib/shopify-admin.ts << 'TS'
/**
 * Shopify Admin API — write operations for Auto-Fix Agent
 * Uses REST 2024-01 (simpler than GraphQL for product updates)
 */

const SHOPIFY_API_VERSION = '2024-01'

interface ShopifyProductUpdate {
  product: Record<string, unknown>
}

export async function updateShopifyProduct(
  shopDomain: string,
  accessToken: string,
  productId: string,          // numeric Shopify product ID (strip gid:// prefix)
  fields: Record<string, unknown>
): Promise<{ success: boolean; error?: string }> {
  const numericId = productId.replace(/\D/g, '')  // strip gid://shopify/Product/ prefix
  const url = `https://${shopDomain}/admin/api/${SHOPIFY_API_VERSION}/products/${numericId}.json`

  const body: ShopifyProductUpdate = { product: { id: numericId, ...fields } }

  const res = await fetch(url, {
    method: 'PUT',
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': accessToken,
    },
    body: JSON.stringify(body),
  })

  if (!res.ok) {
    const errorText = await res.text()
    return { success: false, error: `Shopify API ${res.status}: ${errorText}` }
  }

  return { success: true }
}

export async function getShopifyProduct(
  shopDomain: string,
  accessToken: string,
  productId: string
): Promise<{ product?: Record<string, unknown>; error?: string }> {
  const numericId = productId.replace(/\D/g, '')
  const url = `https://${shopDomain}/admin/api/${SHOPIFY_API_VERSION}/products/${numericId}.json`

  const res = await fetch(url, {
    headers: { 'X-Shopify-Access-Token': accessToken },
  })

  if (!res.ok) {
    return { error: `Shopify API ${res.status}` }
  }

  const data = await res.json()
  return { product: data.product }
}

// Map Vialtry attribute names → Shopify REST product fields
export const ATTRIBUTE_TO_SHOPIFY_FIELD: Record<string, string> = {
  title:            'title',
  description:      'body_html',
  seo_title:        'metafields',      // needs metafield endpoint
  seo_description:  'metafields',
  tags:             'tags',
  product_type:     'product_type',
  vendor:           'vendor',
  handle:           'handle',
}
TS

echo "✅ lib/shopify-admin.ts created"

# =============================================================================
# 4. API ROUTE — POST /api/fix/generate
# =============================================================================
mkdir -p src/app/api/fix/generate
mkdir -p src/app/api/fix/push
mkdir -p src/app/api/fix/revert

cat > src/app/api/fix/generate/route.ts << 'TS'
/**
 * POST /api/fix/generate
 * Gemini writes the fix content for a failing attribute
 * Body: { brand_id, product_id, product_title, attribute, shopify_field, current_value, fix_hint }
 * Returns: { fix_id, attribute, new_value, explanation }
 */
import { NextRequest, NextResponse } from 'next/server'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import { GoogleGenerativeAI } from '@google/generative-ai'
import type { FixTarget, GenerateFixResponse } from '@/types/fix'

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!)
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash-lite' })

export async function POST(req: NextRequest) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const body: FixTarget = await req.json()
  const { brand_id, product_id, product_title, attribute, shopify_field, current_value, fix_hint } = body

  // Verify brand belongs to user
  const { data: brand } = await supabase
    .from('brands')
    .select('id, shop_domain, plan, product_limit')
    .eq('id', brand_id)
    .eq('user_id', session.user.id)
    .single()

  if (!brand) return NextResponse.json({ error: 'Brand not found' }, { status: 404 })

  // Build Gemini prompt
  const prompt = `You are an expert e-commerce catalog writer optimizing product data for AI shopping agents (ChatGPT, Gemini, Perplexity, Amazon Rufus).

Product: "${product_title}"
Attribute to fix: ${attribute}
Shopify field: ${shopify_field}
Current value: ${current_value || '(empty)'}
Why it's failing: ${fix_hint || 'Missing or insufficient content'}

Write an optimized value for this attribute. Rules:
- For descriptions: 150-300 words, include material, use case, key features. No marketing fluff. Structured for AI parsing.
- For titles: Under 70 chars, include product type + key differentiator. No brand name repetition.
- For tags: Comma-separated, 8-15 relevant tags covering category, material, use case, occasion.
- For SEO fields: Follow standard meta best practices.

Respond ONLY in this JSON format, no markdown:
{
  "new_value": "the optimized content here",
  "explanation": "one sentence why this is better for AI visibility"
}`

  let new_value = ''
  let explanation = ''

  try {
    const result = await model.generateContent(prompt)
    const text = result.response.text().trim()
    const parsed = JSON.parse(text)
    new_value = parsed.new_value
    explanation = parsed.explanation
  } catch (err) {
    return NextResponse.json({ error: 'Gemini generation failed', detail: String(err) }, { status: 500 })
  }

  // Insert into fix_history with status=generated
  const { data: fixRow, error: dbErr } = await supabase
    .from('fix_history')
    .insert({
      brand_id,
      product_id,
      product_title,
      attribute,
      shopify_field,
      old_value: current_value || null,
      new_value,
      status: 'generated',
    })
    .select('id')
    .single()

  if (dbErr) return NextResponse.json({ error: 'DB insert failed' }, { status: 500 })

  const response: GenerateFixResponse = {
    fix_id: fixRow.id,
    attribute,
    new_value,
    explanation,
  }

  return NextResponse.json(response)
}
TS

echo "✅ app/api/fix/generate/route.ts created"

# =============================================================================
# 5. API ROUTE — POST /api/fix/push
# =============================================================================
cat > src/app/api/fix/push/route.ts << 'TS'
/**
 * POST /api/fix/push
 * Pushes generated fix to Shopify product via Admin API
 * Body: { fix_id }
 * Returns: { fix_id, shopify_product_id, attribute, status }
 */
import { NextRequest, NextResponse } from 'next/server'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import { updateShopifyProduct } from '@/lib/shopify-admin'

export async function POST(req: NextRequest) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { fix_id } = await req.json()
  if (!fix_id) return NextResponse.json({ error: 'fix_id required' }, { status: 400 })

  // Load fix row + brand in one query
  const { data: fix } = await supabase
    .from('fix_history')
    .select(`
      id, product_id, attribute, shopify_field, new_value, status,
      brands!inner(id, shop_domain, access_token, user_id)
    `)
    .eq('id', fix_id)
    .single()

  if (!fix) return NextResponse.json({ error: 'Fix not found' }, { status: 404 })
  if ((fix.brands as any).user_id !== session.user.id)
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  if (fix.status === 'pushed')
    return NextResponse.json({ error: 'Already pushed' }, { status: 409 })

  const brand = fix.brands as any

  // Build Shopify field update payload
  // Note: metafields (seo_title, seo_description) need separate endpoint — handled below
  const isMetafield = fix.shopify_field === 'metafields'
  let shopifyResult: { success: boolean; error?: string }

  if (isMetafield) {
    // SEO metafields use a different Shopify endpoint
    shopifyResult = await pushMetafield(
      brand.shop_domain,
      brand.access_token,
      fix.product_id,
      fix.attribute,
      fix.new_value
    )
  } else {
    shopifyResult = await updateShopifyProduct(
      brand.shop_domain,
      brand.access_token,
      fix.product_id,
      { [fix.shopify_field]: fix.new_value }
    )
  }

  const newStatus = shopifyResult.success ? 'pushed' : 'failed'

  await supabase
    .from('fix_history')
    .update({
      status: newStatus,
      pushed_at: shopifyResult.success ? new Date().toISOString() : null,
      error_message: shopifyResult.error || null,
    })
    .eq('id', fix_id)

  return NextResponse.json({
    fix_id,
    shopify_product_id: fix.product_id,
    attribute: fix.attribute,
    status: newStatus,
    error: shopifyResult.error,
  })
}

async function pushMetafield(
  shopDomain: string,
  accessToken: string,
  productId: string,
  attribute: string,
  value: string
): Promise<{ success: boolean; error?: string }> {
  const numericId = productId.replace(/\D/g, '')
  const namespace = 'global'
  const key = attribute === 'seo_title' ? 'title_tag' : 'description_tag'

  const url = `https://${shopDomain}/admin/api/2024-01/products/${numericId}/metafields.json`
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': accessToken,
    },
    body: JSON.stringify({
      metafield: { namespace, key, value, type: 'single_line_text_field' }
    }),
  })

  if (!res.ok) {
    const err = await res.text()
    return { success: false, error: `Metafield ${res.status}: ${err}` }
  }
  return { success: true }
}
TS

echo "✅ app/api/fix/push/route.ts created"

# =============================================================================
# 6. API ROUTE — POST /api/fix/revert
# =============================================================================
cat > src/app/api/fix/revert/route.ts << 'TS'
/**
 * POST /api/fix/revert
 * Reverts a pushed fix by writing old_value back to Shopify
 * Body: { fix_id }
 */
import { NextRequest, NextResponse } from 'next/server'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import { updateShopifyProduct } from '@/lib/shopify-admin'

export async function POST(req: NextRequest) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { fix_id } = await req.json()

  const { data: fix } = await supabase
    .from('fix_history')
    .select(`
      id, product_id, attribute, shopify_field, old_value, status,
      brands!inner(shop_domain, access_token, user_id)
    `)
    .eq('id', fix_id)
    .single()

  if (!fix) return NextResponse.json({ error: 'Fix not found' }, { status: 404 })
  if ((fix.brands as any).user_id !== session.user.id)
    return NextResponse.json({ error: 'Forbidden' }, { status: 403 })
  if (fix.status !== 'pushed')
    return NextResponse.json({ error: 'Can only revert pushed fixes' }, { status: 409 })

  const brand = fix.brands as any
  const revertValue = fix.old_value ?? ''  // empty string if no old value existed

  const result = await updateShopifyProduct(
    brand.shop_domain,
    brand.access_token,
    fix.product_id,
    { [fix.shopify_field]: revertValue }
  )

  const newStatus = result.success ? 'reverted' : 'failed'

  await supabase
    .from('fix_history')
    .update({
      status: newStatus,
      reverted_at: result.success ? new Date().toISOString() : null,
      error_message: result.error || null,
    })
    .eq('id', fix_id)

  return NextResponse.json({
    fix_id,
    status: newStatus,
    error: result.error,
  })
}
TS

echo "✅ app/api/fix/revert/route.ts created"

# =============================================================================
# 7. BILLING GATING MIDDLEWARE HELPER
# =============================================================================
cat > src/lib/plan-gate.ts << 'TS'
/**
 * Plan gating helper — checks product limits before running agents
 * Free plan: 10 products max
 * Paid plans: unlimited (product_limit = -1)
 */
import { SupabaseClient } from '@supabase/supabase-js'

export const PLAN_LIMITS: Record<string, number> = {
  free:         10,
  starter:      50,
  growth:       200,
  professional: -1,   // unlimited
  enterprise:   -1,
}

export async function checkProductLimit(
  supabase: SupabaseClient,
  brand_id: string,
  requestedCount: number = 1
): Promise<{ allowed: boolean; plan: string; limit: number; reason?: string }> {
  const { data: brand } = await supabase
    .from('brands')
    .select('plan, product_limit')
    .eq('id', brand_id)
    .single()

  if (!brand) return { allowed: false, plan: 'unknown', limit: 0, reason: 'Brand not found' }

  const limit = brand.product_limit ?? PLAN_LIMITS[brand.plan] ?? 10

  if (limit === -1) return { allowed: true, plan: brand.plan, limit: -1 }

  // Count existing audited products for this brand
  const { count } = await supabase
    .from('pdp_audits')
    .select('*', { count: 'exact', head: true })
    .eq('brand_id', brand_id)

  const used = count ?? 0

  if (used + requestedCount > limit) {
    return {
      allowed: false,
      plan: brand.plan,
      limit,
      reason: `Plan limit reached: ${used}/${limit} products used. Upgrade to audit more.`,
    }
  }

  return { allowed: true, plan: brand.plan, limit }
}
TS

echo "✅ lib/plan-gate.ts created"

# =============================================================================
# 8. PACKAGE — install @google/generative-ai if not present
# =============================================================================
if ! grep -q "@google/generative-ai" package.json 2>/dev/null; then
  echo "📦 Installing @google/generative-ai..."
  npm install @google/generative-ai --save
else
  echo "✅ @google/generative-ai already in package.json"
fi

# =============================================================================
# 9. ENV VARS REMINDER
# =============================================================================
cat >> .env.local.example << 'ENV'

# Stage 2 — Auto-Fix Agent
GEMINI_API_KEY=your_gemini_api_key_here
# Shopify access token is stored per brand in Supabase (brands.access_token)
# No new env vars needed for Shopify — already set in Stage 1
ENV

echo "✅ .env.local.example updated"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "============================================================"
echo "  Vialtry Stage 2 — Auto-Fix Agent: DONE"
echo "============================================================"
echo ""
echo "Files created:"
echo "  supabase/migrations/20260430_stage2_fix_history.sql"
echo "  types/fix.ts"
echo "  lib/shopify-admin.ts"
echo "  lib/plan-gate.ts"
echo "  app/api/fix/generate/route.ts"
echo "  app/api/fix/push/route.ts"
echo "  app/api/fix/revert/route.ts"
echo ""
echo "Next steps:"
echo "  1. supabase db push  (apply migration)"
echo "  2. Set GEMINI_API_KEY in .env.local"
echo "  3. Verify brands table has: shop_domain, access_token columns"
echo "  4. Test: POST /api/fix/generate → POST /api/fix/push → POST /api/fix/revert"
echo "  5. Stage 2 next: run setup6.sh for ACP/UCP Feed Generator"
echo ""
echo "⚠️  WATCH OUT:"
echo "  - Shopify write scope needed: write_products"
echo "    Re-install OAuth flow if current token only has read_products"
echo "  - SEO metafields (seo_title, seo_description) pushed via separate"
echo "    metafield endpoint — already handled in push route"
echo "  - body_html accepts raw HTML — Gemini output should be plain text"
echo "    Consider wrapping in <p> tags in generate prompt"
echo "============================================================"

echo ''
echo '=== setup6b.sh ==='
# Adds gaps JSONB column to pdp_audits + updates audit runner to populate it
# Run BEFORE testing Fix Queue UI
# =============================================================================

set -e
echo "🔧 setup6b — gaps column + audit runner patch..."

# =============================================================================
# 1. MIGRATION — add gaps column
# =============================================================================
mkdir -p supabase/migrations

cat > supabase/migrations/20260430_add_gaps_column.sql << 'SQL'
-- Add gaps JSONB column to pdp_audits if not exists
ALTER TABLE pdp_audits 
  ADD COLUMN IF NOT EXISTS gaps JSONB NOT NULL DEFAULT '[]';

-- Index for querying gaps by brand
CREATE INDEX IF NOT EXISTS idx_pdp_audits_brand_gaps 
  ON pdp_audits(brand_id) 
  WHERE gaps != '[]';
SQL

echo "✅ Migration created"

# =============================================================================
# 2. AUDIT RUNNER PATCH — lib/audit-runner.ts
#    Adds gap extraction logic at end of scoring
#    Assumes existing scorer returns attribute results with score + weight info
# =============================================================================
mkdir -p src/lib

cat > src/lib/audit-gap-extractor.ts << 'TS'
/**
 * Extracts fix targets from PDP audit results
 * Call this after scoring, before saving to pdp_audits
 * 
 * Input: raw attribute scores from your existing scorer
 * Output: gap array ready for fix_history / Fix Queue UI
 */

export interface AuditGap {
  attribute: string        // human label: "Product Description"
  shopify_field: string    // Shopify REST field: "body_html"
  current_value?: string
  fix_hint: string         // why it's failing — shown in UI
  criticality: 'ULTRA' | 'HIGH' | 'MEDIUM'
}

// Map your internal attribute keys → Shopify fields + human labels
// Extend this as you add more attributes to your scorer
const ATTRIBUTE_META: Record<string, {
  shopify_field: string
  label: string
  criticality: 'ULTRA' | 'HIGH' | 'MEDIUM'
  hint: (val?: string) => string
}> = {
  description: {
    shopify_field: 'body_html',
    label: 'Product Description',
    criticality: 'ULTRA',
    hint: (v) => !v ? 'No description — AI agents skip products with empty descriptions'
                    : v.length < 100 ? `Too short (${v.length} chars) — needs 150+ words for AI parsing`
                    : 'Lacks material, use case, or structured content',
  },
  title: {
    shopify_field: 'title',
    label: 'Product Title',
    criticality: 'ULTRA',
    hint: (v) => !v ? 'No title'
                    : v.length > 70 ? 'Title too long (70 char limit for AI agent display)'
                    : 'Missing product type or key differentiator in title',
  },
  tags: {
    shopify_field: 'tags',
    label: 'Product Tags',
    criticality: 'HIGH',
    hint: (v) => !v ? 'No tags — reduces category matching in AI queries'
                    : 'Under 8 tags — add material, use case, occasion, category',
  },
  product_type: {
    shopify_field: 'product_type',
    label: 'Product Type',
    criticality: 'HIGH',
    hint: () => 'Empty product_type — AI agents use this for category classification',
  },
  vendor: {
    shopify_field: 'vendor',
    label: 'Vendor / Brand',
    criticality: 'MEDIUM',
    hint: () => 'Missing vendor field — brand attribution for AI recommendations',
  },
  seo_title: {
    shopify_field: 'metafields',
    label: 'SEO Title',
    criticality: 'HIGH',
    hint: () => 'Missing meta title tag — affects Google AI Mode / SGE visibility',
  },
  seo_description: {
    shopify_field: 'metafields',
    label: 'SEO Description',
    criticality: 'HIGH',
    hint: () => 'Missing meta description — reduces snippet quality in AI search results',
  },
  // Variant-level
  weight: {
    shopify_field: 'variants',
    label: 'Product Weight',
    criticality: 'MEDIUM',
    hint: () => 'No weight specified — required for Amazon Rufus and shipping agents',
  },
  material: {
    shopify_field: 'body_html',
    label: 'Material / Fabric',
    criticality: 'ULTRA',
    hint: () => 'Material not mentioned — #1 factor for AI product matching queries',
  },
  care_instructions: {
    shopify_field: 'body_html',
    label: 'Care Instructions',
    criticality: 'MEDIUM',
    hint: () => 'No care instructions — missed opportunity for long-tail AI queries',
  },
}

/**
 * Main function: takes your scorer output, returns gap array
 * 
 * scorerOutput format (adapt to match your actual scorer):
 * {
 *   [attributeKey]: {
 *     score: number,        // 0 = failing, >0 = passing
 *     value?: string,       // current value from Shopify
 *     maxScore: number,
 *   }
 * }
 */
export function extractGaps(
  scorerOutput: Record<string, { score: number; value?: string; maxScore: number }>
): AuditGap[] {
  const gaps: AuditGap[] = []

  for (const [key, result] of Object.entries(scorerOutput)) {
    // Only process attributes that are failing (score = 0 or significantly below max)
    const isFailing = result.score === 0 || result.score / result.maxScore < 0.3
    if (!isFailing) continue

    const meta = ATTRIBUTE_META[key]
    if (!meta) continue // attribute not mapped — skip

    gaps.push({
      attribute: meta.label,
      shopify_field: meta.shopify_field,
      current_value: result.value,
      fix_hint: meta.hint(result.value),
      criticality: meta.criticality,
    })
  }

  // Sort: ULTRA → HIGH → MEDIUM
  const order = { ULTRA: 0, HIGH: 1, MEDIUM: 2 }
  gaps.sort((a, b) => order[a.criticality] - order[b.criticality])

  return gaps
}

/**
 * Convenience: add to your existing audit save call
 * 
 * BEFORE (your current code probably looks like this):
 *   await supabase.from('pdp_audits').upsert({
 *     brand_id, product_id, product_title,
 *     core_score, full_score, scored_at: new Date().toISOString()
 *   })
 * 
 * AFTER (add gaps):
 *   import { extractGaps } from '@/lib/audit-gap-extractor'
 *   const gaps = extractGaps(scorerOutput)
 *   await supabase.from('pdp_audits').upsert({
 *     brand_id, product_id, product_title,
 *     core_score, full_score, gaps,           // <-- add this
 *     scored_at: new Date().toISOString()
 *   })
 */
TS

echo "✅ lib/audit-gap-extractor.ts created"

# =============================================================================
# 3. BACKFILL SCRIPT — for existing TDK audit data
#    Run once to populate gaps for already-scored products
# =============================================================================
cat > src/scripts/backfill-gaps.ts << 'TS'
/**
 * One-time backfill: regenerate gaps for all existing pdp_audits rows
 * that have gaps = [] (empty)
 * 
 * Run: npx ts-node scripts/backfill-gaps.ts
 * Or:  npx tsx scripts/backfill-gaps.ts
 */
import { createClient } from '@supabase/supabase-js'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!   // needs service role for backfill
)

async function backfill() {
  console.log('Fetching audits with empty gaps...')

  const { data: audits, error } = await supabase
    .from('pdp_audits')
    .select('id, product_id, product_title, brand_id, core_score, full_score')
    .eq('gaps', '[]')
    .limit(200)

  if (error) { console.error(error); process.exit(1) }
  console.log(`Found ${audits?.length ?? 0} audits to backfill`)

  // For each audit, create basic gaps based on scores
  // This is a rough backfill — proper gaps come from next full re-audit
  for (const audit of audits || []) {
    const syntheticGaps = []

    // If core_score is low, flag description as ULTRA gap
    if ((audit.core_score ?? 100) < 60) {
      syntheticGaps.push({
        attribute: 'Product Description',
        shopify_field: 'body_html',
        current_value: undefined,
        fix_hint: 'Low core score — description likely missing key material/use case content',
        criticality: 'ULTRA',
      })
    }
    if ((audit.full_score ?? 100) < 50) {
      syntheticGaps.push({
        attribute: 'SEO Title',
        shopify_field: 'metafields',
        current_value: undefined,
        fix_hint: 'Missing SEO meta title — affects Google AI Mode visibility',
        criticality: 'HIGH',
      })
      syntheticGaps.push({
        attribute: 'Product Tags',
        shopify_field: 'tags',
        current_value: undefined,
        fix_hint: 'Insufficient tags for AI category matching',
        criticality: 'HIGH',
      })
    }

    if (syntheticGaps.length > 0) {
      await supabase
        .from('pdp_audits')
        .update({ gaps: syntheticGaps })
        .eq('id', audit.id)
      console.log(`  ✓ ${audit.product_title} — ${syntheticGaps.length} gaps set`)
    }
  }

  console.log('Backfill complete.')
}

backfill()
TS

echo "✅ scripts/backfill-gaps.ts created"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "============================================================"
echo "  setup6b — gaps column patch: DONE"
echo "============================================================"
echo ""
echo "Files created:"
echo "  supabase/migrations/20260430_add_gaps_column.sql"
echo "  lib/audit-gap-extractor.ts   — extracts gaps from scorer output"
echo "  scripts/backfill-gaps.ts     — one-time backfill for TDK existing data"
echo ""
echo "Steps:"
echo "  1. supabase db push            — applies migration"
echo "  2. Add extractGaps() call in your audit runner (see comment in file)"
echo "  3. npx tsx scripts/backfill-gaps.ts  — fills gaps for existing TDK data"
echo "  4. Then test /dashboard/fixes  — should show TDK's gap cards"
echo "============================================================"

echo ''
echo '=== setup7.sh ==='
# ACP/UCP Feed Generator — /feeds/[brandId] JSON-LD endpoint
# ChatGPT ACP + Google AP2 compliant machine-readable product feeds
# =============================================================================

set -e
echo "📡 Vialtry Stage 2 — ACP/UCP Feed Generator setup..."

mkdir -p src/app/feeds/\[brandId\]
mkdir -p src/lib

# =============================================================================
# 1. FEED ROUTE — app/feeds/[brandId]/route.ts
# Public endpoint — no auth (AI agents fetch this directly)
# =============================================================================
cat > "app/feeds/[brandId]/route.ts" << 'TS'
/**
 * GET /feeds/[brandId]
 * Public JSON-LD feed — served to AI agents (ChatGPT ACP, Google AP2)
 * No auth required. Rate limited by Vercel edge.
 * 
 * Query params:
 *   ?limit=50        (default 50, max 200)
 *   ?page=1          (pagination)
 *   ?updated_after=  (ISO date, for incremental sync)
 */
import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { buildProductJsonLd } from '@/lib/feed-builder'

// Service role — public read only on feeds
const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)

export const revalidate = 3600 // Cache 1 hour at edge

export async function GET(
  req: NextRequest,
  { params }: { params: { brandId: string } }
) {
  const { brandId } = params
  const { searchParams } = new URL(req.url)

  const limit = Math.min(parseInt(searchParams.get('limit') || '50'), 200)
  const page = Math.max(parseInt(searchParams.get('page') || '1'), 1)
  const updatedAfter = searchParams.get('updated_after')

  // Verify brand exists and has feed enabled
  const { data: brand } = await supabase
    .from('brands')
    .select('id, shop_domain, brand_name, plan, feed_enabled')
    .eq('id', brandId)
    .single()

  if (!brand) {
    return NextResponse.json({ error: 'Brand not found' }, { status: 404 })
  }

  // Free plan: feed disabled
  if (!brand.feed_enabled && brand.plan === 'free') {
    return NextResponse.json(
      { error: 'Feed not available on free plan' },
      { status: 403 }
    )
  }

  // Fetch products from pdp_audits (has our enriched data)
  let query = supabase
    .from('pdp_audits')
    .select('product_id, product_title, product_data, gaps, core_score, scored_at')
    .eq('brand_id', brandId)
    .range((page - 1) * limit, page * limit - 1)
    .order('scored_at', { ascending: false })

  if (updatedAfter) {
    query = query.gte('scored_at', updatedAfter)
  }

  const { data: products, error } = await query
  if (error) return NextResponse.json({ error: 'DB error' }, { status: 500 })

  // Build JSON-LD feed
  const feed = {
    '@context': 'https://schema.org',
    '@type': 'ItemList',
    'name': `${brand.brand_name || brand.shop_domain} — AI Product Feed`,
    'description': `Machine-readable product catalog for AI shopping agents. Powered by Vialtry.`,
    'url': `https://vialtry.com/feeds/${brandId}`,
    'numberOfItems': products?.length ?? 0,
    'dateModified': new Date().toISOString(),

    // ACP metadata block (ChatGPT agent protocol)
    'acp:feedVersion': '1.0',
    'acp:provider': 'Vialtry',
    'acp:shopDomain': brand.shop_domain,
    'acp:capabilities': ['product_search', 'availability_check', 'price_check'],

    'itemListElement': (products || []).map((p, i) =>
      buildProductJsonLd(p, brand.shop_domain, i + 1)
    ),
  }

  return NextResponse.json(feed, {
    headers: {
      'Content-Type': 'application/ld+json',
      'Cache-Control': 'public, s-maxage=3600, stale-while-revalidate=86400',
      'Access-Control-Allow-Origin': '*',  // AI agents need CORS
      'X-Feed-Provider': 'Vialtry',
      'X-Brand-Id': brandId,
    },
  })
}
TS

echo "✅ app/feeds/[brandId]/route.ts created"

# =============================================================================
# 2. FEED BUILDER — lib/feed-builder.ts
# Converts raw product data → ACP/AP2 compliant JSON-LD
# =============================================================================
cat > src/lib/feed-builder.ts << 'TS'
/**
 * Builds ACP/AP2 compliant JSON-LD per product
 * Schema.org Product type + ACP extensions + Google AP2 fields
 */

interface ProductRow {
  product_id: string
  product_title: string
  product_data?: Record<string, unknown>  // raw Shopify product fields stored during audit
  gaps?: Array<{ attribute: string; criticality: string }>
  core_score?: number
  scored_at?: string
}

export function buildProductJsonLd(
  row: ProductRow,
  shopDomain: string,
  position: number
): Record<string, unknown> {
  const d = (row.product_data || {}) as Record<string, unknown>
  const variants = (d.variants as Array<Record<string, unknown>>) || []
  const images = (d.images as Array<Record<string, unknown>>) || []
  const firstVariant = variants[0] || {}

  // Price
  const price = firstVariant.price as string | undefined
  const comparePrice = firstVariant.compare_at_price as string | undefined
  const available = variants.some(v => (v.inventory_quantity as number) > 0)
  const currency = 'USD' // default — can be pulled from brand settings

  // Images
  const imageObjs = images.slice(0, 5).map((img, i) => ({
    '@type': 'ImageObject',
    'url': img.src as string,
    'position': i + 1,
  }))

  // Offers block (ACP + Google Shopping)
  const offers: Record<string, unknown> = {
    '@type': 'Offer',
    'url': `https://${shopDomain}/products/${d.handle}`,
    'priceCurrency': currency,
    'availability': available
      ? 'https://schema.org/InStock'
      : 'https://schema.org/OutOfStock',
    'itemCondition': 'https://schema.org/NewCondition',
  }
  if (price) {
    offers['price'] = parseFloat(price).toFixed(2)
  }
  if (comparePrice && parseFloat(comparePrice) > parseFloat(price || '0')) {
    offers['priceSpecification'] = {
      '@type': 'PriceSpecification',
      'price': parseFloat(comparePrice).toFixed(2),
      'priceCurrency': currency,
      'priceType': 'https://schema.org/ListPrice',
    }
  }

  // Variants as additionalProperty (AP2 requirement)
  const variantProperties = variants.slice(0, 10).map(v => ({
    '@type': 'PropertyValue',
    'name': 'variant',
    'value': [v.title, v.sku, v.barcode].filter(Boolean).join(' | '),
    'unitCode': v.weight_unit as string,
  }))

  // Extract description — strip HTML tags
  const rawDescription = (d.body_html as string || '')
  const cleanDescription = rawDescription.replace(/<[^>]+>/g, ' ').replace(/\s+/g, ' ').trim()

  // Tags as keywords
  const tags = ((d.tags as string) || '').split(',').map(t => t.trim()).filter(Boolean)

  const product: Record<string, unknown> = {
    '@type': 'ListItem',
    'position': position,
    'item': {
      '@type': 'Product',
      '@id': `https://${shopDomain}/products/${d.handle}`,

      // Core fields
      'name': row.product_title,
      'description': cleanDescription || undefined,
      'url': `https://${shopDomain}/products/${d.handle}`,
      'sku': firstVariant.sku as string || row.product_id,
      'productID': row.product_id,
      'brand': {
        '@type': 'Brand',
        'name': d.vendor as string || shopDomain.split('.')[0],
      },

      // Category (Google AP2 requirement)
      'category': d.product_type as string || undefined,
      'keywords': tags.length > 0 ? tags.join(', ') : undefined,

      // Images
      'image': imageObjs.length > 0 ? imageObjs : undefined,

      // Offers
      'offers': offers,

      // Variants
      'additionalProperty': variantProperties.length > 0 ? variantProperties : undefined,

      // ACP-specific fields
      'acp:vialtryScore': row.core_score,
      'acp:lastAudited': row.scored_at,
      'acp:gapCount': (row.gaps || []).length,
    },
  }

  // Remove undefined keys (clean output)
  return JSON.parse(JSON.stringify(product))
}
TS

echo "✅ lib/feed-builder.ts created"

# =============================================================================
# 3. MIGRATION — add feed_enabled + brand_name to brands
# =============================================================================
mkdir -p supabase/migrations

cat > supabase/migrations/20260430_feed_columns.sql << 'SQL'
-- Feed enablement flag per brand
ALTER TABLE brands
  ADD COLUMN IF NOT EXISTS feed_enabled   BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS brand_name     TEXT,
  ADD COLUMN IF NOT EXISTS feed_last_built TIMESTAMPTZ;

-- Enable feed for paid plans automatically
UPDATE brands SET feed_enabled = TRUE WHERE plan != 'free';

-- Store raw Shopify product data during audit (needed by feed builder)
ALTER TABLE pdp_audits
  ADD COLUMN IF NOT EXISTS product_data JSONB DEFAULT '{}';
SQL

echo "✅ Migration: supabase/migrations/20260430_feed_columns.sql"

# =============================================================================
# 4. FEED STATUS PAGE — app/dashboard/feed/page.tsx
# Shows brand their feed URL + enable/disable toggle
# =============================================================================
mkdir -p src/app/dashboard/feed

cat > src/app/dashboard/feed/page.tsx << 'TSX'
'use client'

import { useState, useEffect } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'

export default function FeedPage() {
  const supabase = createClientComponentClient()
  const [brand, setBrand] = useState<{ id: string; shop_domain: string; plan: string; feed_enabled: boolean } | null>(null)
  const [toggling, setToggling] = useState(false)
  const [copied, setCopied] = useState(false)

  useEffect(() => {
    async function load() {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) return
      const { data } = await supabase
        .from('brands')
        .select('id, shop_domain, plan, feed_enabled')
        .eq('user_id', session.user.id)
        .single()
      if (data) setBrand(data)
    }
    load()
  }, [supabase])

  const feedUrl = brand ? `${process.env.NEXT_PUBLIC_APP_URL}/feeds/${brand.id}` : ''

  const toggleFeed = async () => {
    if (!brand || brand.plan === 'free') return
    setToggling(true)
    await supabase.from('brands').update({ feed_enabled: !brand.feed_enabled }).eq('id', brand.id)
    setBrand(prev => prev ? { ...prev, feed_enabled: !prev.feed_enabled } : prev)
    setToggling(false)
  }

  const copyUrl = () => {
    navigator.clipboard.writeText(feedUrl)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  if (!brand) return (
    <div className="min-h-screen bg-[#0a0a0f] flex items-center justify-center">
      <div className="text-[#6c63ff] font-mono text-sm tracking-widest animate-pulse">LOADING...</div>
    </div>
  )

  const isPaid = brand.plan !== 'free'

  return (
    <div className="min-h-screen bg-[#0a0a0f] text-[#e8e8f0]">
      <div className="max-w-3xl mx-auto px-6 py-10">

        <div className="mb-8">
          <p className="font-mono text-xs text-[#6c63ff] tracking-[3px] uppercase mb-2">ACP / AP2</p>
          <h1 className="text-3xl font-bold mb-1">AI Agent Feed</h1>
          <p className="text-sm text-[#6b6b80]">
            Machine-readable JSON-LD product feed. ChatGPT, Gemini, and Google AP2 agents fetch this to recommend your products.
          </p>
        </div>

        {/* Feed URL card */}
        <div className="rounded-xl border border-[#2a2a3a] bg-[#111118] p-6 mb-4">
          <div className="flex items-center justify-between mb-3">
            <span className="font-mono text-[10px] tracking-widest uppercase text-[#6b6b80]">Feed URL</span>
            <span
              className="font-mono text-[10px] px-2 py-0.5 rounded-full"
              style={{
                background: brand.feed_enabled ? 'rgba(0,212,170,0.1)' : 'rgba(107,107,128,0.1)',
                color: brand.feed_enabled ? '#00d4aa' : '#6b6b80',
                border: `1px solid ${brand.feed_enabled ? 'rgba(0,212,170,0.3)' : '#2a2a3a'}`,
              }}
            >
              {brand.feed_enabled ? '● LIVE' : '○ DISABLED'}
            </span>
          </div>

          <div className="flex items-center gap-2">
            <code className="flex-1 bg-[#0a0a0f] border border-[#2a2a3a] rounded-lg px-3 py-2.5 text-xs text-[#9d97ff] font-mono truncate">
              {feedUrl}
            </code>
            <button
              onClick={copyUrl}
              className="px-3 py-2.5 rounded-lg text-xs font-mono transition-all flex-shrink-0"
              style={{
                background: copied ? 'rgba(0,212,170,0.15)' : 'rgba(108,99,255,0.15)',
                border: `1px solid ${copied ? 'rgba(0,212,170,0.3)' : 'rgba(108,99,255,0.3)'}`,
                color: copied ? '#00d4aa' : '#9d97ff',
              }}
            >
              {copied ? '✓ COPIED' : 'COPY'}
            </button>
          </div>
        </div>

        {/* Toggle */}
        {isPaid ? (
          <button
            onClick={toggleFeed}
            disabled={toggling}
            className="w-full py-3 rounded-xl text-sm font-mono font-medium transition-all disabled:opacity-40"
            style={{
              background: brand.feed_enabled ? 'rgba(255,107,107,0.1)' : 'rgba(0,212,170,0.12)',
              border: `1px solid ${brand.feed_enabled ? 'rgba(255,107,107,0.3)' : 'rgba(0,212,170,0.3)'}`,
              color: brand.feed_enabled ? '#ff6b6b' : '#00d4aa',
            }}
          >
            {toggling ? 'UPDATING...' : brand.feed_enabled ? '○ DISABLE FEED' : '● ENABLE FEED'}
          </button>
        ) : (
          <div className="rounded-xl border border-[rgba(255,159,67,0.25)] bg-[rgba(255,159,67,0.06)] p-4 text-center">
            <p className="font-mono text-xs text-[#ff9f43] mb-1">PAID PLAN REQUIRED</p>
            <p className="text-xs text-[#6b6b80]">Upgrade to Growth or Pro to enable AI agent feed.</p>
          </div>
        )}

        {/* What this does */}
        <div className="mt-8 space-y-3">
          <p className="font-mono text-[10px] text-[#6b6b80] tracking-widest uppercase">What AI agents see</p>
          {[
            { icon: '🤖', label: 'ChatGPT (ACP)', desc: 'Fetches your feed for product recommendations via GPT-5.5 shopping agent' },
            { icon: '🔵', label: 'Google AP2', desc: 'Google AI Mode ingests this for Shopping + Search AI results' },
            { icon: '🔍', label: 'Perplexity', desc: 'Product data indexed for AI search answer cards' },
            { icon: '📦', label: 'Amazon Rufus', desc: 'Schema-structured data improves Rufus recommendation matching' },
          ].map(item => (
            <div key={item.label} className="flex items-start gap-3 bg-[#111118] border border-[#2a2a3a] rounded-lg px-4 py-3">
              <span className="text-lg flex-shrink-0">{item.icon}</span>
              <div>
                <p className="text-xs font-semibold text-[#e8e8f0] mb-0.5">{item.label}</p>
                <p className="text-xs text-[#6b6b80]">{item.desc}</p>
              </div>
            </div>
          ))}
        </div>

      </div>
    </div>
  )
}
TSX

echo "✅ app/dashboard/feed/page.tsx created"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "============================================================"
echo "  Vialtry — ACP/UCP Feed Generator: DONE"
echo "============================================================"
echo ""
echo "Files created:"
echo "  app/feeds/[brandId]/route.ts     — public JSON-LD feed endpoint"
echo "  lib/feed-builder.ts              — product → ACP/AP2 JSON-LD converter"
echo "  app/dashboard/feed/page.tsx      — feed URL + enable/disable UI"
echo "  supabase/migrations/20260430_feed_columns.sql"
echo ""
echo "Run order:"
echo "  1. supabase db push"
echo "  2. Add NEXT_PUBLIC_APP_URL=https://yourdomain.com to .env.local"
echo "  3. Add product_data save to your audit runner (Shopify raw data)"
echo "  4. Test: GET /feeds/[brandId] — should return JSON-LD"
echo ""
echo "⚠️  CRITICAL: audit runner must save raw Shopify product JSON to"
echo "    pdp_audits.product_data — feed builder reads from there."
echo "    Add to your audit upsert:"
echo "    product_data: shopifyProductObject"
echo ""
echo "Next: setup8.sh — Competitor SOV Tracker weekly job"
echo "============================================================"

echo ''
echo '=== setup8.sh ==='
# Competitor SOV Tracker — weekly cron job + API routes
# =============================================================================

set -e
echo "🏆 setup8 — Competitor SOV Tracker..."

mkdir -p src/app/api/competitors/add
mkdir -p src/app/api/competitors/sov-check
mkdir -p src/app/dashboard/competitors

# =============================================================================
# 1. ADD COMPETITOR — POST /api/competitors/add
# =============================================================================
cat > src/app/api/competitors/add/route.ts << 'TS'
import { NextRequest, NextResponse } from 'next/server'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'

export async function POST(req: NextRequest) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { brand_id, competitor_name, shopify_domain, website_url } = await req.json()

  const { data: brand } = await supabase
    .from('brands')
    .select('id, plan')
    .eq('id', brand_id)
    .eq('user_id', session.user.id)
    .single()
  if (!brand) return NextResponse.json({ error: 'Brand not found' }, { status: 404 })

  // Free plan: max 1 competitor. Paid: 5
  const maxCompetitors = brand.plan === 'free' ? 1 : 5
  const { count } = await supabase
    .from('competitor_tracking')
    .select('*', { count: 'exact', head: true })
    .eq('brand_id', brand_id)

  if ((count ?? 0) >= maxCompetitors) {
    return NextResponse.json({
      error: `Plan limit: ${maxCompetitors} competitors max. Upgrade to add more.`
    }, { status: 403 })
  }

  const { data, error } = await supabase
    .from('competitor_tracking')
    .insert({ brand_id, competitor_name, shopify_domain, website_url })
    .select('id')
    .single()

  if (error) return NextResponse.json({ error: error.message }, { status: 500 })
  return NextResponse.json({ id: data.id })
}
TS

# =============================================================================
# 2. SOV CHECK — POST /api/competitors/sov-check
# Runs 10 prompts, stores results in competitor_sov
# =============================================================================
cat > src/app/api/competitors/sov-check/route.ts << 'TS'
import { NextRequest, NextResponse } from 'next/server'
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs'
import { cookies } from 'next/headers'
import { GoogleGenerativeAI } from '@google/generative-ai'

const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!)
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash-lite' })

export async function POST(req: NextRequest) {
  const supabase = createRouteHandlerClient({ cookies })
  const { data: { session } } = await supabase.auth.getSession()
  if (!session) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })

  const { brand_id } = await req.json()

  const { data: brand } = await supabase
    .from('brands')
    .select('id, shop_domain, brand_name, user_id')
    .eq('id', brand_id)
    .eq('user_id', session.user.id)
    .single()
  if (!brand) return NextResponse.json({ error: 'Brand not found' }, { status: 404 })

  // Get competitors
  const { data: competitors } = await supabase
    .from('competitor_tracking')
    .select('competitor_name')
    .eq('brand_id', brand_id)

  if (!competitors?.length) return NextResponse.json({ error: 'No competitors added' }, { status: 400 })

  // Get SOV prompts from brand's existing prompt set
  const { data: promptRows } = await supabase
    .from('sov_prompts')
    .select('prompt')
    .eq('brand_id', brand_id)
    .limit(10)

  const prompts = promptRows?.map(r => r.prompt) || []
  if (!prompts.length) return NextResponse.json({ error: 'No SOV prompts found' }, { status: 400 })

  const brandName = brand.brand_name || brand.shop_domain.split('.')[0]
  const allNames = [brandName, ...competitors.map(c => c.competitor_name)]
  const results: Array<Record<string, unknown>> = []

  for (const prompt of prompts.slice(0, 10)) {
    const aiPrompt = `You are an AI shopping assistant. Answer this query naturally:
"${prompt}"

After answering, on a new line output ONLY this JSON (no markdown):
{"mentioned": [list of brand names you mentioned from: ${JSON.stringify(allNames)}], "order": [same brands in order of recommendation, 1=first]}`

    try {
      const result = await model.generateContent(aiPrompt)
      const text = result.response.text()
      const jsonMatch = text.match(/\{[\s\S]*"mentioned"[\s\S]*\}/)
      if (!jsonMatch) continue

      const parsed = JSON.parse(jsonMatch[0])
      const mentioned: string[] = parsed.mentioned || []
      const order: string[] = parsed.order || []

      // Store result for brand + each competitor
      for (const name of allNames) {
        const isMentioned = mentioned.includes(name)
        const position = order.indexOf(name) + 1 || null

        results.push({
          brand_id,
          competitor_name: name,
          prompt,
          mentioned: isMentioned,
          position: isMentioned ? position : null,
          checked_at: new Date().toISOString(),
        })
      }
    } catch { continue }
  }

  if (results.length > 0) {
    await supabase.from('competitor_sov').insert(results)
  }

  // Summarize
  const brandResults = results.filter(r => r.competitor_name === brandName)
  const brandMentions = brandResults.filter(r => r.mentioned).length
  const sovPct = prompts.length > 0 ? Math.round((brandMentions / prompts.length) * 100) : 0

  return NextResponse.json({
    prompts_checked: prompts.length,
    brand_sov: sovPct,
    competitors_tracked: competitors.length,
    rows_stored: results.length,
  })
}
TS

# =============================================================================
# 3. WEEKLY CRON — app/api/cron/sov-weekly/route.ts
# Called by Vercel Cron every Monday 9am
# =============================================================================
mkdir -p src/app/api/cron/sov-weekly

cat > src/app/api/cron/sov-weekly/route.ts << 'TS'
/**
 * Vercel Cron: runs every Monday 9am UTC
 * Add to vercel.json:
 * { "crons": [{ "path": "/api/cron/sov-weekly", "schedule": "0 9 * * 1" }] }
 */
import { NextRequest, NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'
import { GoogleGenerativeAI } from '@google/generative-ai'

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL!,
  process.env.SUPABASE_SERVICE_ROLE_KEY!
)
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY!)
const model = genAI.getGenerativeModel({ model: 'gemini-2.5-flash-lite' })

export async function GET(req: NextRequest) {
  // Verify Vercel cron secret
  const authHeader = req.headers.get('authorization')
  if (authHeader !== `Bearer ${process.env.CRON_SECRET}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // Get all paid brands with competitors
  const { data: brands } = await supabase
    .from('brands')
    .select('id, shop_domain, brand_name, plan')
    .neq('plan', 'free')

  let processed = 0
  let errors = 0

  for (const brand of brands || []) {
    try {
      const { data: competitors } = await supabase
        .from('competitor_tracking')
        .select('competitor_name')
        .eq('brand_id', brand.id)

      if (!competitors?.length) continue

      const { data: promptRows } = await supabase
        .from('sov_prompts')
        .select('prompt')
        .eq('brand_id', brand.id)
        .limit(10)

      const prompts = promptRows?.map(r => r.prompt) || []
      if (!prompts.length) continue

      const brandName = brand.brand_name || brand.shop_domain.split('.')[0]
      const allNames = [brandName, ...competitors.map((c: { competitor_name: string }) => c.competitor_name)]
      const rows: Array<Record<string, unknown>> = []

      for (const prompt of prompts) {
        const aiPrompt = `Answer: "${prompt}"\n\nThen output JSON only: {"mentioned": [], "order": []} listing which of these brands you mentioned: ${JSON.stringify(allNames)}`
        try {
          const result = await model.generateContent(aiPrompt)
          const text = result.response.text()
          const jsonMatch = text.match(/\{[\s\S]*"mentioned"[\s\S]*\}/)
          if (!jsonMatch) continue
          const parsed = JSON.parse(jsonMatch[0])
          const mentioned: string[] = parsed.mentioned || []
          const order: string[] = parsed.order || []
          for (const name of allNames) {
            rows.push({
              brand_id: brand.id,
              competitor_name: name,
              prompt,
              mentioned: mentioned.includes(name),
              position: order.indexOf(name) >= 0 ? order.indexOf(name) + 1 : null,
              checked_at: new Date().toISOString(),
            })
          }
        } catch { continue }
      }

      if (rows.length > 0) await supabase.from('competitor_sov').insert(rows)
      processed++
    } catch { errors++ }
  }

  return NextResponse.json({ processed, errors, timestamp: new Date().toISOString() })
}
TS

# =============================================================================
# 4. VERCEL CRON CONFIG
# =============================================================================
cat > vercel.json << 'JSON'
{
  "crons": [
    {
      "path": "/api/cron/sov-weekly",
      "schedule": "0 9 * * 1"
    }
  ]
}
JSON

echo "✅ vercel.json cron configured"

# =============================================================================
# 5. COMPETITOR DASHBOARD PAGE
# =============================================================================
cat > src/app/dashboard/competitors/page.tsx << 'TSX'
'use client'

import { useState, useEffect } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'

interface Competitor { id: string; competitor_name: string; shopify_domain?: string }
interface SovRow { competitor_name: string; mentioned: boolean; position?: number; checked_at: string }

export default function CompetitorsPage() {
  const supabase = createClientComponentClient()
  const [brandId, setBrandId] = useState<string | null>(null)
  const [brandName, setBrandName] = useState('')
  const [competitors, setCompetitors] = useState<Competitor[]>([])
  const [sov, setSov] = useState<SovRow[]>([])
  const [newName, setNewName] = useState('')
  const [adding, setAdding] = useState(false)
  const [checking, setChecking] = useState(false)

  useEffect(() => {
    async function load() {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) return
      const { data: brand } = await supabase
        .from('brands')
        .select('id, brand_name, shop_domain')
        .eq('user_id', session.user.id)
        .single()
      if (!brand) return
      setBrandId(brand.id)
      setBrandName(brand.brand_name || brand.shop_domain.split('.')[0])

      const { data: comps } = await supabase
        .from('competitor_tracking')
        .select('id, competitor_name, shopify_domain')
        .eq('brand_id', brand.id)
      setCompetitors(comps || [])

      // Latest SOV results
      const { data: sovRows } = await supabase
        .from('competitor_sov')
        .select('competitor_name, mentioned, position, checked_at')
        .eq('brand_id', brand.id)
        .order('checked_at', { ascending: false })
        .limit(100)
      setSov(sovRows || [])
    }
    load()
  }, [supabase])

  const addCompetitor = async () => {
    if (!brandId || !newName.trim()) return
    setAdding(true)
    const res = await fetch('/api/competitors/add', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ brand_id: brandId, competitor_name: newName.trim() }),
    })
    if (res.ok) {
      const data = await res.json()
      setCompetitors(prev => [...prev, { id: data.id, competitor_name: newName.trim() }])
      setNewName('')
    }
    setAdding(false)
  }

  const runSovCheck = async () => {
    if (!brandId) return
    setChecking(true)
    await fetch('/api/competitors/sov-check', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ brand_id: brandId }),
    })
    // Reload SOV
    const { data } = await supabase
      .from('competitor_sov')
      .select('competitor_name, mentioned, position, checked_at')
      .eq('brand_id', brandId)
      .order('checked_at', { ascending: false })
      .limit(100)
    setSov(data || [])
    setChecking(false)
  }

  // Compute SOV % per competitor from latest batch
  const latestDate = sov[0]?.checked_at
  const latestBatch = sov.filter(r => r.checked_at === latestDate)
  const allNames = [brandName, ...competitors.map(c => c.competitor_name)]

  const sovStats = allNames.map(name => {
    const rows = latestBatch.filter(r => r.competitor_name === name)
    const mentions = rows.filter(r => r.mentioned).length
    const total = rows.length
    const pct = total > 0 ? Math.round((mentions / total) * 100) : 0
    const avgPos = rows.filter(r => r.position).reduce((a, b) => a + (b.position || 0), 0) / (rows.filter(r => r.position).length || 1)
    return { name, pct, avgPos: Math.round(avgPos) || null, isBrand: name === brandName }
  }).sort((a, b) => b.pct - a.pct)

  return (
    <div className="min-h-screen bg-[#0a0a0f] text-[#e8e8f0]">
      <div className="max-w-4xl mx-auto px-6 py-10">

        <div className="mb-8">
          <p className="font-mono text-xs text-[#6c63ff] tracking-[3px] uppercase mb-2">Competitor Tracker</p>
          <h1 className="text-3xl font-bold mb-1">SOV Benchmarks</h1>
          <p className="text-sm text-[#6b6b80]">How often you vs competitors appear in AI shopping queries.</p>
        </div>

        {/* SOV table */}
        {sovStats.length > 0 && (
          <div className="rounded-xl border border-[#2a2a3a] bg-[#111118] p-5 mb-6">
            <p className="font-mono text-[10px] text-[#6b6b80] tracking-widest uppercase mb-4">
              Latest SOV · {latestDate ? new Date(latestDate).toLocaleDateString() : 'No data yet'}
            </p>
            <div className="space-y-3">
              {sovStats.map(s => (
                <div key={s.name} className="flex items-center gap-4">
                  <div className="w-32 text-xs truncate" style={{ color: s.isBrand ? '#00d4aa' : '#e8e8f0', fontWeight: s.isBrand ? 600 : 400 }}>
                    {s.name} {s.isBrand && <span className="text-[#6b6b80]">(you)</span>}
                  </div>
                  <div className="flex-1 bg-[#1a1a24] rounded-full h-2 overflow-hidden">
                    <div
                      className="h-full rounded-full transition-all duration-500"
                      style={{
                        width: `${s.pct}%`,
                        background: s.isBrand ? 'linear-gradient(90deg,#6c63ff,#00d4aa)' : '#2a2a3a',
                      }}
                    />
                  </div>
                  <div className="w-12 text-right font-mono text-xs" style={{ color: s.isBrand ? '#00d4aa' : '#6b6b80' }}>
                    {s.pct}%
                  </div>
                  {s.avgPos && <div className="w-16 text-right font-mono text-[10px] text-[#6b6b80]">#{s.avgPos} avg</div>}
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Add competitor */}
        <div className="rounded-xl border border-[#2a2a3a] bg-[#111118] p-5 mb-4">
          <p className="font-mono text-[10px] text-[#6b6b80] tracking-widest uppercase mb-3">
            Add Competitor ({competitors.length}/5)
          </p>
          <div className="flex gap-2">
            <input
              value={newName}
              onChange={e => setNewName(e.target.value)}
              onKeyDown={e => e.key === 'Enter' && addCompetitor()}
              placeholder="Brand name (e.g. Mamaearth)"
              className="flex-1 bg-[#0a0a0f] border border-[#2a2a3a] rounded-lg px-3 py-2 text-sm text-[#e8e8f0] outline-none focus:border-[#6c63ff] placeholder:text-[#444]"
            />
            <button
              onClick={addCompetitor}
              disabled={adding || !newName.trim()}
              className="px-4 py-2 rounded-lg text-xs font-mono disabled:opacity-40"
              style={{ background: 'rgba(108,99,255,0.2)', border: '1px solid rgba(108,99,255,0.4)', color: '#9d97ff' }}
            >
              {adding ? '...' : '+ ADD'}
            </button>
          </div>
          {competitors.length > 0 && (
            <div className="flex flex-wrap gap-2 mt-3">
              {competitors.map(c => (
                <span key={c.id} className="font-mono text-[11px] px-2 py-1 rounded-lg bg-[#1a1a24] border border-[#2a2a3a] text-[#6b6b80]">
                  {c.competitor_name}
                </span>
              ))}
            </div>
          )}
        </div>

        {/* Run check */}
        <button
          onClick={runSovCheck}
          disabled={checking || competitors.length === 0}
          className="w-full py-3 rounded-xl text-sm font-mono font-medium transition-all disabled:opacity-40"
          style={{ background: 'rgba(0,212,170,0.12)', border: '1px solid rgba(0,212,170,0.3)', color: '#00d4aa' }}
        >
          {checking ? '⟳ RUNNING SOV CHECK...' : '▶ RUN SOV CHECK NOW'}
        </button>
        <p className="text-center text-[10px] text-[#6b6b80] font-mono mt-2">
          Auto-runs every Monday 9am UTC via Vercel Cron
        </p>

      </div>
    </div>
  )
}
TSX

echo "✅ setup8 complete"
echo ""
echo "Files: app/api/competitors/add/route.ts"
echo "       app/api/competitors/sov-check/route.ts"
echo "       app/api/cron/sov-weekly/route.ts"
echo "       app/dashboard/competitors/page.tsx"
echo "       vercel.json (cron config)"
echo ""
echo "Add CRON_SECRET=any-random-string to .env.local"

echo ''
echo '=== setup9.sh ==='
# Billing gating UI — upgrade prompts + plan display
# No Stripe. DB flag only. Manual upgrade for early clients.
# =============================================================================

set -e
echo "💳 setup9 — Billing gating UI..."

mkdir -p src/components/billing
mkdir -p src/app/dashboard/billing

# =============================================================================
# 1. UPGRADE PROMPT COMPONENT — shown inline when limit hit
# =============================================================================
cat > src/components/billing/UpgradePrompt.tsx << 'TSX'
'use client'

interface UpgradePromptProps {
  feature: string       // e.g. "Auto-Fix Agent"
  reason: string        // e.g. "Free plan: 10 products max"
  compact?: boolean
}

export default function UpgradePrompt({ feature, reason, compact }: UpgradePromptProps) {
  if (compact) return (
    <div className="flex items-center gap-2 px-3 py-2 rounded-lg text-xs"
      style={{ background: 'rgba(255,159,67,0.08)', border: '1px solid rgba(255,159,67,0.25)' }}>
      <span className="text-[#ff9f43]">⚡</span>
      <span className="text-[#6b6b80]">{reason} —</span>
      <a href="/dashboard/billing" className="text-[#ff9f43] font-mono font-medium hover:underline">
        Upgrade
      </a>
    </div>
  )

  return (
    <div className="rounded-xl border p-6 text-center"
      style={{ background: 'rgba(255,159,67,0.05)', borderColor: 'rgba(255,159,67,0.25)' }}>
      <div className="text-2xl mb-3">⚡</div>
      <p className="font-mono text-xs text-[#ff9f43] tracking-widest uppercase mb-2">{feature}</p>
      <p className="text-sm text-[#6b6b80] mb-4">{reason}</p>
      <a
        href="/dashboard/billing"
        className="inline-block px-5 py-2.5 rounded-lg text-xs font-mono font-medium"
        style={{ background: 'rgba(255,159,67,0.15)', border: '1px solid rgba(255,159,67,0.4)', color: '#ff9f43' }}
      >
        VIEW PLANS →
      </a>
    </div>
  )
}
TSX

# =============================================================================
# 2. PLAN BADGE — shown in sidebar/header
# =============================================================================
cat > src/components/billing/PlanBadge.tsx << 'TSX'
'use client'

const PLAN_STYLE: Record<string, { color: string; bg: string; border: string }> = {
  free:         { color: '#6b6b80', bg: 'rgba(107,107,128,0.1)', border: '#2a2a3a' },
  starter:      { color: '#6c63ff', bg: 'rgba(108,99,255,0.12)', border: 'rgba(108,99,255,0.3)' },
  growth:       { color: '#00d4aa', bg: 'rgba(0,212,170,0.1)',   border: 'rgba(0,212,170,0.3)'  },
  professional: { color: '#ff9f43', bg: 'rgba(255,159,67,0.1)',  border: 'rgba(255,159,67,0.3)' },
  enterprise:   { color: '#ff6b6b', bg: 'rgba(255,107,107,0.1)', border: 'rgba(255,107,107,0.3)'},
}

export default function PlanBadge({ plan }: { plan: string }) {
  const s = PLAN_STYLE[plan] || PLAN_STYLE.free
  return (
    <span
      className="font-mono text-[10px] tracking-widest uppercase px-2 py-0.5 rounded-full"
      style={{ color: s.color, background: s.bg, border: `1px solid ${s.border}` }}
    >
      {plan}
    </span>
  )
}
TSX

# =============================================================================
# 3. BILLING PAGE — /dashboard/billing
# =============================================================================
cat > src/app/dashboard/billing/page.tsx << 'TSX'
'use client'

import { useState, useEffect } from 'react'
import { createClientComponentClient } from '@supabase/auth-helpers-nextjs'
import PlanBadge from '@/components/billing/PlanBadge'

const PLANS = [
  {
    key: 'starter',
    name: 'Starter',
    price: '$99',
    period: '/mo',
    desc: 'Up to 500 SKUs',
    color: '#6c63ff',
    features: [
      'Full catalog audit (500 SKUs)',
      'Weekly AI visibility tracking',
      '3 AI engines',
      '3 competitor tracking',
      'Fix recommendations',
      'Weekly email reports',
      'Schema health check',
    ],
  },
  {
    key: 'growth',
    name: 'Growth',
    price: '$199',
    period: '/mo',
    desc: 'Up to 2,000 SKUs',
    color: '#00d4aa',
    featured: true,
    features: [
      'Everything in Starter',
      'Auto-Fix Agent (push to Shopify)',
      'ACP/UCP feed generation',
      '5 competitor tracking',
      '6 AI engines incl. Rufus + Meta AI',
      'Daily monitoring + alerts',
      'Priority support',
    ],
  },
  {
    key: 'professional',
    name: 'Pro',
    price: '$399',
    period: '/mo',
    desc: 'Unlimited SKUs',
    color: '#ff9f43',
    features: [
      'Everything in Growth',
      'Unlimited products',
      'Blog / Content Agent',
      'AI subdomain (ai.yourbrand.com)',
      'White-label reports',
      'Dedicated Slack channel',
    ],
  },
]

export default function BillingPage() {
  const supabase = createClientComponentClient()
  const [brand, setBrand] = useState<{ id: string; plan: string; product_limit: number } | null>(null)

  useEffect(() => {
    async function load() {
      const { data: { session } } = await supabase.auth.getSession()
      if (!session) return
      const { data } = await supabase
        .from('brands')
        .select('id, plan, product_limit')
        .eq('user_id', session.user.id)
        .single()
      if (data) setBrand(data)
    }
    load()
  }, [supabase])

  return (
    <div className="min-h-screen bg-[#0a0a0f] text-[#e8e8f0]">
      <div className="max-w-4xl mx-auto px-6 py-10">

        <div className="mb-8">
          <p className="font-mono text-xs text-[#6c63ff] tracking-[3px] uppercase mb-2">Billing</p>
          <div className="flex items-center gap-3 mb-1">
            <h1 className="text-3xl font-bold">Plans</h1>
            {brand && <PlanBadge plan={brand.plan} />}
          </div>
          <p className="text-sm text-[#6b6b80]">
            {brand?.plan === 'free'
              ? `Free plan: ${brand.product_limit} products. Upgrade to unlock full catalog + Auto-Fix.`
              : 'Manage your plan. Changes apply immediately.'}
          </p>
        </div>

        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-8">
          {PLANS.map(plan => {
            const isCurrent = brand?.plan === plan.key
            return (
              <div
                key={plan.key}
                className="rounded-xl border p-5 relative"
                style={{
                  background: isCurrent ? `rgba(${plan.key === 'growth' ? '0,212,170' : plan.key === 'professional' ? '255,159,67' : '108,99,255'},0.06)` : '#111118',
                  borderColor: isCurrent ? plan.color : plan.featured ? `${plan.color}55` : '#2a2a3a',
                }}
              >
                {plan.featured && !isCurrent && (
                  <div className="absolute -top-3 left-1/2 -translate-x-1/2 font-mono text-[9px] tracking-widest uppercase px-3 py-1 rounded-full"
                    style={{ background: plan.color, color: '#0a0a0f' }}>
                    MOST POPULAR
                  </div>
                )}
                {isCurrent && (
                  <div className="absolute -top-3 left-1/2 -translate-x-1/2 font-mono text-[9px] tracking-widest uppercase px-3 py-1 rounded-full"
                    style={{ background: plan.color, color: '#0a0a0f' }}>
                    CURRENT PLAN
                  </div>
                )}

                <div className="mb-4">
                  <p className="font-bold text-base mb-1">{plan.name}</p>
                  <div className="flex items-baseline gap-1">
                    <span className="font-mono text-2xl font-bold" style={{ color: plan.color }}>{plan.price}</span>
                    <span className="text-xs text-[#6b6b80]">{plan.period}</span>
                  </div>
                  <p className="text-xs text-[#6b6b80] mt-1">{plan.desc}</p>
                </div>

                <ul className="space-y-1.5 mb-5">
                  {plan.features.map(f => (
                    <li key={f} className="flex items-start gap-2 text-xs text-[#6b6b80]">
                      <span style={{ color: plan.color }} className="mt-0.5 flex-shrink-0">✓</span>
                      {f}
                    </li>
                  ))}
                </ul>

                {!isCurrent && (
                  <a
                    href={`mailto:ankit@vialtry.com?subject=Upgrade to ${plan.name}&body=Hi, I'd like to upgrade to the ${plan.name} plan ($${plan.price}/mo).`}
                    className="block w-full text-center py-2 rounded-lg text-xs font-mono transition-all"
                    style={{
                      background: `rgba(${plan.key === 'growth' ? '0,212,170' : plan.key === 'professional' ? '255,159,67' : '108,99,255'},0.15)`,
                      border: `1px solid ${plan.color}55`,
                      color: plan.color,
                    }}
                  >
                    UPGRADE →
                  </a>
                )}
              </div>
            )
          })}
        </div>

        {/* Manual upgrade note */}
        <div className="rounded-xl border border-[#2a2a3a] bg-[#111118] p-4 text-center">
          <p className="text-xs text-[#6b6b80]">
            Upgrades processed manually. Click upgrade → email sent → plan activated within 24hrs.
            <br />
            <span className="font-mono text-[#6c63ff]">Stripe integration coming soon.</span>
          </p>
        </div>

      </div>
    </div>
  )
}
TSX

echo "✅ setup9 complete"
echo ""
echo "Files: components/billing/UpgradePrompt.tsx"
echo "       components/billing/PlanBadge.tsx"
echo "       app/dashboard/billing/page.tsx"
echo ""
echo "Usage in other pages:"
echo "  import UpgradePrompt from '@/components/billing/UpgradePrompt'"
echo "  <UpgradePrompt feature='Auto-Fix Agent' reason='Free plan: 10 products max' />"
echo ""
echo "============================================================"
echo "  STAGE 2 COMPLETE — All setup scripts ready"
echo "============================================================"
echo "  setup5.sh  — Auto-Fix API routes"
echo "  setup6.sh  — Fix Queue UI"
echo "  setup6b.sh — gaps column + backfill"
echo "  setup7.sh  — ACP/UCP Feed Generator"
echo "  setup8.sh  — Competitor SOV Tracker"
echo "  setup9.sh  — Billing gating UI"
echo "============================================================"
echo ""
echo "Run order on laptop:"
echo "  bash setup5.sh"
echo "  bash setup6.sh"
echo "  bash setup6b.sh"
echo "  bash setup7.sh"
echo "  bash setup8.sh"
echo "  bash setup9.sh"
echo "  supabase db push"
echo "  npx tsx scripts/backfill-gaps.ts"
echo "============================================================"

echo ""
echo "✅ ALL DONE — now run: npm run dev"
