import { useEffect, useMemo, useState } from 'react'
import { supabase } from '../lib/supabase'

// Traguardi del percorso: ordine di sblocco e soglie.
const TRAGUARDI = [
  { id: 'primo-quiz', emoji: '🎯', nome: 'Primo passo', desc: 'Completa il tuo primo quiz.', obiettivo: 1, unita: 'quiz' },
  { id: 'cinque-quiz', emoji: '🔥', nome: 'Costanza', desc: 'Completa 5 quiz.', obiettivo: 5, unita: 'quiz' },
  { id: 'cento-risposte', emoji: '💯', nome: 'Centurione', desc: 'Rispondi a 100 domande.', obiettivo: 100, unita: 'risposte' },
  { id: 'precisione', emoji: '🎖️', nome: 'Precisione', desc: 'Raggiungi l\'80% di risposte corrette (almeno 3 quiz).', obiettivo: 80, unita: '%' },
  { id: 'esploratore', emoji: '🧭', nome: 'Esploratore', desc: 'Allenati su 5 argomenti diversi.', obiettivo: 5, unita: 'argomenti' },
  { id: 'padrone', emoji: '👑', nome: 'Padrone', desc: 'Porta un argomento all\'80% di padronanza.', obiettivo: 1, unita: 'argomento' },
  { id: 'programma', emoji: '🏆', nome: 'Tutto il programma', desc: 'Allenati su tutti gli argomenti del corso.', obiettivo: 11, unita: 'argomenti' },
]

const XP_PER_RISPOSTA = 10
const XP_PER_QUIZ = 25
const XP_PER_LIVELLO = 250
const SOGLIA_PADRONANZA = 0.8

function somma(numeri) {
  return numeri.reduce((tot, n) => tot + n, 0)
}

// Carica tentativi e padronanza dell'utente e calcola traguardi, livello e prossimo ripasso.
export function useProgressi({ refresh = 0, totaleArgomenti = 0 } = {}) {
  const [tentativi, setTentativi] = useState([])
  const [argomenti, setArgomenti] = useState([])
  const [caricamento, setCaricamento] = useState(true)
  const [errore, setErrore] = useState('')

  useEffect(() => {
    let attivo = true

    async function carica() {
      setCaricamento(true)
      const { data: sessione } = await supabase.auth.getSession()
      const utenteId = sessione?.session?.user?.id
      if (!utenteId) {
        if (attivo) { setTentativi([]); setArgomenti([]); setCaricamento(false) }
        return
      }

      const [quizRes, padronanzaRes] = await Promise.all([
        supabase
          .from('tentativo')
          .select('id, punteggio, risposte_totali, risposte_corrette, stato, iniziato_il, finito_il')
          .eq('utente_id', utenteId)
          .order('iniziato_il', { ascending: false })
          .limit(500),
        supabase
          .from('utente_argomento')
          .select('mastery, tentativi_totali, ultimo_ripasso_il, argomento:argomento_id ( id, nome, slug, modulo:modulo_id ( numero ) )')
          .eq('utente_id', utenteId),
      ])

      if (!attivo) return
      if (quizRes.error || padronanzaRes.error) {
        setErrore(quizRes.error?.message || padronanzaRes.error?.message || 'Errore di caricamento')
      } else {
        setErrore('')
        setTentativi(quizRes.data || [])
        setArgomenti(padronanzaRes.data || [])
      }
      setCaricamento(false)
    }

    carica()
    return () => { attivo = false }
  }, [refresh])

  const dati = useMemo(() => {
    const completati = tentativi.filter((t) => t.stato === 'COMPLETATO')
    const risposte = somma(completati.map((t) => t.risposte_totali || 0))
    const corrette = somma(completati.map((t) => t.risposte_corrette || 0))
    const precisione = risposte > 0 ? Math.round((corrette / risposte) * 100) : 0
    const media = completati.length
      ? Math.round(somma(completati.map((t) => Number(t.punteggio) || 0)) / completati.length)
      : 0

    const argomentiAllenati = argomenti.filter((a) => a.argomento)
    const padroneggiati = argomentiAllenati.filter((a) => Number(a.mastery) >= SOGLIA_PADRONANZA)
    const totale = totaleArgomenti || TRAGUARDI.find((t) => t.id === 'programma').obiettivo

    const xp = corrette * XP_PER_RISPOSTA + completati.length * XP_PER_QUIZ
    const livello = Math.floor(xp / XP_PER_LIVELLO) + 1
    const xpNelLivello = xp % XP_PER_LIVELLO

    const valori = {
      'primo-quiz': completati.length,
      'cinque-quiz': completati.length,
      'cento-risposte': risposte,
      precisione: completati.length >= 3 ? precisione : 0,
      esploratore: argomentiAllenati.length,
      padrone: padroneggiati.length,
      programma: argomentiAllenati.length,
    }

    const traguardi = TRAGUARDI.map((t) => {
      const obiettivo = t.id === 'programma' ? totale : t.obiettivo
      const valore = Math.min(valori[t.id] || 0, obiettivo)
      return {
        ...t,
        obiettivo,
        valore,
        fatto: valore >= obiettivo && obiettivo > 0,
        percentuale: obiettivo > 0 ? Math.round((valore / obiettivo) * 100) : 0,
      }
    })

    const prossimo = traguardi.find((t) => !t.fatto) || null

    const daRipassare = [...argomentiAllenati]
      .filter((a) => a.argomento)
      .sort((a, b) => Number(a.mastery) - Number(b.mastery))[0]

    return {
      quizCompletati: completati.length,
      risposte,
      corrette,
      precisione,
      media,
      ultimo: tentativi[0]?.finito_il || tentativi[0]?.iniziato_il || null,
      argomentiAllenati: argomentiAllenati.length,
      argomentiTotali: totale,
      padroneggiati: padroneggiati.length,
      xp,
      livello,
      xpNelLivello,
      xpAlProssimo: XP_PER_LIVELLO,
      traguardi,
      sbloccati: traguardi.filter((t) => t.fatto).length,
      prossimo,
      daRipassare: daRipassare
        ? {
            id: daRipassare.argomento.id,
            nome: daRipassare.argomento.nome,
            slug: daRipassare.argomento.slug,
            mastery: Math.round(Number(daRipassare.mastery) * 100),
          }
        : null,
    }
  }, [tentativi, argomenti, totaleArgomenti])

  return { dati, caricamento, errore }
}
