/**
 * OmniBrowser - cursor fantasma de la IA (Playwright MCP).
 *
 * Inyecta en cada página un puntero SVG morado (#9D00FF) que el agente
 * controla para mostrar en tiempo real hacia dónde apunta, sin confundirse
 * con el cursor físico del usuario.
 *
 * Forma:
 *  - SVG embebido en el código (sin archivos de imagen externos).
 *  - Triángulo minimalista de bordes redondeados con la punta aguda hacia la
 *    IZQUIERDA y la base plana vertical a la derecha. Sin cola ni líneas extra.
 *  - Fondo 100% transparente.
 *
 * Comportamiento CSS (sobre el propio elemento SVG):
 *  - position: fixed;                     -> sigue al viewport, no al documento.
 *  - z-index: 2147483647;                 -> siempre por encima de modales.
 *  - pointer-events: none;                -> nunca secuestra los clics físicos.
 *  - transition: top 0.12s ease-out, left 0.12s ease-out, transform 0.1s ease;
 *  - Visible desde el primer frame (no se oculta fuera de la pantalla).
 *
 * Persistencia:
 *  - Se registra con "initScript" en la configuración de Playwright MCP, que
 *    es el equivalente de CDP Page.addScriptToEvaluateOnNewDocument: se
 *    re-inyecta en cada navegación y recarga, sin recalcular nada.
 *
 * Sincronización (backend -> frontend):
 *   browser_evaluate({ function: "() => window.__omnibrowserCursor(x, y)" })
 *   browser_evaluate({ element: <ref>, function: "(el) => window.__omnibrowserCursor(el)" })
 *   browser_evaluate({ function: "() => window.__omnibrowserCursor.pulse()" })
 *   browser_evaluate({ function: "() => window.__omnibrowserCursor.hide()" })
 *
 * Además reacciona solo a la interacción real:
 *  - Clic: si el clic cae cerca del puntero, se dispara un pulso (scale 0.85).
 *  - Scroll: el puntero acompaña al contenido, de modo que se ve el
 *    desplazamiento de la página aunque el agente haga scroll programático.
 *  - Foco: si el elemento que recibe el foco está cerca del puntero, se
 *    reposiciona sobre él (el clic del usuario lejos del puntero no lo mueve).
 */
