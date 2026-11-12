#!/usr/bin/env bash
# OmniBrowser installer for OpenCode + Playwright MCP.
# Detects local browser binaries and registers one or all of them in OpenCode.

set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OPENCODE_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/opencode"
CONFIG_DIR="${OPENCODE_DIR}/omnibrowser"

# Browser IDs are stable and are also used for the generated MCP server names.
declare -A BROWSER_LABELS=(
  [firefox]="Mozilla Firefox"
  [brave]="Brave Browser"
  [opera]="Opera"
  [chrome]="Google Chrome"
  [chromium]="Chromium"
)

declare -A BROWSER_PATHS=()
FOUND_BROWSERS=()
SELECTED_BROWSERS=()

usage() {
  cat <<'HELP'
OmniBrowser - instalador de MCP para OpenCode

Uso:
  ./install.sh                 Detecta navegadores y muestra un menú si hay varios
  ./install.sh --all           Registra todos los navegadores detectados
  ./install.sh --browser brave Configura un navegador específico
  ./install.sh --help          Muestra esta ayuda

IDs aceptados: firefox, brave, opera, chrome, chromium
HELP
}

resolve_command() {
  local candidate resolved
  for candidate in "$@"; do
    if resolved="$(command -v -- "$candidate" 2>/dev/null)" && [[ -n "$resolved" && -x "$resolved" ]]; then
      if command -v readlink >/dev/null 2>&1; then
        readlink -f -- "$resolved" 2>/dev/null || printf '%s\n' "$resolved"
      else
        printf '%s\n' "$resolved"
      fi
      return 0
    fi
  done
  return 1
}

