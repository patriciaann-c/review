import { useProgressi } from '../hooks/useProgressi'

function quando(iso) {
  if (!iso) return ''
  const giorni = Math.floor((Date.now() - new Date(iso).getTime()) / 86400000)
  if (giorni <= 0) return 'oggi'
  if (giorni === 1) return 'ieri'
  if (giorni < 30) return `${giorni} giorni fa`
  return new Date(iso).toLocaleDateString('it-IT', { day: 'numeric', month: 'short' })
}

function etichettaProgresso(traguardo, quizCompletati) {
  if (traguardo.id === 'precisione' && quizCompletati < 3) {
    const mancanti = 3 - quizCompletati
    return `Fai ancora ${mancanti} quiz`
  }
  if (traguardo.unita === '%') return `${traguardo.valore}% su ${traguardo.obiettivo}%`
  return `${traguardo.valore}/${traguardo.obiettivo} ${traguardo.unita}`
}

function testoRipasso(mastery) {
  if (mastery >= 80) return 'Sei già forte: un ripasso veloce per non perdere il ritmo.'
  if (mastery >= 40) return 'Ci sei quasi: è l\'argomento su cui puoi guadagnare di più.'
  return 'È l\'argomento con la padronanza più bassa: ricomincia da qui.'
}

// Schedina del percorso: livello, numeri, traguardi e prossimo ripasso.
export default function ProgressiCard({ argomenti = [], refresh = 0, onAllenati }) {
  const { dati, caricamento, errore } = useProgressi({
    refresh,
    totaleArgomenti: argomenti.length,
  })

  if (errore) return null

  if (caricamento) {
    return (
      <section className="rai-panel rai-progressi rai-progressi-loading" aria-live="polite">
        <div className="spinner-border spinner-border-sm text-primary" role="status" />
        <span>Calcolo i tuoi progressi…</span>
      </section>
    )
  }

  const daRipassare = dati.daRipassare
    || (argomenti[0]
      ? { id: argomenti[0].id, nome: argomenti[0].nome, mastery: 0 }
      : null)

  const avanzamentoLivello = Math.round((dati.xpNelLivello / dati.xpAlProssimo) * 100)

  return (
    <section className="rai-panel rai-progressi" aria-labelledby="titolo-progressi">
      <div className="rai-progressi-head">
        <div>
          <p className="rai-eyebrow mb-1">🏅 Il tuo percorso</p>
          <h2 className="rai-progressi-title" id="titolo-progressi">A che punto sei</h2>
          <p className="rai-progressi-sub">
            {dati.ultimo ? `Ultimo allenamento ${quando(dati.ultimo)}` : 'Il primo quiz ti aspetta'}
          </p>
        </div>
        <div className="rai-livello" aria-label={`Livello ${dati.livello}`}>
          <span>Livello</span>
          <strong>{dati.livello}</strong>
        </div>
      </div>

      <div className="rai-metriche">
        <div className="rai-metrica">
          <strong>{dati.quizCompletati}</strong>
          <span>quiz completati</span>
        </div>
        <div className="rai-metrica">
          <strong>{dati.risposte}</strong>
          <span>risposte date</span>
        </div>
        <div className="rai-metrica">
          <strong>{dati.precisione}%</strong>
          <span>risposte corrette</span>
        </div>
        <div className="rai-metrica">
          <strong>{dati.argomentiAllenati}/{dati.argomentiTotali}</strong>
          <span>argomenti</span>
        </div>
      </div>

      <div className="rai-livello-blocco">
        <div className="rai-livello-testo">
          <span>Livello {dati.livello} → {dati.livello + 1}</span>
          <span>{dati.xpNelLivello}/{dati.xpAlProssimo} XP</span>
        </div>
        <div
          className="rai-progress"
          role="progressbar"
          aria-valuenow={avanzamentoLivello}
          aria-valuemin={0}
          aria-valuemax={100}
          aria-label="Avanzamento verso il prossimo livello"
        >
          <span className="rai-progress-bar" style={{ width: `${avanzamentoLivello}%` }} />
        </div>
      </div>

      <div className="rai-traguardi-head">
        <h3>Traguardi</h3>
        <span className="rai-chip">{dati.sbloccati}/{dati.traguardi.length} sbloccati</span>
      </div>
      <ul className="rai-traguardi">
        {dati.traguardi.map((t) => (
          <li key={t.id} className={`rai-traguardo${t.fatto ? ' unlocked' : ''}`} title={t.desc}>
            <span className="rai-traguardo-emoji" aria-hidden="true">{t.fatto ? t.emoji : '🔒'}</span>
            <span className="rai-traguardo-body">
              <span className="rai-traguardo-nome">{t.nome}</span>
              <span className="rai-traguardo-meta">
                {t.fatto ? 'Sbloccato' : etichettaProgresso(t, dati.quizCompletati)}
              </span>
            </span>
            {!t.fatto && (
              <span className="rai-traguardo-bar" aria-hidden="true">
                <span style={{ width: `${t.percentuale}%` }} />
              </span>
            )}
          </li>
        ))}
      </ul>

      {daRipassare && (
        <div className="rai-riprendi">
          <div>
            <p className="rai-riprendi-eyebrow">Riprendi da qui</p>
            <p className="rai-riprendi-nome">
              {daRipassare.nome}
              <span className="rai-chip">{daRipassare.mastery}%</span>
            </p>
            <p className="rai-riprendi-testo">{testoRipasso(daRipassare.mastery)}</p>
          </div>
          <button
            type="button"
            className="btn rai-btn-primary btn-sm"
            onClick={() => onAllenati?.(daRipassare.id)}
          >
            Allenati →
          </button>
        </div>
      )}

      {dati.quizCompletati === 0 && (
        <p className="rai-progressi-nota mb-0">
          Ogni risposta corretta vale 10 XP, ogni quiz completato 25 XP.
        </p>
      )}
    </section>
  )
}
