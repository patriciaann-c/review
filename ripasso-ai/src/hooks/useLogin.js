import { useState } from 'react'
import { supabase } from '../lib/supabase'

// Stato e azioni del form di accesso/registrazione.
export function useLogin() {
  const [registrazione, setRegistrazione] = useState(false)
  const [dati, setDati] = useState({ nome: '', email: '', password: '' })
  const [errore, setErrore] = useState('')
  const [messaggio, setMessaggio] = useState('')
  const [caricamento, setCaricamento] = useState(false)

  function setCampo(campo, valore) {
    setDati((prec) => ({ ...prec, [campo]: valore }))
  }

  async function invia(e) {
    e.preventDefault()
    setErrore('')
    setMessaggio('')
    setCaricamento(true)
    const risposta = registrazione
      ? await supabase.auth.signUp({ email: dati.email, password: dati.password, options: { data: { nome: dati.nome } } })
      : await supabase.auth.signInWithPassword({ email: dati.email, password: dati.password })
    setCaricamento(false)
    if (risposta.error) setErrore(risposta.error.message)
    else if (registrazione) setMessaggio('Account creato. Conferma la email, poi accedi.')
  }

  return { registrazione, setRegistrazione, dati, setCampo, errore, messaggio, caricamento, invia }
}
