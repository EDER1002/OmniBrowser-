# OmniBrowser - OpenCode MCP Automation

<p align="center">
  <img src="logo.png" alt="OmniBrowser Logo" width="200">
</p>

OmniBrowser facilita la automatización de navegadores en Linux mediante **Playwright MCP** y **OpenCode**. El instalador detecta los navegadores disponibles, genera la configuración adecuada y registra el servidor MCP elegido sin reemplazar el resto de la configuración de OpenCode.

## 🚀 Características

- **Soporte multi-navegador:** Firefox, Brave, Opera, Google Chrome y Chromium.
- **Gecko y Chromium:** usa el motor Firefox de Playwright para Firefox y el motor Chromium para Brave, Opera, Chrome y Chromium.
- **Instalación interactiva:** si encuentra varios navegadores, permite escoger uno desde la terminal.
- **Modo múltiple:** `--all` registra todos los navegadores detectados en OpenCode.
- **Configuración segura:** crea una copia de respaldo de `opencode.json` o `opencode.jsonc` antes de modificarlo y conserva los demás servidores MCP.
- **OpenCode actual:** registra los servidores dentro de `mcp.servers` y usa el formato `command` con todos sus argumentos.
- **Cursor fantasma:** inyecta un puntero SVG morado (`#9D00FF`) que el agente mueve para mostrar en tiempo real dónde apunta, sin tocar el cursor físico del usuario.

## 📂 Estructura del repositorio

```text
OmniBrowser/
├── configs/
│   ├── mcp-firefox-config.json  # Plantilla heredada compatible
│   ├── mcp-brave-config.json
│   ├── mcp-opera-config.json
│   ├── mcp-chrome-config.json
│   ├── mcp-chromium-config.json
│   └── mcp-chromium-cdp.example.json
├── install.sh
├── ghost-cursor.js  # Cursor fantasma morado controlado por el agente
├── mcp-firefox-config.json  # Plantilla heredada compatible
├── opencode.example.json
├── logo.png
├── LICENSE
└── README.md
```

El instalador genera las configuraciones definitivas en:

```text
~/.config/opencode/omnibrowser/
```

En cada archivo Chromium coloca la ruta real del ejecutable que detectó en el sistema. Las configuraciones de `configs/` son ejemplos de referencia; no reemplazan las rutas detectadas automáticamente.

## 🧰 Requisitos

- Linux (probado a nivel de diseño para Arch Linux; también puede funcionar en otras distribuciones).
- Bash 4 o superior.
- Python 3.
- Node.js 20 o superior y `npx`.
- Un entorno gráfico activo si quieres ver el navegador. Playwright MCP abre el navegador en modo visible de forma predeterminada.

En Arch Linux puedes instalar los requisitos principales con:

```bash
sudo pacman -S --needed bash python nodejs npm
```

Instala también al menos uno de los navegadores compatibles. El instalador solo detecta ejecutables que estén disponibles en `PATH`.

## 🛠️ Instalación y uso

1. Clona el repositorio:

   ```bash
   git clone https://github.com/EDER1002/OmniBrowser-.git
   cd OmniBrowser-
   ```

2. Dale permisos de ejecución al instalador:

   ```bash
   chmod +x install.sh
   ```

3. Ejecuta el instalador:

   ```bash
   ./install.sh
   ```

   Si encuentra un solo navegador, lo configura automáticamente. Si encuentra varios, muestra un menú para elegir uno.

4. Opciones adicionales:

   ```bash
   # Configurar todos los navegadores detectados
   ./install.sh --all

   # Configurar solamente Brave
   ./install.sh --browser brave

   # Ver las opciones disponibles
   ./install.sh --help
   ```

5. Reinicia OpenCode y revisa la conexión con el comando `/mcps`.

### ¿Qué modifica el instalador?

- Genera `mcp-<browser>-config.json` dentro de `~/.config/opencode/omnibrowser/`.
- Actualiza `~/.config/opencode/opencode.json` (o `opencode.jsonc` si ese es el archivo global existente).
- Añade los servidores elegidos como `mcp.servers.omnibrowser-<browser>`.
- Migra las entradas MCP antiguas que estén directamente dentro de `mcp` al formato actual `mcp.servers`.
- Crea una copia de respaldo con fecha antes de guardar los cambios.
- No elimina ni reemplaza otros servidores MCP ajenos a OmniBrowser.

Si vuelves a ejecutar el instalador, reemplaza únicamente las entradas administradas por OmniBrowser (`omnibrowser-*` y la antigua entrada `firefox-playwright`).

## 🖱️ Cursor fantasma morado

Cada configuración generada incluye `initScript: ["ghost-cursor.js"]`. El script se inyecta en todas las páginas **antes** que cualquier otro script y crea un puntero SVG morado (`#9D00FF`) con punta hacia la izquierda y fondo transparente:

```css
position: fixed;
z-index: 999999;
pointer-events: none;
transition: top 0.1s ease-out, left 0.1s ease-out;
```

