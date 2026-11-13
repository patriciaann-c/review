import { useMemo } from 'react'

// I moduli sono file .md importati a build time: nessuna richiesta di rete.
const FILE = import.meta.glob('../content/moduli/*.md', {
  query: '?raw',
  import: 'default',
  eager: true,
})

// Elenco ordinato dei moduli con titolo preso dal primo heading del file.
export function useModuli() {
  return useMemo(
    () =>
      Object.entries(FILE)
        .map(([percorso, testo]) => {
          const file = percorso.split('/').pop()
          const titolo = testo.match(/^#\s+(.+)$/m)?.[1] || file
          return { slug: file.replace(/\.md$/, ''), titolo, testo }
        })
        .sort((a, b) => a.slug.localeCompare(b.slug)),
    [],
  )
}
