<#
.SYNOPSIS
    OmniBrowser - instalador de MCP para OpenCode y Claude en Windows.

.DESCRIPTION
    Detecta los navegadores en las rutas estándar de Windows (Program Files,
    AppData\Local, etc.), genera las configuraciones de Playwright MCP con el
    cursor fantasma morado y registra los servidores en OpenCode
    (~/.config/opencode/opencode.json) y, opcionalmente, en Claude Desktop
    (%APPDATA%\Claude\claude_desktop_config.json).

.PARAMETER Browser
    Configura un navegador específico: firefox, brave, opera, chrome o chromium.

.PARAMETER All
    Registra todos los navegadores detectados.

.PARAMETER Claude
    También registra los servidores en Claude Desktop e imprime el comando
    para Claude Code.

.PARAMETER Help
    Muestra esta ayuda.

.EXAMPLE
    .\install.ps1
.EXAMPLE
    .\install.ps1 -All -Claude
.EXAMPLE
    .\install.ps1 -Browser brave
#>
[CmdletBinding()]
param(
    [ValidateSet('firefox', 'brave', 'opera', 'chrome', 'chromium')]
    [string]$Browser,
    [switch]$All,
    [switch]$Claude,
    [switch]$Help
)

Set-StrictMode -Version Latest

if ($PSVersionTable.PSVersion.Major -lt 6) {
    Write-Error "Este instalador requiere PowerShell 7 o superior (instalado: $($PSVersionTable.PSVersion)). Instálalo con: winget install Microsoft.PowerShell"
    exit 1
}

$ErrorActionPreference = 'Stop'

$Labels = @{
    firefox  = 'Mozilla Firefox'
    brave    = 'Brave Browser'
    opera    = 'Opera'
    chrome   = 'Google Chrome'
    chromium = 'Chromium'
}

function Show-Usage {
    Write-Host @'
OmniBrowser - instalador de MCP para Windows

Uso:
  .\install.ps1                 Detecta navegadores y muestra un menú si hay varios
  .\install.ps1 -All            Registra todos los navegadores detectados
  .\install.ps1 -Browser brave  Configura un navegador específico
  .\install.ps1 -Claude         También configura Claude Desktop / Claude Code
  .\install.ps1 -Help           Muestra esta ayuda

IDs aceptados: firefox, brave, opera, chrome, chromium

Nota de ejecución:
  pwsh -ExecutionPolicy Bypass -File .\install.ps1
'@
}

if ($Help) {
    Show-Usage
    exit 0
}

if ($All -and $Browser) {
    Write-Error "Usa -All o -Browser, no ambos."
    exit 2
}

$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) { $ScriptDir = (Get-Location).Path }

# --- Rutas de configuración de los clientes -------------------------------
$OpencodeDir = Join-Path $HOME '.config\opencode'
$ConfigDir = Join-Path $OpencodeDir 'omnibrowser'
$ClaudeConfigPath = if ($env:APPDATA) { Join-Path $env:APPDATA 'Claude\claude_desktop_config.json' } else { $null }

# --- Requisitos: Node.js 20+ y npx ---------------------------------------
$npxCmd = Get-Command npx.cmd -ErrorAction SilentlyContinue
if (-not $npxCmd) { $npxCmd = Get-Command npx -ErrorAction SilentlyContinue }
if (-not $npxCmd) {
    Write-Error "No se encontró npx. Instala Node.js 20 o superior: winget install OpenJS.NodeJS.LTS"
    exit 1
}
$npx = $npxCmd.Source

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Error "No se encontró node. Instala Node.js 20 o superior: winget install OpenJS.NodeJS.LTS"
    exit 1
}
$nodeMajor = & node -p 'Number(process.versions.node.split(".")[0])'
if (-not ($nodeMajor -match '^\d+$') -or [int]$nodeMajor -lt 20) {
    Write-Error "Playwright MCP requiere Node.js 20 o superior. Detectado: $(node --version)"
    exit 1
}

# --- Detección de navegadores en rutas estándar de Windows ----------------
function Find-Browser {
    param([string]$Id, [string[]]$Candidates)
    foreach ($path in $Candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) { return $path }
    }
    $cmd = Get-Command $Id -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    return $null
}

$pf = $env:ProgramFiles
$pf86 = ${env:ProgramFiles(x86)}
$local = $env:LOCALAPPDATA

$Detected = [ordered]@{
    firefox   = Find-Browser 'firefox' @(
        "$pf\Mozilla Firefox\firefox.exe",
        "$pf86\Mozilla Firefox\firefox.exe"
    )
    brave     = Find-Browser 'brave' @(
        "$local\BraveSoftware\Brave-Browser\Application\brave.exe",
        "$pf\BraveSoftware\Brave-Browser\Application\brave.exe"
    )
    opera     = Find-Browser 'opera' @(
        "$local\Programs\Opera\opera.exe",
        "$local\Programs\Opera GX\opera.exe",
        "$pf\Opera\opera.exe"
    )
    chrome    = Find-Browser 'chrome' @(
        "$pf\Google\Chrome\Application\chrome.exe",
        "$pf86\Google\Chrome\Application\chrome.exe",
        "$local\Google\Chrome\Application\chrome.exe"
    )
    chromium  = Find-Browser 'chromium' @(
        "$local\Chromium\Application\chrome.exe",
        "$pf\Chromium\Application\chrome.exe"
    )
}

