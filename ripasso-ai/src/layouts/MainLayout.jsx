import { NavLink, Outlet } from 'react-router-dom'

const NAV_VOCI = [
  { to: '/quiz', label: 'Quiz', emoji: '🧠' },
  { to: '/moduli', label: 'Moduli', emoji: '📖' },
]

// Layout comune: navbar morbida, contenuto della rotta e footer.
export default function MainLayout({ utente, onEsci }) {
  const iniziale = utente?.email?.[0]?.toUpperCase() ?? '👤'

  return (
    <div className="rai-shell">
      <header className="rai-navbar sticky-top">
        <nav className="container rai-navbar-inner" aria-label="Navigazione principale">
          <NavLink to="/quiz" className="rai-brand text-decoration-none">
            <span className="rai-brand-mark">⚡</span>
            <span>Ai Web Developer</span>
          </NavLink>

          <div className="rai-nav-links">
            {NAV_VOCI.map(({ to, label, emoji }) => (
              <NavLink key={to} to={to}
                className={({ isActive }) => `rai-nav-link${isActive ? ' active' : ''}`}>
                <span aria-hidden="true">{emoji}</span> {label}
              </NavLink>
            ))}
          </div>

          <div className="rai-user-area">
            <span className="rai-avatar" aria-hidden="true">{iniziale}</span>
            <span className="rai-user-email d-none d-md-inline">{utente?.email}</span>
            <button type="button" className="rai-btn-esci" onClick={onEsci}>Esci</button>
          </div>
        </nav>
      </header>

      <main className="container rai-main">
        <Outlet />
      </main>

      <footer className="rai-footer">
        <span>⚡ RipassoAI</span>
        <span aria-hidden="true">·</span>
        <span>studia smart, non di più 🚀</span>
      </footer>
    </div>
  )
}
