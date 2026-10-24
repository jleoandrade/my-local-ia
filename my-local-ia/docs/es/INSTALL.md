# my-local-ia — Guía de instalación

[English](../en/INSTALL.md) · [Português](../pt-BR/INSTALL.md) · Solución de problemas: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

Esta guía instala **my-local-ia** en un servidor que ya ejecuta **Ollama**. No necesitas saber Docker ni comandos de Linux más allá de copiar un archivo y ejecutar un comando: el instalador pregunta todo lo que necesita, muestra cada paso y pide confirmación antes de cambiar cualquier cosa.

---

## Contenido

1. [Qué se instala](#1-qué-se-instala)
2. [Requisitos](#2-requisitos)
3. [Antes de empezar: revisión de 2 minutos](#3-antes-de-empezar-revisión-de-2-minutos)
4. [Instalación en Linux](#4-instalación-en-linux)
5. [Instalación en Windows](#5-instalación-en-windows)
6. [Qué hace cada paso del instalador](#6-qué-hace-cada-paso-del-instalador)
7. [Primer acceso](#7-primer-acceso)
8. [El menú del instalador: actualizar, verificar, copia, restaurar, contraseña, desinstalar](#8-el-menú-del-instalador)
9. [Cambiar de la versión oficial a my-local-ia](#9-cambiar-de-la-versión-oficial-a-my-local-ia)
10. [Dónde se guarda todo](#10-dónde-se-guarda-todo)
11. [Modo simulación](#11-modo-simulación)
12. [Publicar en internet (más adelante)](#12-publicar-en-internet-más-adelante)
13. [Notas de seguridad](#13-notas-de-seguridad)
14. [Comandos útiles](#14-comandos-útiles)

---

## 1. Qué se instala

```
 Navegador (cualquier equipo de tu red)
        │  http://IP-DEL-SERVIDOR:4000
        ▼
 ┌──────────────────────────────┐
 │ my-local-ia (contenedor Docker)│ interfaz web, usuarios, chats, documentos
 │ imagen oficial de Open WebUI  │
 │ o la versión my-local-ia      │
 └──────────────┬───────────────┘
                │  http://127.0.0.1:11434
                ▼
 ┌──────────────────────────────┐
 │ Ollama (ya instalado)        │  ejecuta los modelos de IA
 └──────────────┬───────────────┘
                ▼
          GPU NVIDIA (VRAM)
```

- **my-local-ia** es la interfaz web. Se ejecuta dentro de un contenedor Docker llamado `my-local-ia` y guarda sus datos (usuarios, chats, ajustes, archivos subidos) en un volumen Docker llamado `my-local-ia-data`.
- **Ollama** sigue funcionando exactamente como está. El instalador nunca toca tus modelos.
- Hay dos versiones:
  - **Open WebUI oficial**: el proyecto original, recomendado mientras la versión my-local-ia no esté publicada.
  - **my-local-ia**: Open WebUI con las funciones de my-local-ia (catálogo de modelos según el hardware, simulador, monitoreo de disco…), generado desde tu repositorio en GitHub.

  Puedes cambiar de una a otra en cualquier momento con la opción **Actualizar**, sin perder datos.

> **Sobre la licencia.** my-local-ia se basa en Open WebUI. Su licencia exige mantener el nombre y el logo "Open WebUI" en la interfaz, excepto en instalaciones con hasta 50 usuarios en un período de 30 días (o con permiso por escrito / licencia enterprise).

---

## 2. Requisitos

### Servidor Linux (instalador: `install-my-local-ia.sh`)

| Elemento | Requisito |
|---|---|
| Sistema | Ubuntu 20.04 o posterior, Debian 11 o posterior y derivadas (Linux Mint, Pop!_OS…), Fedora, RHEL / Rocky / AlmaLinux / CentOS Stream 8 o posterior. 64 bits (x86_64). |
| Acceso | Un usuario que pueda usar `sudo`. |
| GPU | Tarjeta NVIDIA con el controlador instalado (`nvidia-smi` debe funcionar). Sin GPU también se instala, pero en modo CPU. |
| Ollama | Instalado y en ejecución en el mismo servidor. |
| Disco | Al menos **30 GB libres** (la imagen con GPU ocupa unos 6 GB; los modelos son aparte). |
| RAM | Mínimo 8 GB, recomendado 16 GB o más. |
| Internet | Necesario durante la instalación y las actualizaciones (para descargar Docker y la imagen). |

Docker y NVIDIA Container Toolkit **no necesitan estar instalados**: el instalador instala lo que falte (después de preguntar).

### Equipo Windows (instalador: `install-my-local-ia.ps1`)

| Elemento | Requisito |
|---|---|
| Sistema | Windows 10 versión 2004 (compilación 19041) o posterior, o Windows 11 — Home, Pro o Enterprise. **Windows Server no es compatible** (Docker Desktop no funciona en él). |
| Acceso | Una cuenta con permisos de administrador. |
| Virtualización | Activada en la BIOS/UEFI. Si Windows es una máquina virtual, la *virtualización anidada* debe estar activada en el hipervisor. |
| GPU | Tarjeta NVIDIA con el controlador de Windows actualizado. |
| Ollama | Ollama para Windows, instalado y en ejecución. |
| Disco | Al menos **30 GB libres** en C:. |
| Internet | Necesario durante la instalación y las actualizaciones. |

Docker Desktop y WSL 2 los instala el instalador si faltan (en ese caso Windows debe reiniciarse una vez).

> **Licencia de Docker Desktop:** gratis para uso personal, educación, código abierto y empresas con menos de 250 empleados **y** menos de US$ 10 millones de ingresos anuales. Las empresas más grandes necesitan una suscripción de pago. En Linux, Docker Engine no tiene esa restricción.

---

## 3. Antes de empezar: revisión de 2 minutos

En el servidor, confirma que la GPU y Ollama funcionan. Si algo falla, resuélvelo antes (consulta [TROUBLESHOOTING.md](TROUBLESHOOTING.md)).

**Linux**

```bash
nvidia-smi                      # debe mostrar tu GPU, p. ej. "NVIDIA GeForce RTX 3060 … 12288MiB"
ollama list                     # debe listar tus modelos (una lista vacía también sirve)
curl http://127.0.0.1:11434     # debe responder "Ollama is running"
```

**Windows** (PowerShell)

```powershell
nvidia-smi
ollama list
curl.exe http://127.0.0.1:11434
```

---

## 4. Instalación en Linux

### 4.1 Copia el instalador al servidor

Coloca `install-my-local-ia.sh` en la carpeta `/tmp` del servidor. Algunas formas:

- **Desde Windows, macOS o Linux con `scp`** (cambia `usuario` y `192.168.1.50`):

  ```bash
  scp install-my-local-ia.sh usuario@192.168.1.50:/tmp/
  ```

- **Desde Windows con WinSCP o FileZilla**: conéctate por SFTP al servidor y arrastra el archivo a `/tmp`.

> `/tmp` es solo el punto de partida del instalador. Todo lo importante se guarda fuera de él (consulta la [sección 10](#10-dónde-se-guarda-todo)), porque `/tmp` suele vaciarse cuando el servidor se reinicia.

### 4.2 (Recomendado) Usa `tmux` si estás conectado por SSH

Si la conexión SSH se cae en medio de la instalación, el instalador se detiene. `tmux` lo mantiene en ejecución:

```bash
sudo apt install -y tmux     # Ubuntu/Debian   (Fedora/RHEL: sudo dnf install -y tmux)
tmux new -s instalacion
```

Si la conexión se cae, vuelve a conectarte y ejecuta `tmux attach -t instalacion` para ver el instalador de nuevo.

### 4.3 Ejecuta el instalador

```bash
sudo bash /tmp/install-my-local-ia.sh
```

1. Elige el idioma (English, Português o Español).
2. Elige **1) Instalar**.
3. Responde las preguntas. Pulsa **Enter** para aceptar el valor entre corchetes, por ejemplo `Puerto de acceso a my-local-ia [4000]:`.
4. Al final, el instalador muestra la dirección que debes abrir en el navegador.

La instalación tarda de 5 a 20 minutos, sobre todo por la descarga de la imagen (varios GB) y el primer inicio.

---

## 5. Instalación en Windows

### 5.1 Copia el instalador

Crea la carpeta `C:\temp` y coloca `install-my-local-ia.ps1` en ella.

### 5.2 Abre PowerShell como administrador

Menú Inicio → escribe **PowerShell** → clic derecho en **Windows PowerShell** → **Ejecutar como administrador**.

### 5.3 Ejecuta el instalador

```powershell
powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1
```

`-ExecutionPolicy Bypass` permite ejecutar solo este script, sin cambiar la política de seguridad del equipo. Si Windows dice que el archivo viene de internet y está bloqueado, desbloquéalo antes:

```powershell
Unblock-File C:\temp\install-my-local-ia.ps1
```

Después elige el idioma y **1) Instalar**, como en Linux.

### 5.4 Qué cambia en Windows

- **WSL 2 y Docker Desktop.** Si faltan, el instalador los instala con `winget` y te pide **reiniciar Windows**. Después del reinicio, ejecuta el mismo comando y elige **Instalar**: continúa con las respuestas que ya diste.
- **Términos de Docker Desktop.** La primera vez que Docker Desktop se abre, muestra una ventana con sus términos. Acéptalos; el instalador espera hasta 5 minutos a que Docker esté listo.
- **Ollama y Docker.** Por defecto, Ollama en Windows solo acepta conexiones del propio equipo. Si el contenedor no puede conectarse, el instalador ofrece definir `OLLAMA_HOST=0.0.0.0:11434` para tu usuario y reiniciar Ollama.
- **Firewall y tipo de red.** El instalador crea una regla en el firewall de Windows para el puerto, válida para redes **Privadas** y de **Dominio**. Si Windows clasifica tu red como **Pública**, la regla no se aplica: cámbialo en *Configuración → Red e Internet → (tu conexión) → Red privada*.
- **Puerto dentro del contenedor.** En Windows, el contenedor escucha en el 8080 y Docker lo publica en el puerto que elijas (4000 por defecto). En Linux, escucha directamente en el puerto elegido.

---

## 6. Qué hace cada paso del instalador

La instalación tiene 11 pasos numerados. Todo lo que cambia el sistema se muestra (líneas que empiezan con `$` o `>`) y se confirma contigo antes.

| Paso | Qué ocurre | ¿Cambia el sistema? |
|---|---|---|
| 1. Revisando este servidor | Muestra sistema, procesador, RAM, disco libre, acceso a internet, GPU y controlador, Ollama (versión, cantidad de modelos, carpeta de modelos), Docker y la red (IP local o pública). | No |
| 2. Preguntas | Versión (oficial o my-local-ia), puerto (por defecto **4000**), dirección de Ollama, carpeta de modelos de Ollama. Luego un resumen y una confirmación. | Guarda tus respuestas |
| 3. Docker | Instala Docker desde el repositorio oficial de Docker si falta (Linux) o Docker Desktop (Windows). | Sí, si falta |
| 4. Soporte de GPU | Linux: instala y configura NVIDIA Container Toolkit si falta. En ambos: ejecuta un contenedor de prueba que debe ver la GPU. | Sí, si falta |
| 5. Archivos de configuración | Crea la configuración y una **clave secreta** aleatoria (usada para firmar los inicios de sesión). Se conserva en las actualizaciones para que nadie pierda la sesión. | Sí |
| 6. Descargando la imagen | Descarga la imagen (oficial: `ghcr.io/open-webui/open-webui:cuda`). | Sí |
| 7. Iniciando | Inicia el contenedor **accesible solo desde el propio servidor** y espera a que responda. | Sí |
| 8. Cuenta de administrador | Pregunta nombre, correo y contraseña (oculta, escrita dos veces) y crea el primer usuario, que pasa a ser administrador. Se omite si ya existen usuarios. | Sí |
| 9. Abriendo a la red | Reinicia el contenedor para que otros equipos puedan acceder. | Sí |
| 10. Firewall | Red local: permite el puerto solo para tu red local (ufw, firewalld o firewall de Windows). IP pública: **no** abre el puerto. | Sí, si lo confirmas |
| 11. Pruebas finales | Contenedor en ejecución, interfaz web respondiendo, GPU visible en el contenedor, conexión con Ollama, cantidad de modelos. | No |

**Por qué los pasos 7 y 9 están separados:** la primera persona que crea una cuenta se convierte en administradora. Entre iniciar el contenedor y crear tu cuenta, el instalador deja my-local-ia accesible solo desde el propio servidor, para que nadie de la red tome antes la cuenta de administrador.

**Cómo detecta el instalador el tipo de acceso:** mira la dirección IP del servidor. Direcciones como `192.168.x.x`, `10.x.x.x` y `172.16–31.x.x` son de red local: el puerto se abre solo para esa red. Cualquier otra dirección es pública: el puerto no se abre y un mensaje remite a la [sección 12](#12-publicar-en-internet-más-adelante).

---

## 7. Primer acceso

1. En cualquier equipo de la red, abre `http://IP-DEL-SERVIDOR:4000` (el instalador muestra la dirección exacta al final).
2. Inicia sesión con el correo y la contraseña del administrador.
3. Elige un modelo en la parte superior de la pantalla y empieza a chatear. Los modelos son los instalados en Ollama (`ollama list`).

**Agregar personas**

- **Panel de administración → Usuarios → +**: crea tú la cuenta y entrega la contraseña a la persona; o
- deja que las personas se registren en la página de inicio de sesión. Las cuentas nuevas quedan **pendientes** hasta que un administrador las apruebe en **Panel de administración → Usuarios** (cambia el rol de *pending* a *user*). El interruptor de registro y el rol predeterminado están en **Panel de administración → Configuración → General**.

**Revisar la conexión con Ollama:** **Panel de administración → Configuración → Conexiones**. La dirección de Ollama debe ser la que mostró el instalador (`http://127.0.0.1:11434` en Linux, `http://host.docker.internal:11434` en Windows).

---

## 8. El menú del instalador

Ejecuta el instalador de nuevo cada vez que necesites una de estas opciones. Recuerda tus respuestas anteriores.

| Opción | Qué hace |
|---|---|
| **1) Instalar** | Instala, o recrea el contenedor conservando todos los datos. |
| **2) Actualizar o cambiar de versión** | Descarga la imagen más reciente (misma versión, oficial o my-local-ia), ofrece una **copia de seguridad**, reemplaza el contenedor y lo prueba. Si la nueva versión no inicia, **vuelve sola a la anterior**. |
| **3) Verificar** | Solo diagnóstico: revisa todo y guarda un archivo de **informe** para enviar al pedir ayuda. No cambia nada. |
| **4) Hacer copia de seguridad ahora** | Guarda usuarios, chats, ajustes y archivos subidos en un archivo `.tar.gz`. my-local-ia se detiene unos segundos. Se conservan las 5 copias más recientes. |
| **5) Restaurar una copia de seguridad** | Lista las copias y restaura la que elijas (reemplaza los datos actuales, después de confirmar). |
| **6) Restablecer la contraseña de un usuario** | Define una contraseña nueva para cualquier usuario, incluido el administrador. |
| **7) Desinstalar** | Quita el contenedor y la regla de firewall. Los datos solo se borran si lo confirmas y escribes `DELETE`, y antes se ofrece una copia de seguridad. Docker, Ollama y tus modelos nunca se eliminan. |

---

## 9. Cambiar de la versión oficial a my-local-ia

Cuando el repositorio my-local-ia esté publicado en GitHub y su imagen esté lista:

1. Ejecuta el instalador y elige **2) Actualizar o cambiar de versión**.
2. Elige **my-local-ia** y escribe el usuario de GitHub dueño del repositorio.
3. Acepta la copia de seguridad.

El instalador descarga `ghcr.io/<usuario-github>/my-local-ia:cuda`, conserva todos tus datos y vuelve a la versión anterior si algo falla. Si dice que no pudo descargar la imagen, todavía no está publicada, o su paquete es privado (consulta la guía de solución de problemas).

---

## 10. Dónde se guarda todo

| Qué | Linux | Windows |
|---|---|---|
| Datos (usuarios, chats, ajustes, archivos) | Volumen Docker `my-local-ia-data` | Volumen Docker `my-local-ia-data` |
| Respuestas del instalador | `/etc/my-local-ia/installer.conf` | `C:\ProgramData\my-local-ia\installer.json` |
| Configuración del contenedor y clave secreta | `/etc/my-local-ia/my-local-ia.env` (solo root) | `C:\ProgramData\my-local-ia\my-local-ia.env` (solo administradores) |
| Registro del instalador | `/var/log/my-local-ia-install.log` | `C:\ProgramData\my-local-ia\logs\install.log` |
| Informes de diagnóstico | `/var/log/my-local-ia-report-*.txt` | `C:\ProgramData\my-local-ia\logs\report-*.txt` |
| Copias de seguridad | `/var/backups/my-local-ia/` | `C:\ProgramData\my-local-ia\backups\` |
| Modelos de Ollama (solo lectura para my-local-ia) | normalmente `/usr/share/ollama/.ollama/models` | normalmente `C:\Users\<tú>\.ollama\models` |

Las contraseñas **nunca** se escriben en el registro, la pantalla ni los archivos de configuración.

---

## 11. Modo simulación

Para ver todo lo que haría el instalador, sin cambiar nada:

```bash
sudo bash /tmp/install-my-local-ia.sh --dry-run
```

```powershell
powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1 -DryRun
```

Otras opciones: `--lang en|pt|es` (Linux) y `-Lang en|pt|es` (Windows) eligen el idioma sin preguntar.

---

## 12. Publicar en internet (más adelante)

El instalador solo prepara el acceso desde la **red local**. Si decides que my-local-ia sea accesible desde internet:

- **Preferible: Cloudflare Tunnel.** El programa `cloudflared` se ejecuta en el servidor y abre una conexión saliente hacia Cloudflare, así que **no hace falta abrir ningún puerto en el router**. Cloudflare se encarga del HTTPS, y puedes agregar **Cloudflare Access** para exigir un inicio de sesión adicional (código por correo, Google…) antes de que alguien vea siquiera my-local-ia. Guía: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/>
- **Si usas redirección de puertos en el router:** nunca redirijas el puerto 4000 directamente. Pon delante un proxy inverso con HTTPS (por ejemplo Caddy o Nginx), redirige solo el puerto 443 hacia él, activa el proxy de Cloudflare (nube naranja) con el modo SSL **Full (strict)** y limita la regla del router a los rangos de IP de Cloudflare.

En ambos casos, antes de publicar:

1. Desactiva el registro abierto (**Panel de administración → Configuración → General**) o mantén a los usuarios nuevos como *pendientes*.
2. Usa contraseñas fuertes en todas las cuentas, sobre todo en las de administrador.
3. Mantén my-local-ia actualizado (opción **Actualizar**).
4. Nunca expongas el puerto de Ollama (11434) a internet: Ollama no tiene inicio de sesión.

---

## 13. Notas de seguridad

- El instalador solo cambia lo que muestra y tú confirmas. Nunca elimina Docker, Ollama ni modelos.
- La clave secreta y la configuración solo pueden leerlas root (Linux) o los administradores (Windows).
- La contraseña del administrador se envía directamente a my-local-ia, nunca en una línea de comandos, así que no aparece en la lista de procesos ni en el registro.
- En Linux, el contenedor usa la red del propio servidor (`--network host`) para llegar a Ollama en `127.0.0.1` sin exponer Ollama a la red.
- En Windows, si permites `OLLAMA_HOST=0.0.0.0`, Ollama también acepta conexiones de otros equipos, si el firewall de Windows lo permite. Ollama no tiene inicio de sesión: mantén el puerto 11434 cerrado a la red en el firewall.

---

## 14. Comandos útiles

Linux (usa `sudo` si tu usuario no está en el grupo `docker`). En Windows, los mismos comandos `docker` funcionan en PowerShell.

```bash
docker ps                                  # ¿está en ejecución el contenedor my-local-ia?
docker logs --tail 100 my-local-ia         # últimas 100 líneas de su registro
docker logs -f my-local-ia                 # seguir el registro en vivo (Ctrl+C para salir)
docker restart my-local-ia                 # reiniciar
docker stop my-local-ia                    # detener
docker start my-local-ia                   # iniciar
docker exec my-local-ia nvidia-smi         # GPU vista desde dentro del contenedor
docker system df                           # espacio en disco usado por Docker
ollama ps                                  # modelos cargados y si están en GPU o CPU
```

Documentación de Open WebUI (la base de my-local-ia): <https://docs.openwebui.com>
