import { createClient } from '@supabase/supabase-js'

// Client unico dell'app. Solo chiavi pubbliche (anon/publishable): mai la service_role.
const url = import.meta.env.VITE_SUPABASE_URL
const key = import.meta.env.VITE_SUPABASE_ANON_KEY

export const isSupabaseConfigured = Boolean(url && key)
export const supabase = isSupabaseConfigured ? createClient(url, key) : null
