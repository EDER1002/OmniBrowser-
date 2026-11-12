# OmniBrowser - Automatización de navegadores MCP para OpenCode y Claude

<p align="center">
  <img src="logo.png" alt="OmniBrowser Logo" width="200">
</p>

OmniBrowser configura **Playwright MCP** para que tus agentes de IA (OpenCode, Claude Desktop o Claude Code) controlen tu navegador: abrir páginas, leer contenido, hacer clic y rellenar formularios.

Además incluye un **cursor fantasma morado**: un puntero visual dentro del navegador que la IA mueve para que puedas ver en tiempo real dónde está apuntando, sin confundirse con tu cursor físico.

- **Multi-navegador:** Firefox, Brave, Opera, Google Chrome y Chromium.
- **Multiplataforma:** Linux (`install.sh`) y Windows (`install.ps1`).
- **Multi-cliente:** OpenCode, Claude Desktop y Claude Code.
- **Configuración segura:** respaldo automático antes de modificar cualquier archivo y conservación de los servidores que no son de OmniBrowser.

---

## ✨ Cursor fantasma morado (AI Pointer)

Cada configuración generada incluye `initScript: ["ghost-cursor.js"]`. El script se inyecta en todas las páginas **antes** que cualquier otro script y crea un puntero SVG morado:

- **SVG embebido en el código** (no depende de archivos de imagen externos).
- **Color:** `#9D00FF` con fondo transparente.
- **Orientación:** punta hacia la **izquierda**, inversa a la inclinación tradicional.
- **Comportamiento CSS:**

```css
position: fixed;
z-index: 999999;
pointer-events: none;
transition: top 0.1s ease-out, left 0.1s ease-out;
```

`pointer-events: none` es vital: el cursor **nunca secuestra ni bloquea tus clics físicos**. Es un elemento puramente visual.

### Cómo se mueve (backend → frontend)

No hay servidor web ni puertos abiertos: la comunicación ocurre por la propia herramienta de evaluación del MCP.

1. **Backend (agente):** decide unas coordenadas `(x, y)` o un elemento de la página.
2. **Transporte:** llama a `browser_evaluate` con esas coordenadas.
3. **Frontend (página):** `ghost-cursor.js` expone `window.__omnibrowserCursor(x, y)`, que actualiza las propiedades `left` y `top`; la transición CSS suaviza el desplazamiento.

```js
// Mover a coordenadas exactas de viewport
() => window.__omnibrowserCursor(320, 180)

// Mover al centro de un elemento (por referencia del snapshot)
(el) => window.__omnibrowserCursor(el)

// Ocultar el cursor
() => window.__omnibrowserCursor.hide()
```

Para desactivarlo, elimina la clave `initScript` de la configuración generada; solo después (opcional) puedes borrar `ghost-cursor.js`. **No borres el archivo sin antes quitar `initScript`**: Playwright fallaría al crear el contexto de navegación y dejarían de funcionar todas las herramientas del navegador, no solo el cursor.

---

## 🚀 Características

- **Soporte multi-navegador:** Firefox, Brave, Opera, Google Chrome y Chromium.
- **Gecko y Chromium:** usa el motor Firefox de Playwright para Firefox y el motor Chromium con el ejecutable del sistema para el resto.
- **Multiplataforma:** instaladores equivalentes para Linux y Windows, con detección de rutas estándar en cada sistema.
- **Multi-cliente:** registra los servidores en OpenCode y/o en Claude (Desktop y Code) sin conflictos entre ellos.
- **Cursor fantasma morado** controlado por la IA (ver sección anterior).
- **Instalación interactiva:** si encuentra varios navegadores, permite escoger uno desde la terminal.
- **Modo múltiple:** `--all` registra todos los navegadores detectados.
- **Configuración segura:** crea una copia de respaldo con fecha antes de modificar `opencode.json` o `claude_desktop_config.json`, y conserva los demás servidores MCP.

---

## 📂 Estructura del repositorio

