/**
 * OmniBrowser - cursor fantasma morado (Playwright MCP).
 *
 * Inyecta en cada página un puntero SVG morado (#9D00FF) que el agente
 * controla para mostrar en tiempo real hacia dónde apunta, sin confundirse
 * con el cursor físico del usuario.
 *
 * Propiedades:
 *  - SVG embebido en el código (sin archivos de imagen externos).
 *  - Silueta de puntero clásica con punta hacia la IZQUIERDA, fondo transparente.
 *  - position: fixed; z-index: 999999; pointer-events: none; -> nunca
 *    secuestra ni bloquea los clics físicos del usuario.
 *  - transition: top 0.1s ease-out, left 0.1s ease-out; -> movimiento suave.
 *
 * Instalación: install.sh copia este archivo a
 * ~/.config/opencode/omnibrowser/ y lo referencia desde cada
 * mcp-<navegador>-config.json mediante "initScript".
 *
 * Sincronización (backend -> frontend):
 *   browser_evaluate({ function: "() => window.__omnibrowserCursor(x, y)" })
 *   browser_evaluate({ element: <ref>, function: "(el) => window.__omnibrowserCursor(el)" })
 *   browser_evaluate({ function: "() => window.__omnibrowserCursor.hide()" })
 */
(() => {
  if (window.__omnibrowserCursor) return;

  const SVG_NS = 'http://www.w3.org/2000/svg';

  const host = document.createElement('div');
  host.id = 'omnibrowser-ghost-cursor';
  host.setAttribute('aria-hidden', 'true');
  host.style.cssText = [
    'position: fixed',
    'z-index: 999999',
    'pointer-events: none',
    'top: -100px',
    'left: -100px',
    'transition: top 0.1s ease-out, left 0.1s ease-out',
    'line-height: 0',
  ].join(';');

  // SVG embebido: silueta de puntero clásica con la punta hacia la izquierda.
  const svg = document.createElementNS(SVG_NS, 'svg');
  svg.setAttribute('width', '32');
  svg.setAttribute('height', '32');
  svg.setAttribute('viewBox', '0 0 32 32');
  svg.setAttribute('focusable', 'false');

  const path = document.createElementNS(SVG_NS, 'path');
  // Punta en (2,16) -> lado izquierdo; cuerpo y cola hacia la derecha.
  path.setAttribute('d', 'M2 16 L16 4 L16 11 L28 11 L28 21 L16 21 L16 28 Z');
  path.setAttribute('fill', '#9D00FF');
  path.setAttribute('stroke', '#9D00FF');
  path.setAttribute('stroke-width', '1.5');
  path.setAttribute('stroke-linejoin', 'round');

  svg.appendChild(path);
  host.appendChild(svg);
  (document.documentElement || document.body).appendChild(host);

  // Mueve el cursor. Acepta coordenadas de viewport (x, y) o un elemento
  // del DOM, al que se posiciona en su centro.
  function move(x, y) {
    let px = x;
    let py = y;
    if (x && typeof x.getBoundingClientRect === 'function') {
      const r = x.getBoundingClientRect();
      px = r.left + r.width / 2;
      py = r.top + r.height / 2;
    }
    if (!isFinite(px) || !isFinite(py)) return;
    host.style.left = Math.round(px) + 'px';
    host.style.top = Math.round(py) + 'px';
  }

  move.hide = () => {
    host.style.left = '-100px';
    host.style.top = '-100px';
  };

  window.__omnibrowserCursor = move;
})();
