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
