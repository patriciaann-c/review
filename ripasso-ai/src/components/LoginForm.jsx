import { useLogin } from '../hooks/useLogin'

// Form unico per accedere o creare un account (Supabase Auth).
export default function LoginForm() {
  const { registrazione, setRegistrazione, dati, setCampo, errore, messaggio, caricamento, invia } = useLogin()
  const campi = [
    ...(registrazione ? [{ id: 'nome', label: 'Come ti chiami?', type: 'text', auto: 'name' }] : []),
    { id: 'email', label: 'Email', type: 'email', auto: 'email' },
    {
      id: 'password',
      label: 'Password',
      type: 'password',
      auto: registrazione ? 'new-password' : 'current-password',
    },
  ]

  return (
    <div className="rai-login-wrap">
      <div className="rai-login-card">
        <div className="rai-login-hero">
          <span className="rai-login-mark" aria-hidden="true">⚡</span>
          <p className="rai-eyebrow mb-2">Il tuo spazio di ripasso</p>
          <h1 className="rai-login-title">Ai Web Developer</h1>
          <p className="rai-login-subtitle mb-0">
            Quiz, moduli e spiegazioni per arrivare all'esame con le idee chiare.
          </p>
          <div className="rai-login-doodles" aria-hidden="true">
            <span>🧠</span><span>📚</span><span>🚀</span>
          </div>
        </div>

        <form className="rai-login-form" onSubmit={invia}>
          <h2 className="h4 mb-1">{registrazione ? 'Crea il tuo account' : 'Bentornato!'}</h2>
          <p className="rai-login-hint mb-4">
            {registrazione ? 'Bastano pochi secondi per iniziare.' : 'Accedi e riparti da dove avevi lasciato.'}
          </p>

          {errore && <div className="alert alert-danger py-2 small" role="alert">{errore}</div>}
          {messaggio && <div className="alert alert-success py-2 small" role="status">{messaggio}</div>}

          {campi.map((c) => (
            <div className="mb-3" key={c.id}>
              <label className="form-label" htmlFor={c.id}>{c.label}</label>
              <input
                id={c.id}
                type={c.type}
                autoComplete={c.auto}
                className="form-control rai-input"
                required
                minLength={c.id === 'password' ? 6 : undefined}
                value={dati[c.id]}
                onChange={(e) => setCampo(c.id, e.target.value)}
              />
            </div>
          ))}

          <button className="btn rai-btn-primary w-100 mt-1" disabled={caricamento}>
            {caricamento ? 'Attendi…' : registrazione ? 'Crea account ✨' : 'Accedi →'}
          </button>
          <button
            type="button"
            className="btn rai-btn-link w-100 mt-2"
            onClick={() => setRegistrazione(!registrazione)}
          >
            {registrazione ? 'Hai già un account? Accedi' : 'Non hai un account? Registrati'}
          </button>
        </form>
      </div>
      <p className="rai-login-footer">Fatto con cura per studiare meglio, non di più. 💜</p>
    </div>
  )
}