`pointer-events: none` garantiza que el cursor **nunca secuestre ni bloquee** tus clics físicos: es un elemento puramente visual.

### Cómo se mueve (backend → frontend)

No hay servidor web ni puerto extra: la comunicación ocurre por la propia herramienta de evaluación del MCP.

1. **Backend (agente):** decide unas coordenadas `(x, y)` o un elemento de la página.
2. **Transporte:** llama a `browser_evaluate` con esas coordenadas.
3. **Frontend (página):** `ghost-cursor.js` expone `window.__omnibrowserCursor(x, y)`, que actualiza las propiedades `left` y `top` del elemento; la transición CSS hace el desplazamiento suave.

```js
// Mover a coordenadas exactas de viewport
() => window.__omnibrowserCursor(320, 180)

// Mover al centro de un elemento (por referencia del snapshot)
(el) => window.__omnibrowserCursor(el)

// Ocultar el cursor
() => window.__omnibrowserCursor.hide()
```

El instalador copia `ghost-cursor.js` a `~/.config/opencode/omnibrowser/` junto a los archivos `mcp-<navegador>-config.json`. Si no quieres el cursor, elimina la clave `initScript` de la configuración generada.

## ⚙️ Firefox vs. Chromium: puertos y depuración remota

Hay dos formas de trabajar, y no deben confundirse:

### 1. Playwright inicia el navegador (modo predeterminado)

Es el modo configurado por `install.sh`.

- **Firefox:** se configura con `browserName: "firefox"`. Playwright descarga y usa su propia compilación de Firefox compatible con su protocolo de automatización; no intenta conectarse a la instalación normal de Firefox del sistema.
- **Brave, Opera, Chrome y Chromium:** se configuran con `browserName: "chromium"` y `launchOptions.executablePath` apuntando al ejecutable detectado.
- **No hace falta fijar `--remote-debugging-port=9222`** en este modo. Playwright inicia y administra el navegador directamente, sin que tengas que abrir un puerto de depuración manual.

### 2. Conectarse a un Chromium que ya está abierto (CDP opcional)

Solo necesitas el puerto de depuración cuando quieres que MCP se conecte a una instancia que tú iniciaste previamente. Por ejemplo, para Brave:

```bash
mkdir -p "$HOME/.cache/omnibrowser/brave-cdp-profile"
brave --remote-debugging-port=9222 \
  --user-data-dir="$HOME/.cache/omnibrowser/brave-cdp-profile"
```

Para Opera, Chrome o Chromium, sustituye `brave` por el ejecutable correspondiente. Después utiliza una configuración con `cdpEndpoint`:

```json
{
  "browser": {
    "browserName": "chromium",
    "cdpEndpoint": "http://127.0.0.1:9222"
  }
}
```

Hay un ejemplo en `configs/mcp-chromium-cdp.example.json`. Debes iniciar el navegador con el puerto antes de conectar el servidor MCP. Usa un perfil separado para esta sesión; no expongas el puerto de depuración a redes no confiables.

**Firefox no usa este endpoint CDP de Chromium.** Para Firefox, utiliza el modo de lanzamiento gestionado por Playwright.

## 🧩 Configuración de OpenCode

OpenCode actual registra servidores locales dentro de `mcp.servers`. Un servidor tiene un único arreglo `command`; los argumentos (`-y`, paquete MCP y `--config`) van en ese mismo arreglo, no en una propiedad separada `args`.

El instalador crea automáticamente entradas como esta, con rutas absolutas:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "omnibrowser-brave": {
        "type": "local",
        "command": [
          "npx",
          "-y",
          "@playwright/mcp@latest",
          "--config",
          "/home/usuario/.config/opencode/omnibrowser/mcp-brave-config.json"
        ]
      }
    }
  }
}
```

`opencode.example.json` muestra las cinco entradas posibles deshabilitadas. El instalador activa únicamente las que hayas elegido, o todas si ejecutas `./install.sh --all`.

## 🔧 Solución de problemas

- **No detecta el navegador:** comprueba que su ejecutable esté en `PATH` con `command -v firefox`, `command -v brave`, etc.
- **No aparece el MCP en OpenCode:** reinicia OpenCode y revisa `/mcps`. Confirma que `npx` funcione desde la misma sesión de usuario que inicia OpenCode.
- **Error de Node:** instala Node.js 20 o superior.
- **Error al iniciar Chromium:** verifica la ruta del ejecutable dentro de `~/.config/opencode/omnibrowser/` y las dependencias del paquete de tu navegador.
- **Error al iniciar Firefox:** revisa que Playwright pueda descargar su navegador; la primera ejecución puede requerir conexión a Internet.
- **Configuración JSON inválida:** el instalador se detiene sin sobrescribirla. Corrige el archivo manualmente y vuelve a ejecutarlo.

## 📄 Licencia

Este proyecto está distribuido bajo la licencia **GPL-2.0**. Consulta `LICENSE` para más información.
