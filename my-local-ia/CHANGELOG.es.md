# Historial de versiones de my-local-ia

Cada versión tiene una etiqueta en GitHub (`v1.0`, `v1.1`…) y, desde la 2.1, una imagen fija en GHCR que nunca cambia. Para instalar una versión antigua, usa su imagen en lugar de `:cuda` (o `:main`, sin GPU).

También en [English](CHANGELOG.md) y [Português](CHANGELOG.pt-BR.md).

| Versión | Fecha      | Lo más importante                                             | Imagen fija (GPU)                                                                   |
| ------- | ---------- | ------------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 3.3     | 28/10/2026 | Instalador: optimizar Ollama y desbloquear la GPU             | `ghcr.io/jleoandrade/my-local-ia:cuda` (actual)                                     |
| 3.2     | 25/10/2026 | Catálogo equilibrado entre las notas                          | `ghcr.io/jleoandrade/my-local-ia:git-278c83b45ec47bb703c8329d9261e25c04d183b2-cuda` |
| 3.1     | 25/10/2026 | Lectura de la biblioteca de Ollama corregida                  | `ghcr.io/jleoandrade/my-local-ia:git-957b2b26c7c5bc3c71fba902cb4c4a84d69f7733-cuda` |
| 3.0     | 25/10/2026 | Biblioteca de Ollama, descargas en segundo plano, Ayuda       | `ghcr.io/jleoandrade/my-local-ia:git-153c03666fd4e687524cca1dcd0eab07a7f0a54d-cuda` |
| 2.2     | 25/10/2026 | Modo de herramientas automático y nueva detección de hardware | `ghcr.io/jleoandrade/my-local-ia:git-c61159e117912d25f3ac8d0f710b3aff7a0c561f-cuda` |
| 2.1     | 25/10/2026 | Compilar la imagen en el propio servidor                      | `ghcr.io/jleoandrade/my-local-ia:git-a9d22996ccc7029d428a1e86664729b612dcb5f5-cuda` |
| 2.0     | 25/10/2026 | Todas las pantallas de my-local-ia                            | — (sin imagen propia)                                                               |
| 1.1     | 25/10/2026 | Imagen generada por GitHub Actions                            | —                                                                                   |
| 1.0     | 24/10/2026 | Instaladores, documentación y base del catálogo               | — (instalaba el Open WebUI oficial)                                                 |

## 3.3 — Optimizar Ollama y desbloquear la GPU

- Instalador para Linux, opción **8) Optimizar Ollama**: activa `OLLAMA_FLASH_ATTENTION=1` y `OLLAMA_KV_CACHE_TYPE=q8_0` en un archivo propio del servicio; una conversación ocupa cerca de la mitad de la memoria de la GPU. Al ejecutarla de nuevo, lo deshace.
- Opción **9) Desbloquear los tensor cores de la GPU**: instala gpu-unlock (GeForce RTX 20/30/40), lo activa en GRUB guardando una copia del archivo anterior y explica el ajuste `pcie=1` de Proxmox cuando la GPU no llega como PCIe. Al ejecutarla de nuevo, muestra su estado y lo deshace.
- **3) Verificar** y su informe muestran el estado de las dos mejoras.
- Guías de instalación y solución de problemas, página de Ayuda y manual actualizados.

## 3.2 — Catálogo equilibrado

- El robot reparte sus espacios por nota en este servidor: 40% Va fluido, 30% Usable, 22% Pesado y 8% No funciona. Los espacios que una nota no llena pasan a Usable, Pesado, Va fluido y No funciona, en ese orden.
- Antes, en una GPU de 12 GB, casi todo salía como Va fluido (349 contra 7 Usable).

## 3.1 — Biblioteca de Ollama corregida

- La página de ollama.com no tenía las marcas que buscaba el robot. Ahora los nombres salen de los enlaces `/library/<nombre>` y los tamaños del registro oficial de Ollama, con el tamaño exacto de cada descarga.
- Los conteos de descargas ("40M") ya no se confunden con tamaños ("40m").
- El estado del robot lo dice claramente cuando encuentra los nombres pero no puede leer los tamaños.

## 3.0 — Catálogo más grande, descargas en segundo plano y Ayuda

- **Robot**: lee también la biblioteca oficial de Ollama (todos los tamaños de cada modelo) y más perfiles de Hugging Face; guarda hasta 300 modelos sin duplicar los elegidos a mano. Se ejecuta justo después de cada actualización.
- **Filtro "Cabe en este servidor"** activado por defecto (Va fluido y Usable).
- **Descargas en segundo plano**: cerrar la ventana o cambiar de página ya no las detiene; todos ven el progreso debajo del medidor de disco, con opción de cancelar.
- **Página de Ayuda** (botón arriba de las páginas de my-local-ia y en el menú del usuario) sobre Open WebUI, Ollama y my-local-ia, en tres idiomas, con búsqueda e imágenes.
- Manual del usuario en Word (español, portugués e inglés).

## 2.2 — Herramientas y hardware

- Los modelos que no saben usar herramientas (qwen2.5-coder, los de menos de 4B y los sin soporte) ya no reciben las herramientas de Open WebUI: antes respondían con un bloque de JSON.
- El hardware se detecta de nuevo en cada inicio y se revisa cada pocos minutos; "Detectar de nuevo" dice qué cambió.

## 2.1 — Compilar en el servidor

- Los instaladores pueden compilar la imagen en el propio servidor (sin GitHub Actions), con copia de seguridad y vuelta automática.
- Los workflows de publicación del proyecto original quedan desactivados en el fork.

## 2.0 — Funciones de my-local-ia

- Catálogo "¿Funciona en mi GPU?" con las notas para este hardware y "Los mejores para este servidor".
- Aviso en el selector de modelos, cuadro "Antes de enviar", simulador de hasta 3 modelos.
- Espacio en disco para todos, con alertas (aviso y webhook), previsión y sugerencias para quitar.
- Descargas para todos los usuarios, con revisión del disco y alternativas.
- Ajustes del administrador y robot de modelos nuevos (Hugging Face).
- Interfaz en español, portugués e inglés.

## 1.1 — Imagen en GitHub Actions

- Workflow que genera las imágenes `cuda` y `main` en `ghcr.io/<usuario>/my-local-ia`.

## 1.0 — Base

- Instaladores para Linux (bash) y Windows (PowerShell) en tres idiomas: instalar, actualizar, verificar, copia de seguridad, restaurar, restablecer contraseña y desinstalar. Puerto 4000, solo red local.
- Documentación de instalación y solución de problemas en español, portugués e inglés.
- Detección de hardware, estimación de velocidad y el catálogo de modelos (primera fase).
