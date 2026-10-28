# my-local-ia changelog

Every version has a GitHub tag (`v1.0`, `v1.1`…) and, from 2.1 on, a pinned image on GHCR that never changes. To install an older version, use its image instead of `:cuda` (or `:main` without a GPU).

Also in [Português](CHANGELOG.pt-BR.md) and [Español](CHANGELOG.es.md).

| Version | Date       | Highlight                                        | Pinned image (GPU)                                                                  |
| ------- | ---------- | ------------------------------------------------ | ----------------------------------------------------------------------------------- |
| 3.3     | 2026-10-28 | Installer: optimize Ollama and unlock the GPU    | `ghcr.io/jleoandrade/my-local-ia:cuda` (current)                                    |
| 3.2     | 2026-10-25 | Catalog balanced across the ratings              | `ghcr.io/jleoandrade/my-local-ia:git-278c83b45ec47bb703c8329d9261e25c04d183b2-cuda` |
| 3.1     | 2026-10-25 | Ollama library reader fixed                      | `ghcr.io/jleoandrade/my-local-ia:git-957b2b26c7c5bc3c71fba902cb4c4a84d69f7733-cuda` |
| 3.0     | 2026-10-25 | Ollama library, background downloads, Help       | `ghcr.io/jleoandrade/my-local-ia:git-153c03666fd4e687524cca1dcd0eab07a7f0a54d-cuda` |
| 2.2     | 2026-10-25 | Automatic tool mode and hardware re-detection    | `ghcr.io/jleoandrade/my-local-ia:git-c61159e117912d25f3ac8d0f710b3aff7a0c561f-cuda` |
| 2.1     | 2026-10-25 | Build the image on the server itself             | `ghcr.io/jleoandrade/my-local-ia:git-a9d22996ccc7029d428a1e86664729b612dcb5f5-cuda` |
| 2.0     | 2026-10-25 | Every my-local-ia screen                         | — (no image of its own)                                                             |
| 1.1     | 2026-10-25 | Image built by GitHub Actions                    | —                                                                                   |
| 1.0     | 2026-10-24 | Installers, documentation and the catalog's base | — (installed the official Open WebUI)                                               |

## 3.3 — Optimize Ollama and unlock the GPU

- Linux installer, option **8) Optimize Ollama**: turns on `OLLAMA_FLASH_ATTENTION=1` and `OLLAMA_KV_CACHE_TYPE=q8_0` in a service drop-in of its own; a conversation takes about half the GPU memory. Run it again to undo.
- Option **9) Unlock the GPU tensor cores**: installs gpu-unlock (GeForce RTX 20/30/40), turns it on in GRUB keeping a copy of the old file, and explains Proxmox's `pcie=1` setting when the GPU does not arrive as PCIe. Run it again to see its state or undo it.
- **3) Verify** and its report show the state of both improvements.
- Installation and troubleshooting guides, Help page and manual updated.

## 3.2 — Balanced catalog

- The robot splits its slots by rating on this server: 40% runs smoothly, 30% usable, 22% heavy and 8% won't run. Slots a rating cannot fill go to usable, heavy, smooth and won't run, in that order.
- Before, on a 12 GB GPU, nearly everything came as runs smoothly (349 against 7 usable).

## 3.1 — Ollama library fixed

- The ollama.com page did not have the markers the robot looked for. Names now come from the `/library/<name>` links and sizes from the official Ollama registry, with the exact download size.
- Pull counts ("40M") are no longer mistaken for sizes ("40m").
- The robot status says so when it finds names but cannot read sizes.

## 3.0 — Bigger catalog, background downloads and Help

- **Robot**: also reads the official Ollama library (every size of every model) and more Hugging Face publishers; keeps up to 300 models without duplicating the hand-picked ones. It runs right after every update.
- **"Fits this server" filter** on by default (runs smoothly and usable).
- **Background downloads**: closing the window or changing pages no longer stops them; everyone sees the progress under the disk meter, with a cancel option.
- **Help page** (button at the top of the my-local-ia pages and in the user menu) about Open WebUI, Ollama and my-local-ia, in three languages, with search and screenshots.
- User manual in Word (English, Portuguese and Spanish).

## 2.2 — Tools and hardware

- Models that cannot call tools (qwen2.5-coder, the ones under 4B and the ones without support) no longer get Open WebUI's tools: they used to answer with a block of JSON.
- Hardware is detected again at every start and checked every few minutes; "Detect again" says what changed.

## 2.1 — Build on the server

- The installers can build the image on the server itself (no GitHub Actions needed), with backup and automatic rollback.
- The original project's publishing workflows are disabled in the fork.

## 2.0 — my-local-ia features

- "Does it run on my GPU?" catalog with ratings for this hardware and "Best for this server".
- Warning in the model selector, "Before sending" notice, simulator for up to 3 models.
- Disk space for everyone, with alerts (banner and webhook), forecast and removal suggestions.
- Downloads for every user, with a disk check and alternatives.
- Administrator settings and the robot for new models (Hugging Face).
- Interface in English, Portuguese and Spanish.

## 1.1 — Image on GitHub Actions

- Workflow that builds the `cuda` and `main` images at `ghcr.io/<user>/my-local-ia`.

## 1.0 — Base

- Installers for Linux (bash) and Windows (PowerShell) in three languages: install, update, verify, backup, restore, reset a password and uninstall. Port 4000, local network only.
- Installation and troubleshooting documentation in English, Portuguese and Spanish.
- Hardware detection, speed estimates and the model catalog (first phase).