```text
OmniBrowser/
├── configs/
│   ├── windows/                       # Plantillas con rutas de Windows
│   │   ├── mcp-chrome-config.json
│   │   ├── mcp-brave-config.json
│   │   ├── mcp-opera-config.json
│   │   └── mcp-chromium-config.json
│   ├── mcp-firefox-config.json        # Plantillas con rutas de Linux
│   ├── mcp-brave-config.json
│   ├── mcp-opera-config.json
│   ├── mcp-chrome-config.json
│   ├── mcp-chromium-config.json
│   └── mcp-chromium-cdp.example.json
├── ghost-cursor.js                    # Cursor fantasma morado de la IA
├── install.sh                         # Instalador para Linux
├── install.ps1                        # Instalador para Windows
├── mcp-firefox-config.json            # Plantilla de referencia (raíz)
├── opencode.example.json              # Ejemplo de registro en OpenCode
├── claude.example.json                # Ejemplo de registro en Claude
├── logo.png
├── LICENSE
└── README.md
```

Los instaladores generan las configuraciones definitivas en:

| Cliente | Directorio |
| --- | --- |
| OpenCode | `${XDG_CONFIG_HOME:-~/.config}/opencode/omnibrowser/` en Linux · `~/.config/opencode/omnibrowser/` en Windows |
| Claude Desktop | `%APPDATA%\Claude\` (Windows) · `~/.config/Claude/` (Linux, si existe) |

En cada archivo Chromium colocan la ruta real del ejecutable detectado. Las carpetas `configs/` y `configs/windows/` son **ejemplos de referencia**; no las copies tal cual a tu directorio de configuración (las rutas relativas de `initScript` dejarían de resolver): ejecuta el instalador, que genera las configuraciones definitivas con `ghost-cursor.js` junto a ellas.

---

## 🧰 Requisitos

### Linux

- Linux con entorno gráfico activo (probado a nivel de diseño para Arch Linux; puede funcionar en otras distribuciones). Playwright MCP abre el navegador en modo visible por defecto.
- Bash 4 o superior, Python 3, Node.js 20 o superior con `npx`.
- Al menos uno de los navegadores soportados disponible en `PATH`.

```bash
sudo pacman -S --needed bash python nodejs npm     # Arch
sudo apt install bash python3 nodejs npm           # Debian/Ubuntu
```

> Ojo con Debian/Ubuntu: el `nodejs` de los repositorios suele ser **inferior a Node 20**. Si el instalador se queja de la versión de Node, instala una versión reciente con [NodeSource](https://github.com/nodesource/distributions) o `nvm install --lts`.

### Windows

- Windows 10 o superior con **PowerShell 7 o superior** (`winget install Microsoft.PowerShell`). El instalador lo comprueba y te avisa si solo tienes Windows PowerShell 5.1.
- Node.js 20 o superior (`winget install OpenJS.NodeJS.LTS`).
- Al menos uno de los navegadores soportados.

Rutas estándar que detecta `install.ps1`:

| Navegador | Rutas comprobadas |
| --- | --- |
| Firefox | `%ProgramFiles%\Mozilla Firefox\firefox.exe`, `%ProgramFiles(x86)%\...` |
| Chrome | `%ProgramFiles%\Google\Chrome\Application\chrome.exe`, `%ProgramFiles(x86)%\...`, `%LOCALAPPDATA%\...` |
| Brave | `%LOCALAPPDATA%\BraveSoftware\Brave-Browser\Application\brave.exe`, `%ProgramFiles%\...` |
| Opera | `%LOCALAPPDATA%\Programs\Opera\opera.exe`, `%LOCALAPPDATA%\Programs\Opera GX\opera.exe`, `%ProgramFiles%\Opera\opera.exe` |
| Chromium | `%LOCALAPPDATA%\Chromium\Application\chrome.exe`, `%ProgramFiles%\...` |

Si el navegador no está en esas rutas, añádelo a `PATH` y el instalador lo encontrará igualmente.

---

## 🛠️ Instalación en Linux

```bash
git clone https://github.com/EDER1002/OmniBrowser-.git
cd OmniBrowser-
chmod +x install.sh
./install.sh
```

Si encuentra un solo navegador lo configura automáticamente; si encuentra varios, muestra un menú para elegir.

```bash
./install.sh --all             # Todos los navegadores detectados
./install.sh --browser brave   # Solo Brave
./install.sh --claude          # Además, registra en Claude
./install.sh --help            # Ayuda
```

## 🪟 Instalación en Windows

Abre una terminal **PowerShell 7** (`pwsh`) en la carpeta del repositorio y ejecuta:

```powershell
git clone https://github.com/EDER1002/OmniBrowser-.git
cd OmniBrowser-
pwsh -ExecutionPolicy Bypass -File .\install.ps1
```

> `-ExecutionPolicy Bypass` solo afecta a esta ejecución; es necesario porque Windows bloquea por defecto la ejecución de scripts de PowerShell. Si `pwsh` no se reconoce, instala PowerShell 7 con `winget install Microsoft.PowerShell`.

Mismas opciones que en Linux, en forma de parámetros:

```powershell
.\install.ps1 -All                # Todos los navegadores detectados
.\install.ps1 -Browser brave      # Solo Brave
.\install.ps1 -Claude             # Además, registra en Claude Desktop / Code
.\install.ps1 -Help               # Ayuda
```

---

## 🔌 Integración con OpenCode

OpenCode guarda su configuración global en `~/.config/opencode/opencode.json(c)` en **todos los sistemas operativos** (en Linux, `install.sh` respeta `XDG_CONFIG_HOME` si lo tienes definido).

Los servidores locales van dentro de `mcp.servers` y usan **un único arreglo `command`** con todos los argumentos (`-y`, paquete MCP y `--config`). No existe una propiedad separada `args` en OpenCode.

```json
{
  "$schema": "https://opencode.ai/config.json",
  "mcp": {
    "servers": {
      "omnibrowser-firefox": {
        "type": "local",
        "command": [
          "npx",
          "-y",
          "@playwright/mcp@latest",
          "--config",
          "/home/usuario/.config/opencode/omnibrowser/mcp-firefox-config.json"
        ],
        "timeout": { "startup": 60000, "catalog": 30000 }
      }
    }
  }
}
```

`opencode.example.json` muestra las cinco entradas posibles deshabilitadas. Los instaladores crean las entradas de los navegadores que elijas y reemplazan únicamente las administradas por OmniBrowser (`omnibrowser-*`) y la entrada legada `firefox-playwright`, conservando el resto de tus servidores MCP.

Al terminar, **reinicia OpenCode** y comprueba la conexión con `/mcps`.

---

## 🤖 Integración con Claude

Claude usa el formato `mcpServers`, distinto al de OpenCode: `command` es un **string** y los argumentos van en `args`.

```json
{
  "mcpServers": {
    "omnibrowser-firefox": {
      "command": "npx",
      "args": [
        "-y",
        "@playwright/mcp@latest",
        "--config",
        "/ABSOLUTE/PATH/TO/omnibrowser/mcp-firefox-config.json"
      ]
    }
  }
}
```

### Claude Desktop

| Sistema | Archivo de configuración |
| --- | --- |
| Windows | `%APPDATA%\Claude\claude_desktop_config.json` |
| macOS | `~/Library/Application Support/Claude/claude_desktop_config.json` |
| Linux | `~/.config/Claude/claude_desktop_config.json` (solo si tienes alguna versión instalada) |

- En **Windows**: `.\install.ps1 -Claude` crea o fusiona el archivo automáticamente (con respaldo).
- En **Linux**: `./install.sh --claude` fusiona **solo si el archivo ya existe**; si no, imprime los comandos de Claude Code en su lugar.

`claude.example.json` contiene las cinco entradas con rutas absolutas de ejemplo: reemplaza `/ABSOLUTE/PATH/TO/` por la ruta real de tu directorio `omnibrowser/` y pega el contenido en tu archivo de configuración.

### Claude Code

Registra cada servidor con la CLI (una línea por navegador):

```bash
claude mcp add omnibrowser-firefox -- npx -y @playwright/mcp@latest --config "$HOME/.config/opencode/omnibrowser/mcp-firefox-config.json"
```

Si usas `XDG_CONFIG_HOME`, ajusta la ruta: el instalador imprime el comando exacto para tu sistema.

Ambos instaladores imprimen estos comandos cuando se les pasa `--claude` / `-Claude`. También puedes copiar `claude.example.json` como `.mcp.json` en la raíz de un proyecto: Claude Code lo lee con la misma estructura `mcpServers`.

---

## ⚙️ Firefox vs. Chromium: puertos y depuración remota

Hay dos formas de trabajar, y no deben confundirse:

### 1. Playwright inicia el navegador (modo predeterminado)

Es el modo configurado por los instaladores.

- **Firefox:** se configura con `browserName: "firefox"`. Playwright descarga y usa su propia compilación de Firefox compatible con su protocolo de automatización; no intenta conectarse a la instalación normal de Firefox del sistema.
- **Brave, Opera, Chrome y Chromium:** se configuran con `browserName: "chromium"` y `launchOptions.executablePath` apuntando al ejecutable detectado.
- **No hace falta fijar `--remote-debugging-port=9222`** en este modo. Playwright inicia y administra el navegador directamente.

### 2. Conectarse a un Chromium que ya está abierto (CDP opcional)

Solo necesitas el puerto de depuración cuando quieres que MCP se conecte a una instancia que tú iniciaste previamente:

```bash
mkdir -p "$HOME/.cache/omnibrowser/brave-cdp-profile"
brave --remote-debugging-port=9222 \
  --user-data-dir="$HOME/.cache/omnibrowser/brave-cdp-profile"
