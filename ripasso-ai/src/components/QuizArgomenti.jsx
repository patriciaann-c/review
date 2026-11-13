import { useMemo, useState } from 'react'
import QuizRunner from './QuizRunner'
import { useArgomenti } from '../hooks/useArgomenti'

const EMOJI = {
  html: '🧱',
  css: '🎨',
  javascript: '⚡',
  react: '⚛️',
  nodejs: '🟢',
  mysql: '🗄️',
  express: '🚏',
  prisma: '🔷',
  langchain: '🦜',
  'agenti-ai': '🤖',
  autenticazione: '🔐',
}

// Pagina dei quiz: elenco ricercabile degli argomenti e quiz da svolgere.
export default function QuizArgomenti() {
  const { argomenti, caricamento, errore } = useArgomenti()
  const [scelto, setScelto] = useState(null)
  const [cerca, setCerca] = useState('')

  const totaleDomande = useMemo(
    () => argomenti.reduce((somma, a) => somma + a.domande, 0),
    [argomenti],
  )

  const visibili = useMemo(() => {
    const q = cerca.trim().toLowerCase()
    if (!q) return argomenti
    return argomenti.filter((a) =>
      `${a.nome} ${a.modulo}`.toLowerCase().includes(q),
    )
  }, [argomenti, cerca])

  if (caricamento) {
    return (
      <div className="rai-spinner-wrap">
        <div className="spinner-border text-primary" role="status" />
        <p className="mb-0 small">Carichiamo gli argomenti…</p>
      </div>
    )
  }
  if (errore) return <div className="alert alert-danger">{errore}</div>

  const attivo = argomenti.find((a) => a.id === scelto) || argomenti[0]
  if (!attivo) return <div className="alert alert-info">Nessun argomento disponibile.</div>

  return (
    <>
      <section className="rai-page-hero">
        <div className="rai-hero-copy">
          <span className="rai-eyebrow">🎯 Allenamento</span>
          <h1 className="rai-hero-title">Quiz per argomento</h1>
          <p className="rai-hero-text">
            Scegli un tema, rispondi con calma e scopri subito cosa vale la pena ripassare.
          </p>
          <div className="rai-hero-stats">
            <span className="rai-stat"><strong>{argomenti.length}</strong> argomenti</span>
            <span className="rai-stat"><strong>{totaleDomande}</strong> domande</span>
            <span className="rai-stat"><strong>4</strong> livelli</span>
          </div>
        </div>
        <div className="rai-hero-art" aria-hidden="true">
          <span className="rai-hero-art-main">🧠</span>
          <span className="rai-hero-art-spark">✨</span>
        </div>
      </section>

      <div className="row g-4">
        <aside className="col-lg-4 col-xl-3">
          <div className="rai-panel rai-topic-panel">
            <label className="form-label rai-search-label" htmlFor="cerca-argomento">
              Cerca un argomento
            </label>
            <div className="rai-search-wrap">
              <span aria-hidden="true">🔎</span>
              <input
                id="cerca-argomento"
                type="search"
                className="form-control rai-search"
                placeholder="Es. JavaScript"
                value={cerca}
                onChange={(e) => setCerca(e.target.value)}
              />
            </div>

            <div className="rai-topic-list">
              {visibili.map((a) => (
                <button
                  key={a.id}
                  type="button"
                  title={a.modulo}
                  aria-pressed={a.id === attivo.id}
                  className={`rai-topic ${a.id === attivo.id ? 'active' : ''}`}
                  onClick={() => setScelto(a.id)}
                >
                  <span className="rai-topic-emoji" aria-hidden="true">
                    {EMOJI[a.slug] || '📘'}
                  </span>
                  <span className="rai-topic-body">
                    <span className="rai-topic-name">{a.nome}</span>
                    <span className="rai-topic-meta">{a.modulo}</span>
                  </span>
                  <span className="rai-topic-count">{a.domande}</span>
                </button>
              ))}
            </div>

            {visibili.length === 0 && (
              <p className="rai-empty-small mb-0">Nessun argomento trovato per “{cerca}”.</p>
            )}
          </div>
        </aside>

        <div className="col-lg-8 col-xl-9">
          <QuizRunner key={attivo.id} argomentoId={attivo.id} titolo={attivo.nome} />
        </div>
      </div>
    </>
  )
}