detect_browsers() {
  local id path

  if path="$(resolve_command firefox)"; then
    BROWSER_PATHS[firefox]="$path"
    FOUND_BROWSERS+=(firefox)
  fi
  if path="$(resolve_command brave brave-browser)"; then
    BROWSER_PATHS[brave]="$path"
    FOUND_BROWSERS+=(brave)
  fi
  if path="$(resolve_command opera)"; then
    BROWSER_PATHS[opera]="$path"
    FOUND_BROWSERS+=(opera)
  fi
  if path="$(resolve_command google-chrome-stable google-chrome chrome)"; then
    BROWSER_PATHS[chrome]="$path"
    FOUND_BROWSERS+=(chrome)
  fi
  if path="$(resolve_command chromium chromium-browser)"; then
    BROWSER_PATHS[chromium]="$path"
    FOUND_BROWSERS+=(chromium)
  fi

  # Avoid an empty, misleading menu if no supported executable was found.
  if ((${#FOUND_BROWSERS[@]} == 0)); then
    echo "No se detectó Firefox, Brave, Opera, Google Chrome ni Chromium en PATH." >&2
    echo "Instala un navegador o asegúrate de que su ejecutable esté disponible en PATH." >&2
    exit 1
  fi
}

select_browsers() {
  local mode="${1:-interactive}"
  local requested="${2:-}"
  local choice index

  case "$mode" in
    all)
      SELECTED_BROWSERS=("${FOUND_BROWSERS[@]}")
      ;;
    browser)
      if [[ -z "${BROWSER_PATHS[$requested]+x}" ]]; then
        echo "El navegador '$requested' no está instalado o no se encontró en PATH." >&2
        echo "Detectados: ${FOUND_BROWSERS[*]}" >&2
        exit 1
      fi
      SELECTED_BROWSERS=("$requested")
      ;;
    interactive)
      if ((${#FOUND_BROWSERS[@]} == 1)); then
        SELECTED_BROWSERS=("${FOUND_BROWSERS[0]}")
        echo "Se detectó un navegador: ${BROWSER_LABELS[${FOUND_BROWSERS[0]}]}"
        return
      fi

      echo "Navegadores detectados:"
      for index in "${!FOUND_BROWSERS[@]}"; do
        id="${FOUND_BROWSERS[$index]}"
        printf '  %d) %s (%s)\n' "$((index + 1))" "${BROWSER_LABELS[$id]}" "${BROWSER_PATHS[$id]}"
      done
      printf 'Selecciona el navegador que quieres vincular con MCP [1-%d]: ' "${#FOUND_BROWSERS[@]}"
      read -r choice
      if [[ ! "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#FOUND_BROWSERS[@]})); then
        echo "Selección no válida. No se realizaron cambios." >&2
        exit 1
      fi
      SELECTED_BROWSERS=("${FOUND_BROWSERS[$((choice - 1))]}")
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
}

MODE="interactive"
REQUESTED_BROWSER=""
while (($#)); do
  case "$1" in
    --all)
      MODE="all"
      shift
      ;;
    --browser)
      if (($# < 2)); then
        echo "Falta el ID después de --browser." >&2
        usage >&2
        exit 2
      fi
      MODE="browser"
      REQUESTED_BROWSER="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Opción desconocida: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "${HOME:-}" ]]; then
  echo "La variable HOME no está definida." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Se necesita Python 3 para generar y fusionar los archivos JSON." >&2
  echo "En Arch Linux: sudo pacman -S python" >&2
  exit 1
fi

if ! command -v node >/dev/null 2>&1 || ! command -v npx >/dev/null 2>&1; then
  echo "Se necesita Node.js 20 o superior y npx." >&2
  echo "En Arch Linux: sudo pacman -S nodejs npm" >&2
  exit 1
fi

NODE_MAJOR="$(node -p 'Number(process.versions.node.split(".")[0])' 2>/dev/null || echo 0)"
if [[ ! "$NODE_MAJOR" =~ ^[0-9]+$ ]] || ((NODE_MAJOR < 20)); then
  echo "Playwright MCP requiere Node.js 20 o superior. Versión detectada: $(node --version 2>/dev/null || echo desconocida)" >&2
  exit 1
fi

detect_browsers
select_browsers "$MODE" "$REQUESTED_BROWSER"

PY_ARGS=("$CONFIG_DIR" "$OPENCODE_DIR" "$(command -v npx)" "$SCRIPT_DIR/firefox-highlight.js")
for id in "${SELECTED_BROWSERS[@]}"; do
  PY_ARGS+=("${id}=${BROWSER_PATHS[$id]}")
done

python3 - "${PY_ARGS[@]}" <<'PY'
import datetime
import json
import os
import re
import shutil
import sys
import tempfile
from pathlib import Path

config_dir = Path(sys.argv[1]).expanduser()
opencode_dir = Path(sys.argv[2]).expanduser()
npx_path = sys.argv[3]
script_source = Path(sys.argv[4]).expanduser()
selected = []

browser_definitions = {
    "firefox": {"label": "Mozilla Firefox", "engine": "firefox"},
    "brave": {"label": "Brave Browser", "engine": "chromium"},
    "opera": {"label": "Opera", "engine": "chromium"},
    "chrome": {"label": "Google Chrome", "engine": "chromium"},
    "chromium": {"label": "Chromium", "engine": "chromium"},
}

for item in sys.argv[5:]:
    if "=" not in item:
        raise SystemExit(f"Argumento interno no válido: {item!r}")
    browser_id, executable = item.split("=", 1)
    if browser_id not in browser_definitions:
        raise SystemExit(f"Navegador desconocido: {browser_id}")
    selected.append((browser_id, executable))

if not selected:
    raise SystemExit("No se seleccionó ningún navegador.")

# OpenCode accepts JSONC. Remove comments and trailing commas before parsing;
# the original file is backed up before the normalized JSON is written.
def strip_jsonc(source: str) -> str:
    output = []
    i = 0
    in_string = False
    escaped = False
    while i < len(source):
        ch = source[i]
        nxt = source[i + 1] if i + 1 < len(source) else ""
        if in_string:
            output.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            output.append(ch)
            i += 1
            continue
        if ch == "/" and nxt == "/":
            i += 2
            while i < len(source) and source[i] not in "\r\n":
                i += 1
            continue
        if ch == "/" and nxt == "*":
            i += 2
            while i + 1 < len(source) and source[i:i + 2] != "*/":
                if source[i] in "\r\n":
                    output.append(source[i])
                i += 1
            i += 2
            continue
        output.append(ch)
        i += 1
    cleaned = "".join(output)
    # JSONC permits trailing commas. This only removes commas immediately
    # before a closing brace/bracket; commas inside strings are untouched.
    result = []
    i = 0
    in_string = False
    escaped = False
    while i < len(cleaned):
        ch = cleaned[i]
        if in_string:
            result.append(ch)
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            result.append(ch)
            i += 1
            continue
        if ch == ",":
            j = i + 1
            while j < len(cleaned) and cleaned[j].isspace():
                j += 1
            if j < len(cleaned) and cleaned[j] in "}]":
                i += 1
                continue
        result.append(ch)
        i += 1
    return "".join(result)

opencode_dir.mkdir(parents=True, exist_ok=True)
config_dir.mkdir(parents=True, exist_ok=True)

# Copy the click-highlight script next to the generated configs so that every
# installed browser can reference it with a relative "initScript" path.
if not script_source.is_file():
    raise SystemExit(f"No se encontró el script de resaltado: {script_source}")
shutil.copy2(script_source, config_dir / "firefox-highlight.js")

# Prefer the JSON file if it exists; otherwise support an existing JSONC file.
json_path = opencode_dir / "opencode.json"
jsonc_path = opencode_dir / "opencode.jsonc"
opencode_file = json_path if json_path.exists() or not jsonc_path.exists() else jsonc_path

if opencode_file.exists():
    raw = opencode_file.read_text(encoding="utf-8")
    try:
        opencode_config = json.loads(strip_jsonc(raw))
    except Exception as exc:
        raise SystemExit(
            f"No se pudo interpretar {opencode_file}: {exc}\n"
            "No se modificó el archivo. Revisa el JSON/JSONC manualmente."
        )
    if not isinstance(opencode_config, dict):
        raise SystemExit("La raíz de la configuración de OpenCode debe ser un objeto JSON.")
else:
    opencode_config = {"$schema": "https://opencode.ai/config.json"}

mcp = opencode_config.setdefault("mcp", {})
if not isinstance(mcp, dict):
    raise SystemExit("La propiedad 'mcp' existente no es un objeto; no se modificó la configuración.")

servers = mcp.setdefault("servers", {})
if not isinstance(servers, dict):
    raise SystemExit("La propiedad 'mcp.servers' existente no es un objeto; no se modificó la configuración.")

# Migrate legacy OpenCode v1 MCP entries from mcp.<name> to mcp.servers.<name>.
for old_name, old_value in list(mcp.items()):
    if old_name in {"servers", "timeout"}:
        continue
    if isinstance(old_value, dict) and old_value.get("type") in {"local", "remote"}:
        servers.setdefault(old_name, old_value)
        del mcp[old_name]

# Replace only OmniBrowser's own entries, preserving unrelated MCP servers.
for name in list(servers):
    if name.startswith("omnibrowser-") or name == "firefox-playwright":
        del servers[name]

for browser_id, executable in selected:
    definition = browser_definitions[browser_id]
    config_path = config_dir / f"mcp-{browser_id}-config.json"
    browser_config = {
        "browser": {
            "browserName": definition["engine"],
            "launchOptions": {"headless": False},
            # Cuadro de luz rojo alrededor de cada click/campo (firefox-highlight.js).
            "initScript": ["firefox-highlight.js"],
        }
    }

    # Playwright ships a patched Firefox build; use its managed Firefox engine.
    # Chromium-family browsers can be launched through the detected system binary.
    if definition["engine"] == "chromium":
        browser_config["browser"]["launchOptions"]["executablePath"] = executable

    config_path.write_text(
        json.dumps(browser_config, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )

    server_name = f"omnibrowser-{browser_id}"
    servers[server_name] = {
        "type": "local",
        "command": [npx_path, "-y", "@playwright/mcp@latest", "--config", str(config_path)],
        "timeout": {"startup": 60000, "catalog": 30000},
    }

opencode_config.setdefault("$schema", "https://opencode.ai/config.json")

# Back up the actual OpenCode config before replacing it.
if opencode_file.exists():
    timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    backup = opencode_file.with_name(f"{opencode_file.name}.bak-{timestamp}")
    shutil.copy2(opencode_file, backup)
    print(f"Respaldo creado: {backup}")

# Atomic write: a failed write cannot leave a truncated opencode.json.
fd, temp_name = tempfile.mkstemp(prefix=".opencode-omnibrowser-", dir=str(opencode_dir))
try:
    with os.fdopen(fd, "w", encoding="utf-8") as handle:
        json.dump(opencode_config, handle, indent=2, ensure_ascii=False)
        handle.write("\n")
    os.replace(temp_name, opencode_file)
except Exception:
    try:
        os.unlink(temp_name)
    except OSError:
        pass
    raise

print("\nOmniBrowser quedó configurado correctamente.")
print(f"Configuración MCP: {config_dir}")
print(f"OpenCode: {opencode_file}")
for browser_id, executable in selected:
    print(f"  - {browser_definitions[browser_id]['label']}: omnibrowser-{browser_id}")
    if browser_id != "firefox":
        print(f"    Ejecutable: {executable}")
PY

printf '\nListo. Reinicia OpenCode y verifica los servidores con /mcps.\n'
printf 'Para registrar todos los navegadores detectados: ./install.sh --all\n'