(() => {
  if (window.__omnibrowserCursor) return;

  const SVG_NS = 'http://www.w3.org/2000/svg';
  const CURSOR_ID = 'omnibrowser-ghost-cursor';

  // Tamaño del SVG en píxeles y vista lógica usada en el trazado.
  const SIZE = 28;
  const VIEWBOX = 24;

  // Desplazamiento de la punta dentro de la caja del SVG: se usa para que la
  // punta (y no el centro) quede exactamente sobre la coordenada apuntada.
  const TIP_X = Math.round((3.4 / VIEWBOX) * SIZE);
  const TIP_Y = Math.round((12 / VIEWBOX) * SIZE);

  // Radio (px) a partir del cual un clic se considera "del agente".
  const CLICK_RADIUS = 32;
  // Distancia máxima a la que se sigue un cambio de foco.
  const FOCUS_RADIUS = 120;
  // Duración del pulso (la transición de transform hace el resto).
  const PULSE_MS = 110;

  // --- Elemento ------------------------------------------------------------
  const cursor = document.createElementNS(SVG_NS, 'svg');
  cursor.id = CURSOR_ID;
  cursor.setAttribute('width', String(SIZE));
  cursor.setAttribute('height', String(SIZE));
  cursor.setAttribute('viewBox', `0 0 ${VIEWBOX} ${VIEWBOX}`);
  cursor.setAttribute('focusable', 'false');
  cursor.setAttribute('aria-hidden', 'true');
  cursor.style.cssText = [
    'position: fixed',
    `left: ${TIP_X}px`,
    `top: ${TIP_Y}px`,
    'width: ' + SIZE + 'px',
    'height: ' + SIZE + 'px',
    'z-index: 2147483647',
    'pointer-events: none',
    'opacity: 1',
    'visibility: visible',
    'transition: top 0.12s ease-out, left 0.12s ease-out, transform 0.1s ease',
    'will-change: top, left, transform',
    'filter: drop-shadow(0 0 3px rgba(157, 0, 255, 0.55))',
    'overflow: visible',
  ].join('; ');

  // Triángulo minimalista con la punta hacia la izquierda:
  //   M  -> borde superior derecho (inicio)
  //   Q  -> esquina superior derecha redondeada
  //   L  -> base vertical plana (lado derecho)
  //   Q  -> esquina inferior derecha redondeada
  //   L  -> borde inferior hacia la punta
  //   Q  -> punta aguda redondeada (control en x = 2.6)
  const path = document.createElementNS(SVG_NS, 'path');
  path.setAttribute(
    'd',
    'M20.4 3.2Q21.5 2.4 21.5 3.7L21.5 20.3Q21.5 21.6 20.4 20.8L4.2 13.2Q2.9 12 4.2 10.8Z'
  );
  path.setAttribute('fill', '#9D00FF');
  cursor.appendChild(path);

  const mount = () => {
    const parent = document.documentElement || document.body;
    if (parent && !cursor.isConnected) parent.appendChild(cursor);
  };
  if (document.documentElement) mount();
  else {
    document.addEventListener('readystatechange', mount, { once: true });
    document.addEventListener('DOMContentLoaded', mount, { once: true });
  }

  // --- Posición ------------------------------------------------------------
  let position = { x: TIP_X, y: TIP_Y };
  let pulseTimer = null;

  const clamp = (value, min, max) => Math.max(min, Math.min(value, max));

  function applyPosition(x, y) {
    const width = cursor.clientWidth || SIZE;
    const height = cursor.clientHeight || SIZE;
    const left = clamp(Math.round(x) - TIP_X, 0, Math.max(0, window.innerWidth - width));
    const top = clamp(Math.round(y) - TIP_Y, 0, Math.max(0, window.innerHeight - height));
    position = { x: left + TIP_X, y: top + TIP_Y };
    cursor.style.left = left + 'px';
    cursor.style.top = top + 'px';
  }

  function isElement(value) {
    return !!value && typeof value === 'object' && typeof value.getBoundingClientRect === 'function';
  }

  // Centra el puntero sobre un elemento. Si el elemento está fuera de la
  // pantalla, primero lo trae a la vista para que el desplazamiento se vea.
  function moveToElement(element) {
    if (!isElement(element)) return false;
    let rect = element.getBoundingClientRect();
    const inViewport =
      rect.width > 0 &&
      rect.height > 0 &&
      rect.top >= 0 &&
      rect.left >= 0 &&
      rect.bottom <= window.innerHeight &&
      rect.right <= window.innerWidth;
    if (!inViewport && typeof element.scrollIntoView === 'function') {
      element.scrollIntoView({ block: 'center', inline: 'center', behavior: 'auto' });
      rect = element.getBoundingClientRect();
    }
    applyPosition(rect.left + rect.width / 2, rect.top + rect.height / 2);
    return true;
  }

  // --- API pública ---------------------------------------------------------
  function ghostCursor(target, maybeY) {
    if (isElement(target)) {
      moveToElement(target);
      return { ...position };
    }
    if (target && typeof target === 'object' && 'x' in target && 'y' in target) {
      applyPosition(Number(target.x), Number(target.y));
      return { ...position };
    }
    const x = Number(target);
    const y = Number(maybeY);
    if (isFinite(x) && isFinite(y)) applyPosition(x, y);
    return { ...position };
  }

  // Pulso visual: escala rápida a 0.85 y vuelta (usa la transición de transform).
  ghostCursor.pulse = () => {
    cursor.style.transform = 'scale(0.85)';
    if (pulseTimer) clearTimeout(pulseTimer);
    pulseTimer = setTimeout(() => {
      cursor.style.transform = 'scale(1)';
    }, PULSE_MS);
    return true;
  };

  // Mueve el puntero y marca el clic (para agentes que prefieran una sola llamada).
  ghostCursor.click = (target) => {
    if (isElement(target)) moveToElement(target);
    else if (target && typeof target === 'object' && 'x' in target) {
      applyPosition(Number(target.x), Number(target.y));
    }
    ghostCursor.pulse();
    return { ...position };
  };

  // Desplaza la página; el listener de scroll mueve el puntero en consecuencia.
  ghostCursor.scrollTo = (y) => {
    const top = typeof y === 'object' && y !== null ? Number(y.top) : Number(y);
    if (!isFinite(top)) return false;
    window.scrollTo({ top, behavior: 'auto' });
    return true;
  };

  ghostCursor.hide = () => {
    cursor.style.opacity = '0';
    cursor.style.visibility = 'hidden';
    return true;
  };

  ghostCursor.show = () => {
    cursor.style.opacity = '1';
    cursor.style.visibility = 'visible';
    return true;
  };

  ghostCursor.position = () => ({ ...position });
  ghostCursor.isVisible = () => cursor.style.visibility !== 'hidden';

  window.__omnibrowserCursor = ghostCursor;

  // --- Reacción a la interacción real --------------------------------------
  // Clic del agente: se detecta por cercanía al puntero (el agente mueve el
  // cursor antes de hacer clic). Un clic del usuario lejos del puntero no
  // dispara nada.
  document.addEventListener(
    'click',
    (event) => {
      const dx = event.clientX - position.x;
      const dy = event.clientY - position.y;
      if (Math.sqrt(dx * dx + dy * dy) <= CLICK_RADIUS) ghostCursor.pulse();
    },
    true
  );

  // Scroll: el puntero acompaña al contenido para que se vea el movimiento.
  let lastWindowScrollY = window.scrollY || 0;

  const onScroll = (event) => {
    const target = event.target;

    // Scroll de la página: el puntero sigue al contenido (mismo delta).
    if (!target || target === document || target === document.documentElement) {
      const y = window.scrollY || document.documentElement.scrollTop || 0;
      const delta = y - lastWindowScrollY;
      lastWindowScrollY = y;
      if (delta) applyPosition(position.x, position.y + delta);
      return;
    }

    // Scroll de un contenedor interno: el puntero se acerca a la zona que se
    // está desplazando, de modo que se note el movimiento aunque el
    // contenedor ni siquiera haya estado antes en pantalla.
    if (!isElement(target)) return;
    const rect = target.getBoundingClientRect();
    const visible =
      rect.width > 0 &&
      rect.height > 0 &&
      rect.bottom > 0 &&
      rect.right > 0 &&
      rect.top < window.innerHeight &&
      rect.left < window.innerWidth;
    if (!visible) return;
    applyPosition(rect.left + rect.width / 2, rect.top + rect.height / 2);
  };
  window.addEventListener('scroll', onScroll, { capture: true, passive: true });

  // Foco: solo se sigue si el elemento enfocado está cerca del puntero, de
  // modo que la navegación del usuario no mueve el cursor del agente.
  document.addEventListener(
    'focusin',
    (event) => {
      const element = event.target;
      if (!isElement(element)) return;
      const rect = element.getBoundingClientRect();
      if (!rect.width && !rect.height) return;
      const cx = rect.left + rect.width / 2;
      const cy = rect.top + rect.height / 2;
      const dx = cx - position.x;
      const dy = cy - position.y;
      if (Math.sqrt(dx * dx + dy * dy) <= FOCUS_RADIUS) applyPosition(cx, cy);
    },
    true
  );

  // Al cambiar el tamaño de la ventana el puntero se mantiene dentro.
  window.addEventListener('resize', () => applyPosition(position.x, position.y));
})();
