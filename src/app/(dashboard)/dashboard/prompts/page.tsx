'use client'

import { useState, useEffect } from 'react'
import { createClient } from '@/lib/supabase/client'

interface Prompt {
  id: string
  prompt_text: string
  category: string
  is_active: boolean
  created_at: string 
}

export default function PromptsPage() {
  const [prompts, setPrompts] = useState<Prompt[]>([])
  const [newPrompt, setNewPrompt] = useState('')
  const [category, setCategory] = useState('general')
  const [loading, setLoading] = useState(false)
  const [saving, setSaving] = useState(false)

  const supabase = createClient()

  useEffect(() => {
    fetchPrompts()
  }, [])

  async function fetchPrompts() {
    setLoading(true)
    const { data } = await supabase
      .from('user_prompts')
      .select('*')
      .eq('is_active', true)
      .order('created_at', { ascending: false })
    if (data) setPrompts(data)
    setLoading(false)
  }

  async function addPrompt() {
    if (!newPrompt.trim()) return
    setSaving(true)
    const { data: brand } = await supabase
      .from('brands')
      .select('id')
      .limit(1)
      .single()

    await supabase.from('user_prompts').insert({
      brand_id: brand?.id,
      prompt_text: newPrompt.trim(),
      category,
      is_active: true
    })
    setNewPrompt('')
    await fetchPrompts()
    setSaving(false)
  }

  async function deletePrompt(id: string) {
    await supabase
      .from('user_prompts')
      .update({ is_active: false })
      .eq('id', id)
    await fetchPrompts()
  }

  const categories = ['general', 'product', 'category', 'brand', 'comparison']

  return (
    <div className="p-6 max-w-4xl">
      <h1 className="text-2xl font-bold text-white mb-2">SOV Prompts</h1>
      <p className="text-gray-400 mb-6">
        Manage prompts used to check your AI visibility.
        Runs automatically at low-traffic hours.
      </p>

      <div className="bg-gray-900 rounded-xl p-4 mb-6 border border-gray-800">
        <h2 className="text-white font-semibold mb-3">Add Prompt</h2>
        <div className="flex gap-3 mb-3">
          <input
            type="text"
            value={newPrompt}
            onChange={(e) => setNewPrompt(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && addPrompt()}
            placeholder="e.g. best running shoes under $100"
            className="flex-1 bg-gray-800 text-white rounded-lg px-4 py-2 border border-gray-700 focus:border-purple-500 focus:outline-none placeholder-gray-500"
          />
          <select
            value={category}
            onChange={(e) => setCategory(e.target.value)}
            className="bg-gray-800 text-white rounded-lg px-3 py-2 border border-gray-700 focus:outline-none"
          >
            {categories.map((cat) => (
              <option key={cat} value={cat}>
                {cat.charAt(0).toUpperCase() + cat.slice(1)}
              </option>
            ))}
          </select>
          <button
            onClick={addPrompt}
            disabled={saving || !newPrompt.trim()}
            className="bg-purple-600 hover:bg-purple-700 disabled:opacity-50 text-white px-4 py-2 rounded-lg font-medium transition"
          >
            {saving ? 'Saving...' : 'Add'}
          </button>
        </div>
      </div>

      <div className="space-y-2">
        {loading ? (
          <p className="text-gray-400">Loading prompts...</p>
        ) : prompts.length === 0 ? (
          <div className="bg-gray-900 rounded-xl p-8 border border-gray-800 text-center">
            <p className="text-gray-400">No prompts yet. Add your first prompt above.</p>
          </div>
        ) : (
          prompts.map((prompt) => (
            <div
              key={prompt.id}
              className="bg-gray-900 rounded-xl px-4 py-3 border border-gray-800 flex items-center justify-between group"
            >
              <div>
                <p className="text-white">{prompt.prompt_text}</p>
                <span className="text-xs text-gray-500 capitalize">{prompt.category}</span>
              </div>
              <button
                onClick={() => deletePrompt(prompt.id)}
                className="text-gray-600 hover:text-red-400 transition opacity-0 group-hover:opacity-100 text-sm"
              >
                Remove
              </button>
            </div>
          ))
        )}
      </div>

      {prompts.length > 0 && (
        <p className="text-gray-500 text-sm mt-4">
          {prompts.length} prompt{prompts.length > 1 ? 's' : ''} · Next run scheduled at 2:00 AM
        </p>
      )}
    </div>
  )
}
