import { useState } from 'react'
import { useQuiz } from '../hooks/useQuiz'

const LIVELLI = {
  L1: { label: 'Base', emoji: '🌱' },
  L2: { label: 'Intermedio', emoji: '🌿' },
  L3: { label: 'Avanzato', emoji: '🌳' },
  L4: { label: 'Esperto', emoji: '🏆' },
}

function messaggioRisultato(percentuale) {
  if (percentuale >= 90) return { emoji: '🏆', titolo: 'Bravissimo!', testo: 'Padroneggi questo argomento: ora puoi passare al livello successivo.' }
  if (percentuale >= 75) return { emoji: '🌟', titolo: 'Ottimo lavoro!', testo: 'Ci sei quasi: rivedi le risposte sbagliate e riprova.' }
  if (percentuale >= 50) return { emoji: '💪', titolo: 'Buona base!', testo: 'Rivedi i concetti segnati e fai un altro giro: migliorerai in fretta.' }
  return { emoji: '📚', titolo: 'Da ripassare', testo: 'Nessun problema: leggi le spiegazioni e riprova con calma.' }
}

// Quiz di un argomento: una domanda alla volta, punteggio e revisione.
export default function QuizRunner({ argomentoId, titolo }) {
  const { domande, risposte, rispondi, invia, azzera, risultato, caricamento, invio, errore } = useQuiz({ argomentoId })
  const [indice, setIndice] = useState(0)

  if (caricamento) {
    return (
      <div className="rai-panel rai-quiz-skeleton">
        <div className="spinner-border spinner-border-sm text-primary me-2" role="status" />
        <span>Preparo le domande…</span>
      </div>
    )
  }

  if (domande.length === 0) {
    return (
      <div className="rai-panel rai-empty">
        <span className="rai-empty-emoji" aria-hidden="true">🫥</span>
        <p className="mb-0">Non ci sono ancora domande per questo argomento.</p>
      </div>
    )
  }

  const totale = domande.length
  const risposteDate = Object.keys(risposte).length
  const avanzamento = Math.round((risposteDate / totale) * 100)

  if (risultato) {
    const percentuale = Math.round(Number(risultato.punteggio) || 0)
    const messaggio = messaggioRisultato(percentuale)
    const dettagli = new Map((risultato.dettagli || []).map((d) => [d.domanda_id, d]))

    return (
      <section className="rai-panel rai-quiz-result" aria-live="polite">
        <div className="rai-result-hero">
          <span className="rai-result-emoji" aria-hidden="true">{messaggio.emoji}</span>
          <div>
            <p className="rai-eyebrow mb-1">Quiz completato</p>
            <h2 className="rai-result-title">{messaggio.titolo}</h2>
            <p className="rai-result-text mb-0">{messaggio.testo}</p>
          </div>
          <div className="rai-score">
            <strong>{percentuale}%</strong>
            <span>{risultato.corrette}/{risultato.totali} corrette</span>
          </div>
        </div>

        <div className="rai-result-bar" aria-hidden="true">
          <span style={{ width: `${percentuale}%` }} />
        </div>

        <div className="d-flex flex-wrap justify-content-between align-items-center gap-2 my-3">
          <h3 className="h6 mb-0">Rivedi le risposte</h3>
          <button
            type="button"
            className="btn rai-btn-primary btn-sm"
            onClick={() => { azzera(); setIndice(0) }}
          >
            Rifai il quiz 🔁
          </button>
        </div>

        <div className="rai-review-list">
          {domande.map((d) => {
            const esito = dettagli.get(d.domanda.id)
            const scelta = d.domanda.opzione.find((o) => o.id === risposte[d.domanda.id])
            const corretta = d.domanda.opzione.find((o) => o.id === esito?.opzione_corretta_id)
            return (
              <details key={d.domanda.id} className={`rai-review-item ${esito?.corretta ? 'ok' : 'ko'}`}>
                <summary>
                  <span className="rai-review-icon" aria-hidden="true">{esito?.corretta ? '✅' : '❌'}</span>
                  <span className="rai-review-question">{d.domanda.testo}</span>
                </summary>
                <div className="rai-review-body">
                  <p className="mb-1">
                    <strong>La tua risposta:</strong> {scelta?.testo || 'Nessuna risposta'}
                  </p>
                  {!esito?.corretta && (
                    <p className="mb-1"><strong>Risposta corretta:</strong> {corretta?.testo}</p>
                  )}
                  <p className="mb-0 rai-review-explanation">
                    <strong>Perché:</strong> {esito?.spiegazione || d.domanda.spiegazione || 'Nessuna spiegazione disponibile.'}
                  </p>
                </div>
              </details>
            )
          })}
        </div>
      </section>
    )
  }

  const corrente = domande[indice]
  const domanda = corrente.domanda
  const rispostaScelta = risposte[domanda.id]
  const livello = LIVELLI[domanda.livello] || { label: domanda.livello, emoji: '📘' }

  return (
    <section className="rai-panel rai-quiz">
      <div className="rai-quiz-head">
        <div>
          <p className="rai-eyebrow mb-1">🧠 Quiz di verifica</p>
          <h2 className="rai-quiz-title">{titolo || 'Mettiti alla prova'}</h2>
        </div>
        <span className="rai-chip">{risposteDate}/{totale} risposte</span>
      </div>

      <div
        className="rai-progress"
        role="progressbar"
        aria-valuenow={avanzamento}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-label="Avanzamento del quiz"
      >
        <span className="rai-progress-bar" style={{ width: `${avanzamento}%` }} />
      </div>

      {errore && <div className="alert alert-danger py-2 small">{errore}</div>}

      <div className="rai-question">
        <div className="rai-question-top">
          <span className="rai-step">Domanda {indice + 1} di {totale}</span>
          <span className={`rai-level rai-level-${String(domanda.livello).toLowerCase()}`}>
            <span aria-hidden="true">{livello.emoji}</span> {livello.label}
          </span>
        </div>

        <fieldset>
          <legend className="rai-question-text">{domanda.testo}</legend>
          <div className="rai-options">
            {domanda.opzione.map((o, i) => (
              <label
                key={o.id}
                className={`rai-option ${rispostaScelta === o.id ? 'selected' : ''}`}
              >
                <input
                  type="radio"
                  name={domanda.id}
                  value={o.id}
                  checked={rispostaScelta === o.id}
                  onChange={() => rispondi(domanda.id, o.id)}
                />
                <span className="rai-option-letter" aria-hidden="true">
                  {String.fromCharCode(65 + i)}
                </span>
                <span className="rai-option-text">{o.testo}</span>
              </label>
            ))}
          </div>
        </fieldset>
      </div>

      <div className="rai-quiz-footer">
        <div className="d-flex gap-2">
          <button
            type="button"
            className="btn rai-btn-ghost"
            disabled={indice === 0}
            onClick={() => setIndice((i) => Math.max(0, i - 1))}
          >
            ← Indietro
          </button>
          <button
            type="button"
            className="btn rai-btn-ghost"
            disabled={indice === totale - 1}
            onClick={() => setIndice((i) => Math.min(totale - 1, i + 1))}
          >
            Avanti →
          </button>
        </div>

        <div className="d-flex align-items-center gap-2">
          {!rispostaScelta && <span className="rai-hint d-none d-sm-inline">Scegli una risposta</span>}
          <button
            type="button"
            className="btn rai-btn-primary"
            onClick={invia}
            disabled={invio || risposteDate < totale}
            title={risposteDate < totale ? 'Rispondi a tutte le domande per consegnare' : undefined}
          >
            {invio
              ? 'Invio…'
              : risposteDate === totale
                ? 'Consegna il quiz 🚀'
                : `Da rispondere: ${totale - risposteDate}`}
          </button>
        </div>
      </div>
    </section>
  )
}