```

Para Opera, Chrome o Chromium sustituye `brave` por el ejecutable correspondiente. Después utiliza una configuración con `cdpEndpoint`:

```json
{
  "browser": {
    "browserName": "chromium",
    "cdpEndpoint": "http://127.0.0.1:9222",
    "initScript": ["ghost-cursor.js"]
  }
}
```

Las rutas de `initScript` son relativas al **directorio donde vive el archivo de configuración**, por eso el ejemplo lleva `ghost-cursor.js` sin `../` (el fichero `configs/mcp-chromium-cdp.example.json` usa `../ghost-cursor.js` porque está dentro de `configs/`). Hay un ejemplo en `configs/mcp-chromium-cdp.example.json`. Usa un perfil separado para esta sesión; no expongas el puerto de depuración a redes no confiables.

**Firefox no usa este endpoint CDP de Chromium.** Para Firefox, utiliza el modo de lanzamiento gestionado por Playwright.

---

## 🔧 Solución de problemas

**El puerto CDP está ocupado (9222 en uso)**
Otra instancia de Chrome/Chromium ya lo usa. Ciérrala o cambia de puerto:

```bash
ss -ltnp | grep 9222          # Linux: quién lo ocupa
chrome --remote-debugging-port=9223   # usa otro puerto
```

Y apunta `cdpEndpoint` a ese nuevo puerto.

**No detecta el navegador**
Comprueba que el ejecutable esté en `PATH` con `command -v firefox` (Linux) o `$env:PATH` (Windows). En Windows, revisa las rutas de la tabla de requisitos.

**Error de rutas de binarios en Chromium**
Verifica la ruta escrita dentro de `~/.config/opencode/omnibrowser/mcp-<navegador>-config.json` y que el ejecutable exista. Vuelve a ejecutar el instalador para que la regenere.

**No aparece el MCP en OpenCode o Claude**
Reinicia el cliente y revisa `/mcps` (OpenCode) o el icono de MCP (Claude Desktop). Confirma que `npx` funcione desde la misma sesión de usuario.

**Claude en Windows no arranca el servidor**
Claude Desktop a veces no encuentra `npx`. Sustituye `"command": "npx"` por `"command": "cmd"` y añade `"/c", "npx"` al inicio de `args`.

**Error de Node**
Instala Node.js 20 o superior. En Windows: `winget install OpenJS.NodeJS.LTS`.

**Error al iniciar Firefox**
Playwright necesita descargar su navegador la primera vez: revisa que haya conexión a Internet. También puedes instalarlo a mano:

```bash
npx playwright install firefox
```

**PowerShell bloquea install.ps1 (Windows)**
Ejecuta `pwsh -ExecutionPolicy Bypass -File .\install.ps1`. Si te dice que requiere PowerShell 7, instálalo con `winget install Microsoft.PowerShell` y repite el comando con `pwsh`.

**Configuración JSON inválida**
Ambos instaladores se detienen sin sobrescribir el archivo. Corrígelo manualmente y vuelve a ejecutarlos; los respaldos `.bak-<fecha>` quedan junto al archivo original.

---

## 📄 Licencia

Este proyecto está distribuido bajo la licencia **GPL-2.0**. Consulta `LICENSE` para más información.