$FoundIds = @($Detected.Keys | Where-Object { $Detected[$_] })

if ($FoundIds.Count -eq 0) {
    Write-Error "No se detectó Firefox, Brave, Opera, Google Chrome ni Chromium. Instala uno o asegúrate de que esté en PATH."
    exit 1
}

# --- Selección ------------------------------------------------------------
$Selected = @()
if ($All) {
    $Selected = $FoundIds
}
elseif ($Browser) {
    if ($FoundIds -notcontains $Browser) {
        Write-Error "El navegador '$Browser' no está instalado. Detectados: $($FoundIds -join ', ')"
        exit 1
    }
    $Selected = @($Browser)
}
elseif ($FoundIds.Count -eq 1) {
    $Selected = $FoundIds
    Write-Host "Se detectó un navegador: $($Labels[$FoundIds[0]])"
}
else {
    Write-Host "Navegadores detectados:"
    for ($i = 0; $i -lt $FoundIds.Count; $i++) {
        $id = $FoundIds[$i]
        Write-Host ("  {0}) {1} ({2})" -f ($i + 1), $Labels[$id], $Detected[$id])
    }
    $choice = Read-Host "Selecciona el navegador que quieres vincular con MCP [1-$($FoundIds.Count)]"
    if ($choice -notmatch '^\d+$' -or [int]$choice -lt 1 -or [int]$choice -gt $FoundIds.Count) {
        Write-Error "Selección no válida. No se realizaron cambios."
        exit 1
    }
    $Selected = @($FoundIds[[int]$choice - 1])
}

# --- Generación de configs (con cursor fantasma) --------------------------
$CursorScript = Join-Path $ScriptDir 'ghost-cursor.js'
if (-not (Test-Path -LiteralPath $CursorScript)) {
    Write-Error "No se encontró ghost-cursor.js junto a install.ps1: $CursorScript"
    exit 1
}

New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
Copy-Item -LiteralPath $CursorScript -Destination (Join-Path $ConfigDir 'ghost-cursor.js') -Force

function Write-Json {
    param([string]$Path, [object]$Data)
    $temp = "$Path.tmp"
    $json = $Data | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($temp, $json, [System.Text.UTF8Encoding]::new($false))
    Move-Item -LiteralPath $temp -Destination $Path -Force
}

function Backup-File {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
    Copy-Item -LiteralPath $Path -Destination "$Path.bak-$stamp"
    Write-Host "  Respaldo creado: $Path.bak-$stamp"
}

$ConfigPaths = @{}
foreach ($id in $Selected) {
    $cfgPath = Join-Path $ConfigDir "mcp-$id-config.json"
    if ($id -eq 'firefox') {
        # Playwright trae su propio Firefox; no se necesita executablePath.
        $config = [ordered]@{
            browser = [ordered]@{
                browserName    = 'firefox'
                launchOptions  = [ordered]@{ headless = $false }
                initScript     = @('ghost-cursor.js')
            }
        }
    }
    else {
        $config = [ordered]@{
            browser = [ordered]@{
                browserName    = 'chromium'
                launchOptions  = [ordered]@{
                    executablePath = $Detected[$id]
                    headless       = $false
                }
                initScript     = @('ghost-cursor.js')
            }
        }
    }
    Write-Json -Path $cfgPath -Data $config
    $ConfigPaths[$id] = $cfgPath
}

# Lee un JSON (admite JSONC) y exige un objeto como raíz.
function Read-JsonConfig {
    param([string]$Path)
    $rawText = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($rawText)) {
        Write-Error "No se pudo interpretar ${Path}: el archivo está vacío. No se modificó." -ErrorAction Continue
        exit 1
    }
    if ($rawText.TrimStart().StartsWith('[')) {
        Write-Error "No se pudo interpretar ${Path}: la raíz debe ser un objeto JSON, no una lista. No se modificó." -ErrorAction Continue
        exit 1
    }
    try {
        $data = $rawText | ConvertFrom-Json -AsHashtable
    }
    catch {
        Write-Error "No se pudo interpretar $Path. No se modificó el archivo. Corrígelo manualmente y vuelve a ejecutar." -ErrorAction Continue
        exit 1
    }
    if ($data -isnot [hashtable]) {
        Write-Error "No se pudo interpretar ${Path}: la raíz debe ser un objeto JSON. No se modificó." -ErrorAction Continue
        exit 1
    }
    return $data
}

# --- Registro en OpenCode -------------------------------------------------
if (-not (Test-Path -LiteralPath $OpencodeDir)) {
    New-Item -ItemType Directory -Force -Path $OpencodeDir | Out-Null
}

