# OpenCode Firefox MCP Automation

<p align="center">
  <img src="logo.png" alt="OpenCode Firefox MCP Logo" width="200" height="200">
</p>

Este repositorio contiene la configuración y scripts necesarios para habilitar el control autónomo de navegadores mediante Mozilla Firefox en un entorno Linux, utilizando el Model Context Protocol (MCP) de OpenCode.

## Estructura del repositorio

```opencode-firefox-ide-automation/
├── opencode.example.json       # Plantilla de configuración MCP (ejemplo)
├── mcp-firefox-config.json     # Configuración del motor de Firefox
└── install.sh                  # Script de instalación automática
```

## Requisitos previos

1. **Node.js y npx**: Asegúrate de tener Node.js instalado (versión 12.2.0 o superior) y que `npx` esté disponible en tu entorno.
2. **Acceso a la terminal**: Necesario para ejecutar los comandos de instalación.

## Instrucciones de instalación

1. **Clonar o descargar** este repositorio en tu carpeta de Descargas:
   ```bash
   # Si estás clonando desde GitHub:
   git clone https://github.com/tu-usuario/opencode-firefox-ide-automation.git ~/Descargas/opencode-firefox-ide-automation
   ```

2. **Ejecutar el script de instalación**:
   ```bash
   cd ~/Descargas/opencode-firefox-ide-automation
   chmod +x install.sh
   ./install.sh
   ```

3. **Verificar la instalación**:
   ```bash
   # Verificar que los archivos están en ~/.config/opencode/
   ls -la ~/.config/opencode/
   ```

4. **Iniciar el servidor MCP de Firefox** (opcional):
   ```bash
   npx -y @playwright/mcp@latest --config ~/.config/opencode/mcp-firefox-config.json
   ```

## Cómo funciona

- **Firefox MCP Server**: Utiliza Playwright con el motor Gecko de Firefox para controlar navegadores web de forma autónoma.
- **Integración con OpenCode**: El servidor MCP se conecta a OpenCode mediante el comando especificado en `opencode.json`.
- **VSCodium Runner**: Complementario que permite ejecutar comandos en un entorno VS Code-like.
- Ejecución robusta (-y y rutas dinámicas): Se incorpora la bandera -y en npx para evitar interrupciones de confirmación y el instalador gestiona dinámicamente las rutas absolutas ($HOME) en Linux.

## ¿Por qué usar Firefox en lugar de Chromium?

- **Privacidad mejorada**: Firefox es conocido por sus fuertes características de privacidad y bloqueo de rastreadores.
- **Compatibilidad**: Funciona bien en entornos Linux sin dependencias adicionales de Microsoft.
- **Open Source**: Firefox es 100% open source y está mantenido por la comunidad.

## Soporte y mantenimiento

Este repositorio se mantendrá actualizado con las mejores prácticas de seguridad y compatibilidad. Si encuentras algún problema o tienes sugerencias, por favor abre un issue en la página de GitHub del repositorio.

## Licencia

Este proyecto está licenciado bajo la licencia MIT. Consulta el archivo `LICENSE` para más detalles.
