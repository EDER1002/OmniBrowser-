/**
 * OmniBrowser - resaltado visual de interacciones (Playwright MCP).
 *
 * Dibuja un "cuadro de luz" rojo alrededor del elemento donde el agente
 * actúa, para que la persona que observa la ventana vea qué está haciendo:
 *  - Al hacer click en cualquier elemento (pointerdown).
 *  - Al enfocar un campo de texto (focusin).
 *
 * No mueve el mouse, no bloquea el usuario y no consume recursos medibles
 * (unos pocos bytes de DOM que desaparecen solos tras ~1.1 segundos).
 *
 * Instalación: install.sh copia este archivo a
 * ~/.config/opencode/omnibrowser/ y lo referencia desde cada
 * mcp-<navegador>-config.json mediante "initScript".
 *
 * Uso manual para resaltar ANTES de una acción:
 *   browser_evaluate({ element: <ref>, function: "(el) => window.__ocHighlight(el)" })
 */
(() => {
  if (window.__ocHighlightInstalled) return;
  window.__ocHighlightInstalled = true;

  const DURATION = 1100;

  const style = document.createElement('style');
  style.textContent = `
    .omnibrowser-hl-ring {
      position: fixed;
      z-index: 2147483647;
      pointer-events: none;
      border: 3px solid #ff2d2d;
      border-radius: 6px;
      box-shadow: 0 0 0 4px rgba(255, 45, 45, 0.28), 0 0 14px rgba(255, 45, 45, 0.55);
      animation: omnibrowser-hl-fade ${DURATION}ms ease-out forwards;
    }
    @keyframes omnibrowser-hl-fade {
      0%   { opacity: 1; transform: scale(1); }
      70%  { opacity: 1; transform: scale(1); }
      100% { opacity: 0; transform: scale(1.03); }
    }
  `;
  (document.documentElement || document.head).appendChild(style);

  function flash(el) {
    if (!el || typeof el.getBoundingClientRect !== 'function') return;
    const r = el.getBoundingClientRect();
    if ((r.width === 0 && r.height === 0) || !isFinite(r.left)) return;
    const box = document.createElement('div');
    box.className = 'omnibrowser-hl-ring';
    box.style.left = Math.round(r.left - 4) + 'px';
    box.style.top = Math.round(r.top - 4) + 'px';
    box.style.width = Math.round(r.width + 8) + 'px';
    box.style.height = Math.round(r.height + 8) + 'px';
    (document.documentElement || document.body).appendChild(box);
    setTimeout(() => box.remove(), DURATION + 150);
  }

  // Resalta automáticamente en cada click y en cada campo enfocado.
  document.addEventListener('pointerdown', (e) => flash(e.target), true);
  document.addEventListener('focusin', (e) => flash(e.target), true);

  // API manual para resaltar antes de una acción.
  window.__ocHighlight = (el) => flash(el || document.activeElement);
})();
