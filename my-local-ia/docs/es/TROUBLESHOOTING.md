# my-local-ia — Guía de solución de problemas

[English](../en/TROUBLESHOOTING.md) · [Português](../pt-BR/TROUBLESHOOTING.md) · Instalación: [INSTALL.md](INSTALL.md)

Cada problema de abajo incluye el **síntoma** (lo que ves), la **causa** y la **solución**. Los comandos marcados como _Linux_ se ejecutan en la terminal del servidor (con `sudo` cuando haga falta); los marcados como _Windows_ se ejecutan en PowerShell abierto como administrador.

---

## Contenido

- [0. Empieza aquí: reúne la información](#0-empieza-aquí-reúne-la-información)
- [1. Instalador](#1-instalador)
- [2. GPU (NVIDIA)](#2-gpu-nvidia)
- [3. Docker](#3-docker)
- [4. Inicio de my-local-ia](#4-inicio-de-my-local-ia)
- [5. Ollama y modelos](#5-ollama-y-modelos)
- [6. Acceso desde otros equipos](#6-acceso-desde-otros-equipos)
- [7. Cuentas y contraseñas](#7-cuentas-y-contraseñas)
- [8. Actualizaciones, copias de seguridad y cambio de servidor](#8-actualizaciones-copias-de-seguridad-y-cambio-de-servidor)
- [9. La imagen de my-local-ia](#9-la-imagen-de-my-local-ia)
- [10. Espacio en disco](#10-espacio-en-disco)
- [11. Pedir ayuda](#11-pedir-ayuda)

---

## 0. Empieza aquí: reúne la información

1. **Ejecuta el instalador y elige 3) Verificar.** Revisa todo sin cambiar nada, muestra ✔ / ! / ✖ para cada elemento y guarda un informe:
   - Linux: `/var/log/my-local-ia-report-<fecha>.txt`
   - Windows: `C:\ProgramData\my-local-ia\logs\report-<fecha>.txt`
2. **Lee el registro del instalador**, que tiene cada comando y su salida:
   - Linux: `/var/log/my-local-ia-install.log`
   - Windows: `C:\ProgramData\my-local-ia\logs\install.log`
3. **Lee el registro de my-local-ia:**

   ```bash
   docker logs --tail 100 my-local-ia
   ```

La mayoría de los problemas se identifican en la primera línea marcada con ✖ en el resultado de Verificar. Busca ese mensaje abajo.

---

## 1. Instalador

### "Ejecuta este script como root" (Linux) / "Ejecuta este script en PowerShell abierto como Administrador" (Windows)

- **Causa:** el instalador cambia ajustes del sistema y necesita permisos de administrador.
- **Solución:**
  - Linux: `sudo bash /tmp/install-my-local-ia.sh`
  - Windows: menú Inicio → **PowerShell** → clic derecho → **Ejecutar como administrador**, y ejecuta el comando de nuevo.

### Linux: `$'\r': command not found` o `set: pipefail: invalid option name`

- **Causa:** el archivo se convirtió a saltos de línea de Windows (CRLF) en el camino al servidor, por ejemplo al abrirlo y guardarlo en un editor de Windows o al copiarlo en modo "texto".
- **Solución:** las versiones actuales del instalador lo corrigen solas y se reinician. Con una copia antigua, corrige el archivo y ejecútalo de nuevo:

  ```bash
  sudo sed -i 's/\r$//' /tmp/install-my-local-ia.sh
  sudo bash /tmp/install-my-local-ia.sh
  ```

  Para evitarlo, copia el archivo con `scp`, o configura WinSCP para transferir en modo **binario**.

### Windows: "la ejecución de scripts está deshabilitada en este sistema"

- **Causa:** la directiva de ejecución de Windows bloquea los scripts.
- **Solución:** ejecútalo con la directiva liberada solo para este script (nada cambia de forma permanente):

  ```powershell
  powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1
  ```

  Si aún se niega porque el archivo viene de internet: `Unblock-File C:\temp\install-my-local-ia.ps1`.

### Windows: las tildes se ven rotas (Ã©, Ã±…)

- **Causa:** un editor volvió a guardar el archivo con otra codificación. El script se guarda como UTF-8 con BOM, que Windows PowerShell necesita.
- **Solución:** copia otra vez el archivo original. Si lo editas, guárdalo como **UTF-8 con BOM** (en el Bloc de notas: _Guardar como → Codificación: UTF-8 con BOM_).

### "Esta distribución no es compatible con la instalación automática de Docker"

- **Causa:** el instalador solo sabe instalar Docker en Ubuntu/Debian (y derivadas) y Fedora/RHEL/Rocky/Alma/CentOS Stream.
- **Solución:** instala Docker manualmente siguiendo <https://docs.docker.com/engine/install/>, comprueba que `docker info` funciona y ejecuta el instalador de nuevo: se salta el paso de Docker.

### "No se pudo acceder a ghcr.io (registro de imágenes)"

- **Causa:** sin internet, fallo de DNS, o un proxy/firewall que bloquea `ghcr.io`.
- **Solución:**
  1. Prueba: `curl -I https://ghcr.io/v2/` (una respuesta `401` es normal y significa que funciona).
  2. Si la red usa **proxy**, Docker también lo necesita. _Linux:_ crea `/etc/systemd/system/docker.service.d/http-proxy.conf`:

     ```ini
     [Service]
     Environment="HTTP_PROXY=http://proxy.ejemplo:3128"
     Environment="HTTPS_PROXY=http://proxy.ejemplo:3128"
     Environment="NO_PROXY=localhost,127.0.0.1"
     ```

     y luego `sudo systemctl daemon-reload && sudo systemctl restart docker`. _Windows:_ Docker Desktop → Settings → Resources → Proxies.

### La instalación se detuvo cuando se cayó la conexión SSH

- **Causa:** cerrar la sesión SSH termina los programas iniciados en ella.
- **Solución:** vuelve a conectarte y ejecuta el instalador de nuevo; reutiliza las respuestas ya dadas y se salta lo ya hecho. La próxima vez, usa `tmux` (consulta la guía de instalación, sección 4.2).

### "El puerto 4000 ya está en uso en este servidor"

- **Causa:** otro programa usa el puerto.
- **Solución:** mira cuál es y elige otro puerto, o detén ese programa:
  - Linux: `sudo ss -ltnp | grep ':4000'`
  - Windows: `Get-NetTCPConnection -LocalPort 4000 -State Listen | Select-Object OwningProcess; Get-Process -Id <número>`

---

## 2. GPU (NVIDIA)

### "Se encontró una tarjeta NVIDIA, pero el controlador no está instalado (falta nvidia-smi)"

- **Causa:** falta el controlador NVIDIA. Sin él, ni Ollama ni my-local-ia pueden usar la GPU.
- **Solución (Linux):**
  - Ubuntu: `sudo ubuntu-drivers install` y reinicia el servidor.
  - Debian, Fedora, RHEL y otras: instala el controlador desde los repositorios de la distribución o desde NVIDIA (<https://www.nvidia.com/Download/index.aspx>) y reinicia.
  - Compruébalo con `nvidia-smi`.
- **Solución (Windows):** instala el controlador más reciente desde <https://www.nvidia.com/Download/index.aspx> y reinicia.
- **Máquina virtual:** la GPU debe pasarse a la VM (_GPU passthrough_) en el hipervisor (Proxmox, VMware ESXi, Hyper-V DDA…). Si `lspci | grep -i nvidia` (Linux) no muestra nada, la VM todavía no ve la tarjeta.

### "La GPU NO es visible dentro de los contenedores"

- **Síntoma:** el contenedor de prueba del paso 4 falla, o Verificar muestra "La GPU no es visible dentro del contenedor".
- **Causa (Linux):** NVIDIA Container Toolkit no está instalado o no está configurado en Docker.
- **Solución (Linux):**

  ```bash
  nvidia-ctk --version                              # ¿está instalado?
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker
  docker run --rm --gpus all ubuntu:24.04 nvidia-smi -L   # debe listar la GPU
  ```

  Si `nvidia-ctk` no existe, ejecuta el instalador de nuevo (el paso 4 lo instala) o sigue <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>.

- **Causa (Windows):** controlador NVIDIA antiguo, WSL antiguo, o Docker Desktop sin usar el motor WSL 2.
- **Solución (Windows):** actualiza el controlador NVIDIA; ejecuta `wsl --update`; en Docker Desktop → Settings → General, activa **Use the WSL 2 based engine**; reinicia Docker Desktop.

### Error `could not select device driver "" with capabilities: [[gpu]]`

- **Causa:** Docker no conoce el runtime de NVIDIA (el mismo caso de arriba).
- **Solución:** los comandos `nvidia-ctk runtime configure` del punto anterior.

### Las respuestas son muy lentas

- **Causa:** el modelo no cabe en la memoria de la GPU (VRAM), así que parte de él se ejecuta en la RAM del sistema, mucho más lenta; o Ollama no está usando la GPU.
- **Solución:**
  1. Mientras un chat está respondiendo, ejecuta `ollama ps`. La columna **PROCESSOR** muestra `100% GPU` cuando todo está en la tarjeta. Algo como `40%/60% CPU/GPU` significa que el modelo es más grande que la VRAM: elige un modelo más pequeño o una versión más comprimida (Q4).
  2. Ejecuta `nvidia-smi` durante una respuesta: el uso de la GPU debe subir.
  3. Si `ollama ps` muestra `100% CPU` con un modelo pequeño, el propio Ollama no ve la GPU: reinícialo (`sudo systemctl restart ollama`) y revisa su registro (`journalctl -u ollama --since "10 min ago"`).

---

## 3. Docker

### La instalación de Docker falla (Linux)

- **Causa:** paquetes de la distribución en conflicto (`docker.io`, `containerd`, `podman-docker`) o repositorios inaccesibles.
- **Solución:**
  - Ubuntu/Debian: `sudo apt remove -y docker.io docker-doc docker-compose podman-docker containerd runc` y ejecuta el instalador de nuevo.
  - Fedora/RHEL: `sudo dnf remove -y podman-docker` y ejecuta el instalador de nuevo.
  - El error exacto está en `/var/log/my-local-ia-install.log`.

### "Docker está instalado pero detenido" (Linux)

- **Solución:**

  ```bash
  sudo systemctl enable --now docker
  sudo systemctl status docker            # debe mostrar "active (running)"
  sudo journalctl -u docker --since "10 min ago"   # el motivo, si falla
  ```

### Windows: Docker Desktop no inicia

- **Causas y soluciones:**
  - **Virtualización desactivada:** activa _Intel VT-x_ / _AMD-V (SVM)_ en la BIOS/UEFI. Administrador de tareas → Rendimiento → CPU debe mostrar _Virtualización: Habilitado_.
  - **Windows es una máquina virtual:** activa la virtualización anidada en el hipervisor. Hyper-V (en el host, con la VM apagada): `Set-VMProcessor -VMName <nombre> -ExposeVirtualizationExtensions $true`. VMware: _Expose hardware assisted virtualization to the guest OS_.
  - **WSL antiguo:** `wsl --update` y reinicia.
  - **Windows Server:** Docker Desktop no es compatible. Usa Windows 10/11 o un servidor Linux.

### Windows: "winget no está disponible"

- **Solución:** instala **Instalador de aplicación** desde Microsoft Store, o instala Docker Desktop manualmente desde <https://www.docker.com/products/docker-desktop/>, y ejecuta el instalador de nuevo.

---

## 4. Inicio de my-local-ia

### "my-local-ia no respondió a tiempo"

- **Causas:**
  - El primer inicio descarga archivos extra (para la búsqueda en documentos) y puede tardar varios minutos con una conexión lenta.
  - Falta de RAM.
  - Un error en el contenedor.
- **Solución:**
  1. Mira el registro: `docker logs --tail 100 my-local-ia`. Mientras aparezcan mensajes de descarga o de inicio, espera y vuelve a revisar con Verificar.
  2. Revisa la RAM: `free -h` (Linux). Con menos de 2 GB disponibles, cierra otros programas o agrega RAM.
  3. Si el registro muestra un error (`Error`, `Traceback`), envía el registro (consulta la [sección 11](#11-pedir-ayuda)).

### "El contenedor se detuvo durante el inicio" / el contenedor se reinicia una y otra vez

- **Solución:**
  1. `docker logs --tail 100 my-local-ia` muestra el motivo.
  2. Motivos comunes:
     - **Falta el archivo de configuración:** el instalador se interrumpió antes del paso 5. Ejecuta **Instalar** de nuevo.
     - **Error de base de datos después de una actualización:** usa **Restaurar** con la copia hecha antes de la actualización.
     - **Permiso denegado en la carpeta de modelos de Ollama (Linux con SELinux):** el instalador ya inicia el contenedor con `--security-opt label=disable` cuando SELinux está en modo enforcing. Si creaste el contenedor a mano, agrega esa opción.

---

## 5. Ollama y modelos

### "Ollama no responde"

- **Linux:**

  ```bash
  sudo systemctl status ollama
  sudo systemctl restart ollama
  curl http://127.0.0.1:11434        # "Ollama is running"
  ```

- **Windows:** abre **Ollama** desde el menú Inicio (aparece junto al reloj) y prueba `curl.exe http://127.0.0.1:11434`.

### "my-local-ia no puede conectar con Ollama"

- **Linux:** el contenedor usa la red del servidor, así que `http://127.0.0.1:11434` funciona siempre que Ollama responda en el servidor (punto anterior). Si Ollama está en **otro** equipo:
  1. En ese equipo, haz que Ollama escuche en la red: `sudo systemctl edit ollama`, agrega

     ```ini
     [Service]
     Environment="OLLAMA_HOST=0.0.0.0:11434"
     ```

     y `sudo systemctl restart ollama`.

  2. En my-local-ia, define la dirección como `http://IP-DE-ESE-EQUIPO:11434` (pregunta del instalador, o **Panel de administración → Configuración → Conexiones**).
  3. Permite el puerto 11434 en el firewall de ese equipo **solo** para el servidor de my-local-ia.

- **Windows:** acepta la oferta del instalador para definir `OLLAMA_HOST`, o hazlo a mano: _Configuración → Sistema → Acerca de → Configuración avanzada del sistema → Variables de entorno_ → nueva variable de usuario `OLLAMA_HOST` = `0.0.0.0:11434`; cierra Ollama (icono junto al reloj → Quit) y ábrelo de nuevo.
- Más detalles sobre la configuración de Ollama: <https://github.com/ollama/ollama/blob/main/docs/faq.md>

### La lista de modelos en my-local-ia está vacía

- **Solución:**
  1. `ollama list` en el servidor debe mostrar modelos. Si está vacía, descarga uno, por ejemplo `ollama pull llama3.2`.
  2. **Panel de administración → Configuración → Conexiones:** la conexión de Ollama debe estar activada y con la dirección correcta. Haz clic en el icono de verificar/actualizar junto a ella.
  3. Recarga la página (F5).

---

## 6. Acceso desde otros equipos

### Funciona en el servidor pero no desde otros equipos

1. **En el servidor**, prueba: `curl http://127.0.0.1:4000/health` → debe responder `{"status":true}`. Si no responde, el problema es el propio my-local-ia (sección 4).
2. **Dirección:** usa la IP del servidor que se mostró al final de la instalación (`hostname -I` en Linux, `ipconfig` en Windows). Ambos equipos deben estar en la misma red.
3. **Firewall:**
   - Linux con ufw: `sudo ufw status` debe mostrar `4000/tcp ALLOW <tu red>`. Para agregarla: `sudo ufw allow from 192.168.1.0/24 to any port 4000 proto tcp`.
   - Linux con firewalld: `sudo firewall-cmd --list-all`. Para agregarla: `sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.1.0/24 port port=4000 protocol=tcp accept' && sudo firewall-cmd --reload`.
   - Windows: la regla "my-local-ia (TCP 4000)" debe existir en _Firewall de Windows Defender → Configuración avanzada → Reglas de entrada_, y la red debe ser **Privada** (_Configuración → Red e Internet_).
4. **Aislamiento de red:** las redes Wi-Fi de invitados y algunos routers ("aislamiento de AP", "aislamiento de clientes") bloquean el acceso entre dispositivos. Prueba desde un equipo conectado por cable al mismo router.
5. **Servidor con IP pública:** en ese caso el instalador no abre el puerto. Consulta _Publicar en internet_ en la guía de instalación.

---

## 7. Cuentas y contraseñas

### Olvidé la contraseña del administrador

- Ejecuta el instalador y elige **6) Restablecer la contraseña de un usuario**: escribe el correo y la contraseña nueva. Funciona con la base de datos predeterminada.

### Los usuarios nuevos no pueden iniciar sesión

- **Causa:** los registros nuevos quedan **pendientes**.
- **Solución:** **Panel de administración → Usuarios** → cambia el rol de la persona de _pending_ a _user_. Para cambiar el valor predeterminado: **Panel de administración → Configuración → General → Rol de usuario predeterminado**.

### El enlace de registro no aparece en la página de inicio de sesión

- **Causa:** después de crear el primer administrador, el registro puede quedar desactivado.
- **Solución:** **Panel de administración → Configuración → General → Habilitar nuevos registros**, o crea tú las cuentas en **Panel de administración → Usuarios**.

### Todos perdieron la sesión después de reinstalar

- **Causa:** la clave secreta cambió (por ejemplo, después de borrar `/etc/my-local-ia` o `C:\ProgramData\my-local-ia`).
- **Solución:** no se perdió nada; cada persona solo tiene que iniciar sesión de nuevo.

---

## 8. Actualizaciones, copias de seguridad y cambio de servidor

### "La nueva versión no inició. Volviendo a la anterior…"

- **Causa:** la nueva imagen no pudo iniciar. El instalador volvió a poner la versión anterior automáticamente.
- **Solución:**
  1. Comprueba que my-local-ia funciona (Verificar).
  2. Si la versión anterior también falla, puede que la nueva versión ya haya convertido la base de datos: elige **5) Restaurar** y toma la copia hecha justo antes de la actualización.
  3. Envía los registros (sección 11) antes de intentar la actualización de nuevo.

### Restaurar una copia de seguridad a mano

Si no se puede usar el instalador (Linux; ajusta el nombre del archivo):

```bash
docker stop my-local-ia
docker run --rm -v my-local-ia-data:/data -v /var/backups/my-local-ia:/backup alpine:3.20 \
  sh -c "find /data -mindepth 1 -delete && tar xzf /backup/my-local-ia-data-AAAAMMDD-HHMMSS.tar.gz -C /data"
docker start my-local-ia
```

### Mover my-local-ia a otro servidor

1. Servidor antiguo: instalador → **4) Hacer copia de seguridad ahora**.
2. Copia el archivo `.tar.gz` al servidor nuevo, en `/var/backups/my-local-ia/` (Windows: `C:\ProgramData\my-local-ia\backups\`).
3. Servidor nuevo: instalador → **1) Instalar**.
4. Servidor nuevo: instalador → **5) Restaurar**, elige el archivo copiado.

---

## 9. La imagen de my-local-ia

### "No se pudo descargar ghcr.io/<usuario>/my-local-ia…"

- **Causas:**
  - El repositorio de GitHub todavía no generó la imagen (la generación se ejecuta en GitHub Actions y tarda de 20 a 40 minutos).
  - El paquete de la imagen es **privado**.
  - El usuario de GitHub se escribió mal.
- **Solución:**
  1. En GitHub, abre el repositorio → **Actions**: el "build" más reciente debe estar en verde.
  2. Abre tu perfil → **Packages** → `my-local-ia` → **Package settings** → **Change visibility** → **Public**.
  3. Ejecuta **Actualizar** de nuevo y elige my-local-ia. Mientras tanto, la versión oficial sigue funcionando.

### "La compilación falló" (imagen compilada en el servidor)

La versión instalada sigue funcionando: el contenedor solo se cambia cuando la imagen nueva está lista. El registro muestra el paso exacto (busca las últimas líneas con `ERROR` o `error`).

| Qué muestra el registro                                             | Causa                                    | Solución                                                                                                                                 |
| ------------------------------------------------------------------- | ---------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `JavaScript heap out of memory` o `Killed` durante `npm run build`  | Poca memoria para compilar la interfaz   | Cierra otros programas o dale más RAM a la VM; en Windows, aumenta la memoria de WSL (archivo `%UserProfile%\.wslconfig`, `memory=12GB`) |
| `no space left on device`                                           | El disco se llenó durante la compilación | Libera unos 25 GB (ver la sección 10) y vuelve a ejecutar; `docker builder prune -f` borra cachés antiguas                               |
| `Could not resolve host` / `fatal: unable to access` / `curl: (22)` | Sin internet o dirección/rama incorrecta | Revisa la dirección del repositorio y la rama; abre la dirección en el navegador                                                         |
| Error en `pip install` o `npm ci`                                   | Falla de red pasajera                    | Vuelve a ejecutar: los pasos que ya funcionaron quedan en caché                                                                          |

---

## 10. Espacio en disco

### "no space left on device" / "Menos de 30 GB libres"

- **Mira qué ocupa espacio:**

  ```bash
  df -h /                      # espacio libre
  docker system df             # imágenes, contenedores y volúmenes
  ollama list                  # modelos y sus tamaños
  ```

- **Libera espacio de forma segura:**
  - Quita los modelos que no usas: `ollama rm <modelo>`.
  - Quita las imágenes Docker que ya no se usan (versiones antiguas tras actualizar): `docker image prune -a`. Esto **no** borra tus datos (volúmenes).
  - Quita copias antiguas en `/var/backups/my-local-ia/` (el instalador ya conserva solo las 5 más recientes).
- **Nunca** ejecutes `docker volume prune` ni `docker system prune --volumes` sin copia de seguridad: pueden borrar el volumen `my-local-ia-data`.

---

## 11. Pedir ayuda

Envía:

1. El **informe** creado por **3) Verificar** (la ruta aparece al final de Verificar).
2. El **registro del instalador** (`/var/log/my-local-ia-install.log` o `C:\ProgramData\my-local-ia\logs\install.log`).
3. Qué estabas haciendo y el mensaje exacto en pantalla (una captura de pantalla ayuda).

El informe y el registro nunca contienen contraseñas ni la clave secreta. Sí contienen direcciones IP y nombres de modelos y carpetas: quita lo que no quieras compartir.