$OpenCodeFile = $null
foreach ($name in @('opencode.json', 'opencode.jsonc')) {
    $candidate = Join-Path $OpencodeDir $name
    if (Test-Path -LiteralPath $candidate) { $OpenCodeFile = $candidate; break }
}
if (-not $OpenCodeFile) { $OpenCodeFile = Join-Path $OpencodeDir 'opencode.json' }

$openCodeConfig = @{}
if (Test-Path -LiteralPath $OpenCodeFile) {
    $openCodeConfig = Read-JsonConfig -Path $OpenCodeFile
    Backup-File -Path $OpenCodeFile
}

if (-not $openCodeConfig.ContainsKey('mcp')) { $openCodeConfig['mcp'] = @{} }
$mcp = $openCodeConfig['mcp']
if ($mcp -isnot [hashtable]) {
    Write-Error "La propiedad 'mcp' existente no es un objeto; no se modificó la configuración."
    exit 1
}
$servers = if ($mcp.ContainsKey('servers')) { $mcp['servers'] } else { @{} }
if ($servers -isnot [hashtable]) {
    Write-Error "La propiedad 'mcp.servers' existente no es un objeto; no se modificó el archivo. Corrígelo manualmente y vuelve a ejecutar." -ErrorAction Continue
    exit 1
}

# Migración de entradas antiguas (formato v1 directamente en "mcp").
foreach ($key in @($mcp.Keys)) {
    if ($key -in @('servers', 'timeout')) { continue }
    $value = $mcp[$key]
    if ($value -is [hashtable] -and $value.ContainsKey('type') -and $value['type'] -in @('local', 'remote')) {
        if (-not $servers.ContainsKey($key)) { $servers[$key] = $value }
        $mcp.Remove($key)
    }
}

# Sustituye solo las entradas administradas por OmniBrowser.
foreach ($key in @($servers.Keys)) {
    if ($key.StartsWith('omnibrowser-') -or $key -eq 'firefox-playwright') {
        $servers.Remove($key)
    }
}

foreach ($id in $Selected) {
    $servers["omnibrowser-$id"] = [ordered]@{
        type    = 'local'
        command = @($npx, '-y', '@playwright/mcp@latest', '--config', $ConfigPaths[$id])
        timeout = [ordered]@{ startup = 60000; catalog = 30000 }
    }
}

$mcp['servers'] = $servers
$openCodeConfig['mcp'] = $mcp
if (-not $openCodeConfig.ContainsKey('$schema')) {
    $openCodeConfig['$schema'] = 'https://opencode.ai/config.json'
}

Write-Json -Path $OpenCodeFile -Data $openCodeConfig
Write-Host "`nOpenCode: $OpenCodeFile"

# --- Registro opcional en Claude ------------------------------------------
if ($Claude) {
    if (-not $ClaudeConfigPath) {
        Write-Host "No se encontró %APPDATA%; no se configuró Claude Desktop."
    }
    else {
        $claudeData = @{}
        if (Test-Path -LiteralPath $ClaudeConfigPath) {
            $claudeData = Read-JsonConfig -Path $ClaudeConfigPath
            Backup-File -Path $ClaudeConfigPath
        }
        else {
            New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ClaudeConfigPath) | Out-Null
            Write-Host "  Se creó $ClaudeConfigPath"
        }

        $mcpServers = if ($claudeData.ContainsKey('mcpServers')) { $claudeData['mcpServers'] } else { @{} }
        if ($mcpServers -isnot [hashtable]) {
            Write-Error "La propiedad 'mcpServers' existente no es un objeto; no se modificó el archivo. Corrígelo manualmente y vuelve a ejecutar." -ErrorAction Continue
            exit 1
        }

        # Sustituye solo las entradas administradas por OmniBrowser.
        foreach ($key in @($mcpServers.Keys)) {
            if ($key.StartsWith('omnibrowser-') -or $key -eq 'firefox-playwright') {
                $mcpServers.Remove($key)
            }
        }

        foreach ($id in $Selected) {
            $mcpServers["omnibrowser-$id"] = [ordered]@{
                command = $npx
                args    = @('-y', '@playwright/mcp@latest', '--config', $ConfigPaths[$id])
            }
        }

        $claudeData['mcpServers'] = $mcpServers
        Write-Json -Path $ClaudeConfigPath -Data $claudeData
        Write-Host "Claude Desktop: $ClaudeConfigPath"
    }

    Write-Host "`nPara Claude Code, registra el servidor con (por navegador):"
    foreach ($id in $Selected) {
        Write-Host "  claude mcp add omnibrowser-$id -- npx -y @playwright/mcp@latest --config `"$($ConfigPaths[$id])`""
    }
}

# --- Resumen --------------------------------------------------------------
Write-Host "`nOmniBrowser quedó configurado correctamente."
Write-Host "Configuración MCP: $ConfigDir"
foreach ($id in $Selected) {
    Write-Host "  - $($Labels[$id]): omnibrowser-$id"
    if ($id -ne 'firefox') { Write-Host "    Ejecutable: $($Detected[$id])" }
}
Write-Host "`nReinicia OpenCode o Claude Desktop y verifica la conexión con /mcps (OpenCode) o el icono de MCP (Claude)."
