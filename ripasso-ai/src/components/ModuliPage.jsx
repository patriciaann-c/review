import { useState } from 'react'
import ReactMarkdown from 'react-markdown'
import remarkGfm from 'remark-gfm'
import { useModuli } from '../hooks/useModuli'

const EMOJI = {
  '01': '🧱',
  '02': '🎨',
  '03': '⚡',
  '04': '⚛️',
  '05': '🟢',
  '06': '🗄️',
  '07': '🚏',
  '08': '🔷',
  '09': '🦜',
  10: '🤖',
}

const nomeBreve = (titolo) => titolo.replace(/^Modulo\s+\d+\s*[—–-]\s*/i, '')

// Pagina moduli: indice dei 10 moduli e contenuto Markdown del modulo scelto.
export default function ModuliPage() {
  const moduli = useModuli()
  const [slug, setSlug] = useState(moduli[0]?.slug)
  const attivo = moduli.find((m) => m.slug === slug) || moduli[0]
  if (!attivo) return <div className="alert alert-info">Nessun modulo disponibile.</div>

  const numero = attivo.slug.slice(0, 2)
  const titolo = nomeBreve(attivo.titolo)
  const parole = attivo.testo.trim().split(/\s+/).length

  function apri(nuovoSlug) {
    setSlug(nuovoSlug)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }

  return (
    <>
      <section className="rai-page-hero rai-page-hero-moduli">
        <div className="rai-hero-copy">
          <span className="rai-eyebrow">📖 Materiale del corso</span>
          <h1 className="rai-hero-title">I moduli, spiegati con calma</h1>
          <p className="rai-hero-text">
            Tutto il programma in un posto: leggi, sottolinea e torna quando ti serve.
          </p>
          <div className="rai-hero-stats">
            <span className="rai-stat"><strong>{moduli.length}</strong> moduli</span>
            <span className="rai-stat"><strong>teoria</strong> + esercizi</span>
            <span className="rai-stat"><strong>checklist</strong> finale</span>
          </div>
        </div>
        <div className="rai-hero-art" aria-hidden="true">
          <span className="rai-hero-art-main">📚</span>
          <span className="rai-hero-art-spark">💡</span>
        </div>
      </section>

      <div className="row g-4">
        <aside className="col-lg-4 col-xl-3">
          <div className="rai-panel rai-topic-panel">
            <p className="rai-list-title">Scegli un modulo</p>
            <div className="rai-topic-list rai-module-list">
              {moduli.map((m) => {
                const num = m.slug.slice(0, 2)
                return (
                  <button
                    key={m.slug}
                    type="button"
                    aria-pressed={m.slug === attivo.slug}
                    className={`rai-topic rai-module ${m.slug === attivo.slug ? 'active' : ''}`}
                    onClick={() => apri(m.slug)}
                  >
                    <span className="rai-topic-emoji" aria-hidden="true">{EMOJI[num] || '📘'}</span>
                    <span className="rai-topic-body">
                      <span className="rai-topic-name">{nomeBreve(m.titolo)}</span>
                      <span className="rai-topic-meta">Modulo {num}</span>
                    </span>
                  </button>
                )
              })}
            </div>
          </div>
        </aside>

        <article className="col-lg-8 col-xl-9">
          <div className="rai-reader">
            <header className="rai-reader-head">
              <span className="rai-reader-emoji" aria-hidden="true">{EMOJI[numero] || '📘'}</span>
              <div className="rai-reader-titles">
                <p className="rai-eyebrow mb-1">Modulo {numero}</p>
                <h2 className="rai-reader-title">{titolo}</h2>
              </div>
              <span className="rai-chip">≈ {parole.toLocaleString('it-IT')} parole</span>
            </header>
            <div className="markdown-body">
              <ReactMarkdown remarkPlugins={[remarkGfm]}>{attivo.testo}</ReactMarkdown>
            </div>
          </div>
        </article>
      </div>
    </>
  )
}
