import { lazy, Suspense, useEffect, useState } from 'react'
import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import LoginForm from './components/LoginForm'
import QuizArgomenti from './components/QuizArgomenti'
import MainLayout from './layouts/MainLayout'
import { isSupabaseConfigured, supabase } from './lib/supabase'

// La pagina moduli (markdown + 10 file) si carica solo quando serve.
const ModuliPage = lazy(() => import('./components/ModuliPage'))

// Radice dell'app: sessione Supabase e rotte protette.
export default function App() {
  // undefined = sessione in caricamento, null = ospite.
  const [sessione, setSessione] = useState(undefined)

  useEffect(() => {
    if (!supabase) return
    supabase.auth.getSession().then(({ data }) => setSessione(data.session))
    const { data: sub } = supabase.auth.onAuthStateChange((_evento, nuova) => setSessione(nuova))
    return () => sub.subscription.unsubscribe()
  }, [])

  if (!isSupabaseConfigured) {
    return (
      <div className="container py-5">
        <div className="alert alert-warning mb-0">
          Configura <code>VITE_SUPABASE_URL</code> e <code>VITE_SUPABASE_ANON_KEY</code> in <code>.env.local</code>.
        </div>
      </div>
    )
  }

  if (sessione === undefined) {
    return (
      <div className="rai-spinner-wrap" style={{ minHeight: '100vh' }}>
        <div className="spinner-border text-primary" role="status"><span className="visually-hidden">Caricamento…</span></div>
        <p className="mb-0 small">Prepariamo il tuo ripasso…</p>
      </div>
    )
  }

  if (!sessione) return <LoginForm />

  return (
    <BrowserRouter>
      <Routes>
        <Route element={<MainLayout utente={sessione.user} onEsci={() => supabase.auth.signOut()} />}>
          <Route index element={<Navigate to="/quiz" replace />} />
          <Route path="quiz" element={<QuizArgomenti />} />
          <Route path="moduli" element={
            <Suspense fallback={<div className="text-center py-5"><div className="spinner-border text-primary" role="status" /></div>}>
              <ModuliPage />
            </Suspense>
          } />
          <Route path="*" element={<Navigate to="/quiz" replace />} />
        </Route>
      </Routes>
    </BrowserRouter>
  )
}
