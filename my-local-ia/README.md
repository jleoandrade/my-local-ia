# my-local-ia

Local AI for your own server: [Open WebUI](https://github.com/open-webui/open-webui) + [Ollama](https://ollama.com), installed in one guided step, with hardware-aware features on the way (model catalog with speed estimates for your GPU, side-by-side simulator, disk monitoring).

| | English | Português | Español |
|---|---|---|---|
| Installation | [INSTALL](docs/en/INSTALL.md) | [Instalação](docs/pt-BR/INSTALL.md) | [Instalación](docs/es/INSTALL.md) |
| Troubleshooting | [TROUBLESHOOTING](docs/en/TROUBLESHOOTING.md) | [Solução de problemas](docs/pt-BR/TROUBLESHOOTING.md) | [Solución de problemas](docs/es/TROUBLESHOOTING.md) |

## Installers

| System | File | Run |
|---|---|---|
| Linux | [`install/install-my-local-ia.sh`](install/install-my-local-ia.sh) | `sudo bash /tmp/install-my-local-ia.sh` |
| Windows 10/11 | [`install/install-my-local-ia.ps1`](install/install-my-local-ia.ps1) | `powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1` |

Both installers speak English, Portuguese and Spanish, show every step, ask before changing anything, and offer: install, update or switch version (official Open WebUI ↔ my-local-ia), verify, backup, restore, reset a password and uninstall. Default port: **4000**. Add `--dry-run` (Linux) or `-DryRun` (Windows) to see what they would do without changing anything.

## License

my-local-ia is based on Open WebUI and follows the [Open WebUI License](../LICENSE): the "Open WebUI" name and logo stay in the interface, except for deployments with up to 50 users in a 30-day period (or with written permission / an enterprise license).
