import { useEffect, useState } from 'react'
import { supabase } from '../lib/supabase'

// Elenco degli argomenti con modulo di appartenenza e numero di domande.
export function useArgomenti() {
  const [argomenti, setArgomenti] = useState([])
  const [caricamento, setCaricamento] = useState(true)
  const [errore, setErrore] = useState('')

  useEffect(() => {
    let attivo = true
    supabase
      .from('argomento')
      .select('id, nome, slug, modulo:modulo_id ( titolo, numero ), domanda ( count )')
      .then(({ data, error }) => {
        if (!attivo) return
        if (error) setErrore(error.message)
        else {
          const righe = (data || []).map((a) => ({
            ...a,
            modulo: a.modulo?.titolo || '',
            ordine: a.modulo?.numero ?? 0,
            domande: a.domanda?.[0]?.count || 0,
          }))
          // Ordina per modulo e poi per nome: le query PostgREST non ordinano per tabelle unite.
          setArgomenti(righe.sort((a, b) => a.ordine - b.ordine || a.nome.localeCompare(b.nome)))
        }
        setCaricamento(false)
      })
    return () => { attivo = false }
  }, [])

  return { argomenti, caricamento, errore }
}
