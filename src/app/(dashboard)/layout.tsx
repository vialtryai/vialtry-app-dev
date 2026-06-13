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
          <Link href="/dashboard/prompts" className="flex items-center gap-2.5 px-3 py-2 rounded-lg text-gray-400 hover:text-white hover:bg-gray-800 transition-colors text-sm">⊛ SOV Prompts</Link>          <Link href="/dashboard/recommendations" className="flex items-center gap-2.5 px-3 py-2 rounded-lg text-gray-400 hover:text-white hover:bg-gray-800 transition-colors text-sm">⚡ Fix Queue</Link>
          <div className="flex items-center gap-2.5 px-3 py-2 rounded-lg text-gray-600 text-sm cursor-not-allowed">⊘ Competitors<span className="ml-auto text-xs bg-gray-800 text-gray-600 px-1.5 py-0.5 rounded">soon</span></div>
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
