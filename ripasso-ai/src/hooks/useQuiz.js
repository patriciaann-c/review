import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

// Fisher–Yates: mescola le opzioni lato client senza modificare i dati salvati.
function mescola(items) {
  const copia = [...items]
  for (let i = copia.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1))
    ;[copia[i], copia[j]] = [copia[j], copia[i]]
  }
  return copia
}

// Carica le domande di un argomento e invia il tentativo all'RPC di correzione.
export function useQuiz({ argomentoId } = {}) {
  const [domande, setDomande] = useState([])
  const [risposte, setRisposte] = useState({})
  const [risultato, setRisultato] = useState(null)
  const [caricamento, setCaricamento] = useState(true)
  const [invio, setInvio] = useState(false)
  const [errore, setErrore] = useState('')

  useEffect(() => {
    let attivo = true

    supabase
      .from('domanda')
      .select('id, testo, livello, argomento:argomento_id ( nome ), opzione ( id, testo, ordine )')
      .eq('argomento_id', argomentoId)
      .eq('stato', 'APPROVATA')
      .order('id')
      .then(({ data, error }) => {
        if (!attivo) return
        if (error) setErrore(error.message)
        else {
          setDomande((data || []).map((d) => ({
            domanda: {
              ...d,
              opzione: mescola([...(d.opzione || [])]),
            },
          })))
        }
        setCaricamento(false)
      })

    return () => { attivo = false }
  }, [argomentoId])

  function rispondi(domandaId, opzioneId) {
    setRisposte((prec) => ({ ...prec, [domandaId]: opzioneId }))
  }

  async function invia() {
    setInvio(true)
    setErrore('')
    const payload = domande.map((d) => ({
      domanda_id: d.domanda.id,
      opzione_id: risposte[d.domanda.id] || null,
    }))
    const { data, error } = await supabase.rpc('invia_quiz_argomento', {
      p_argomento_id: argomentoId,
      p_risposte: payload,
    })
    setInvio(false)
    if (error) setErrore(error.message)
    else setRisultato(data)
  }

  function azzera() {
    setRisposte({})
    setRisultato(null)
  }

  return { domande, risposte, rispondi, invia, azzera, risultato, caricamento, invio, errore }
}
