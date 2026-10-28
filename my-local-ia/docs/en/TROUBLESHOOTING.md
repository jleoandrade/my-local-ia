# my-local-ia — Troubleshooting guide

[Português](../pt-BR/TROUBLESHOOTING.md) · [Español](../es/TROUBLESHOOTING.md) · Installation: [INSTALL.md](INSTALL.md)

Each problem below has the **symptom** (what you see), the **cause** and the **solution**. Commands marked _Linux_ run in the server terminal (with `sudo` when needed); commands marked _Windows_ run in PowerShell opened as administrator.

---

## Contents

- [0. Start here: collect information](#0-start-here-collect-information)
- [1. Installer](#1-installer)
- [2. GPU (NVIDIA)](#2-gpu-nvidia)
- [3. Docker](#3-docker)
- [4. Starting my-local-ia](#4-starting-my-local-ia)
- [5. Ollama and models](#5-ollama-and-models)
- [6. Access from other computers](#6-access-from-other-computers)
- [7. Accounts and passwords](#7-accounts-and-passwords)
- [8. Updates, backups and moving to another server](#8-updates-backups-and-moving-to-another-server)
- [9. The my-local-ia image](#9-the-my-local-ia-image)
- [10. Disk space](#10-disk-space)
- [11. Asking for help](#11-asking-for-help)

---

## 0. Start here: collect information

1. **Run the installer and choose 3) Verify.** It checks everything without changing anything, shows ✔ / ! / ✖ for each item and saves a report:
   - Linux: `/var/log/my-local-ia-report-<date>.txt`
   - Windows: `C:\ProgramData\my-local-ia\logs\report-<date>.txt`
2. **Read the installer log**, which has every command and its output:
   - Linux: `/var/log/my-local-ia-install.log`
   - Windows: `C:\ProgramData\my-local-ia\logs\install.log`
3. **Read the my-local-ia log:**

   ```bash
   docker logs --tail 100 my-local-ia
   ```

Most problems are identified by the first line marked ✖ in the Verify output. Look for that message below.

---

## 1. Installer

### "Run this script as root" (Linux) / "Run this script from PowerShell opened as Administrator" (Windows)

- **Cause:** the installer changes system settings and needs administrator rights.
- **Solution:**
  - Linux: `sudo bash /tmp/install-my-local-ia.sh`
  - Windows: Start menu → **PowerShell** → right-click → **Run as administrator**, then run the command again.

### Linux: `$'\r': command not found` or `set: pipefail: invalid option name`

- **Cause:** the file was converted to Windows line endings (CRLF) on the way to the server, for example by opening and saving it in a Windows editor or copying it in "text" mode.
- **Solution:** current versions of the installer fix this by themselves and restart. With an older copy, fix the file and run it again:

  ```bash
  sudo sed -i 's/\r$//' /tmp/install-my-local-ia.sh
  sudo bash /tmp/install-my-local-ia.sh
  ```

  To avoid it, copy the file with `scp`, or set WinSCP to **binary** transfer mode.

### Windows: "running scripts is disabled on this system"

- **Cause:** the Windows execution policy blocks scripts.
- **Solution:** run it with the policy bypassed only for this script (nothing is changed permanently):

  ```powershell
  powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1
  ```

  If it still refuses because the file came from the internet: `Unblock-File C:\temp\install-my-local-ia.ps1`.

### Windows: accented letters appear broken (Ã©, Ã§…)

- **Cause:** the file was saved again by an editor in another encoding. The script is saved as UTF-8 with BOM, which Windows PowerShell needs.
- **Solution:** copy the original file again. If you edit it, save it as **UTF-8 with BOM** (in Notepad: _Save as → Encoding: UTF-8 with BOM_).

### "This distribution is not supported by the automatic Docker installation"

- **Cause:** the installer only knows how to install Docker on Ubuntu/Debian (and derivatives) and Fedora/RHEL/Rocky/Alma/CentOS Stream.
- **Solution:** install Docker manually following <https://docs.docker.com/engine/install/>, check that `docker info` works, and run the installer again: it skips the Docker step.

### "Could not reach ghcr.io (image registry)"

- **Cause:** no internet, DNS failure, or a proxy/firewall blocking `ghcr.io`.
- **Solution:**
  1. Test: `curl -I https://ghcr.io/v2/` (an answer `401` is normal and means it works).
  2. If the network uses a **proxy**, Docker also needs it. _Linux:_ create `/etc/systemd/system/docker.service.d/http-proxy.conf`:

     ```ini
     [Service]
     Environment="HTTP_PROXY=http://proxy.example:3128"
     Environment="HTTPS_PROXY=http://proxy.example:3128"
     Environment="NO_PROXY=localhost,127.0.0.1"
     ```

     then `sudo systemctl daemon-reload && sudo systemctl restart docker`. _Windows:_ Docker Desktop → Settings → Resources → Proxies.

### The installation stopped when the SSH connection dropped

- **Cause:** closing the SSH session ends the programs started from it.
- **Solution:** reconnect and run the installer again; it reuses the answers already given and skips what is done. Next time, use `tmux` (see the installation guide, section 4.2).

### "Port 4000 is already in use on this server"

- **Cause:** another program uses the port.
- **Solution:** see what it is and choose another port, or stop that program:
  - Linux: `sudo ss -ltnp | grep ':4000'`
  - Windows: `Get-NetTCPConnection -LocalPort 4000 -State Listen | Select-Object OwningProcess; Get-Process -Id <number>`

---

## 2. GPU (NVIDIA)

### "An NVIDIA card was found, but the driver is not installed (nvidia-smi is missing)"

- **Cause:** the NVIDIA driver is missing. Without it, neither Ollama nor my-local-ia can use the GPU.
- **Solution (Linux):**
  - Ubuntu: `sudo ubuntu-drivers install` and restart the server.
  - Debian, Fedora, RHEL and others: install the driver from the distribution's repositories or from NVIDIA (<https://www.nvidia.com/Download/index.aspx>) and restart.
  - Check with `nvidia-smi`.
- **Solution (Windows):** install the latest driver from <https://www.nvidia.com/Download/index.aspx> and restart.
- **Virtual machine:** the GPU must be passed through to the VM (_GPU passthrough_) in the hypervisor (Proxmox, VMware ESXi, Hyper-V DDA…). If `lspci | grep -i nvidia` (Linux) shows nothing, the VM does not see the card yet.

### "The GPU is NOT visible inside containers"

- **Symptom:** the test container in step 4 fails, or Verify shows "GPU not visible inside the container".
- **Cause (Linux):** the NVIDIA Container Toolkit is missing or not configured in Docker.
- **Solution (Linux):**

  ```bash
  nvidia-ctk --version                              # installed?
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker
  docker run --rm --gpus all ubuntu:24.04 nvidia-smi -L   # must list the GPU
  ```

  If `nvidia-ctk` does not exist, run the installer again (step 4 installs it) or follow <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>.

- **Cause (Windows):** old NVIDIA driver, old WSL, or Docker Desktop not using the WSL 2 engine.
- **Solution (Windows):** update the NVIDIA driver; run `wsl --update`; in Docker Desktop → Settings → General, enable **Use the WSL 2 based engine**; restart Docker Desktop.

### Error `could not select device driver "" with capabilities: [[gpu]]`

- **Cause:** Docker does not know the NVIDIA runtime (same as above).
- **Solution:** the `nvidia-ctk runtime configure` commands of the previous item.

### Answers are very slow

- **Cause:** the model does not fit in the GPU memory (VRAM), so part of it runs in the much slower system RAM; or Ollama is not using the GPU at all.
- **Solution:**
  1. While a chat is answering, run `ollama ps`. The **PROCESSOR** column shows `100% GPU` when everything is on the card. Something like `40%/60% CPU/GPU` means the model is bigger than the VRAM: choose a smaller model or a more compressed version (Q4).
  2. Run `nvidia-smi` during an answer: the GPU usage must go up.
  3. If `ollama ps` shows `100% CPU` for a small model, Ollama itself is not seeing the GPU: restart it (`sudo systemctl restart ollama`) and check its log (`journalctl -u ollama --since "10 min ago"`).

### Option 9 (gpu-unlock): "This GPU is not seen as a PCI Express device here" or error `-95`

- **Cause:** the VM gets the GPU on an old PCI bus, without the FLR reset gpu-unlock needs. The log shows `unlock_transaction_claim ... error=-95` (operation not supported).
- **Fix (Proxmox, on the host):** check with `qm config <VMID> | grep -E "machine|hostpci"` (it needs `machine: q35`), then `qm shutdown <VMID>`, `qm set <VMID> --hostpci0 <GPU address on the host>,pcie=1` and `qm start <VMID>`. Run option 9 again inside the VM. The GPU's address in the VM changes (for example from `06:10.0` to `01:00.0`); gpu-unlock finds it at any address.

### Option 9 (gpu-unlock): "turned on, but this boot did not unlock the GPU"

- **See why:** `journalctl -k -b | grep gpu_unlock`.
- **Common causes:**
  - The kernel was updated without headers and the module was not built for it: `sudo apt install -y linux-headers-generic linux-headers-$(uname -r)`, then `sudo dpkg-reconfigure gpu-unlock-dkms` and restart.
  - **Secure Boot** blocks unsigned modules: check with `mokutil --sb-state`. Turn Secure Boot off in the VM/BIOS or sign the DKMS module.
  - The GPU was powered down or already had a driver when the module ran (the log says `skipped`): fully power the machine off and on.

---

## 3. Docker

### Docker installation fails (Linux)

- **Cause:** conflicting packages from the distribution (`docker.io`, `containerd`, `podman-docker`) or repositories that are unreachable.
- **Solution:**
  - Ubuntu/Debian: `sudo apt remove -y docker.io docker-doc docker-compose podman-docker containerd runc` and run the installer again.
  - Fedora/RHEL: `sudo dnf remove -y podman-docker` and run the installer again.
  - The exact error is in `/var/log/my-local-ia-install.log`.

### "Docker is installed but not running" (Linux)

- **Solution:**

  ```bash
  sudo systemctl enable --now docker
  sudo systemctl status docker            # must show "active (running)"
  sudo journalctl -u docker --since "10 min ago"   # the reason, if it fails
  ```

### Windows: Docker Desktop does not start

- **Causes and solutions:**
  - **Virtualization disabled:** enable _Intel VT-x_ / _AMD-V (SVM)_ in the BIOS/UEFI. Task Manager → Performance → CPU must show _Virtualization: Enabled_.
  - **Windows is a virtual machine:** enable nested virtualization in the hypervisor. Hyper-V (on the host, with the VM off): `Set-VMProcessor -VMName <name> -ExposeVirtualizationExtensions $true`. VMware: _Expose hardware assisted virtualization to the guest OS_.
  - **Old WSL:** `wsl --update` and restart.
  - **Windows Server:** not supported by Docker Desktop. Use Windows 10/11 or a Linux server.

### Windows: "winget is not available"

- **Solution:** install **App Installer** from the Microsoft Store, or install Docker Desktop manually from <https://www.docker.com/products/docker-desktop/>, then run the installer again.

---

## 4. Starting my-local-ia

### "my-local-ia did not answer in time"

- **Causes:**
  - The first start downloads extra files (for document search) and can take several minutes on a slow connection.
  - Not enough RAM.
  - An error in the container.
- **Solution:**
  1. Look at the log: `docker logs --tail 100 my-local-ia`. While it shows download or startup messages, wait and check again with Verify.
  2. Check the RAM: `free -h` (Linux). With less than 2 GB available, close other programs or add RAM.
  3. If the log shows an error (`Error`, `Traceback`), send the log (see [section 11](#11-asking-for-help)).

### "The container stopped while starting" / the container keeps restarting

- **Solution:**
  1. `docker logs --tail 100 my-local-ia` shows the reason.
  2. Common reasons:
     - **Missing configuration file:** the installer was interrupted before step 5. Run **Install** again.
     - **Database error after an update:** use **Restore** with the backup made before the update.
     - **Permission denied on the Ollama models folder (Linux with SELinux):** the installer already starts the container with `--security-opt label=disable` when SELinux is in enforcing mode. If you created the container by hand, add that option.

---

## 5. Ollama and models

### "Ollama is not answering"

- **Linux:**

  ```bash
  sudo systemctl status ollama
  sudo systemctl restart ollama
  curl http://127.0.0.1:11434        # "Ollama is running"
  ```

- **Windows:** start **Ollama** from the Start menu (it appears next to the clock) and test `curl.exe http://127.0.0.1:11434`.

### "my-local-ia cannot reach Ollama"

- **Linux:** the container uses the server's network, so `http://127.0.0.1:11434` works whenever Ollama answers on the server (previous item). If Ollama is on **another** computer:
  1. On that computer, make Ollama listen on the network: `sudo systemctl edit ollama`, add

     ```ini
     [Service]
     Environment="OLLAMA_HOST=0.0.0.0:11434"
     ```

     and `sudo systemctl restart ollama`.

  2. In my-local-ia, set the address to `http://IP-OF-THAT-COMPUTER:11434` (installer question, or **Admin Panel → Settings → Connections**).
  3. Allow port 11434 in that computer's firewall **only** for the my-local-ia server.

- **Windows:** accept the installer's offer to set `OLLAMA_HOST`, or do it by hand: _Settings → System → About → Advanced system settings → Environment Variables_ → new user variable `OLLAMA_HOST` = `0.0.0.0:11434`; quit Ollama (icon next to the clock → Quit) and open it again.
- More details about Ollama settings: <https://github.com/ollama/ollama/blob/main/docs/faq.md>

### The model list in my-local-ia is empty

- **Solution:**
  1. `ollama list` on the server must show models. If it is empty, download one, for example `ollama pull llama3.2`.
  2. **Admin Panel → Settings → Connections:** the Ollama connection must be enabled, with the right address. Click the verify/refresh icon next to it.
  3. Reload the page (F5).

### Option 8: Ollama did not come back after optimizing

- **See why:** `systemctl status ollama` and `journalctl -u ollama --since "10 min ago"`.
- **Fix:** old Ollama versions do not know these settings; update Ollama (`curl -fsSL https://ollama.com/install.sh | sh`). To go back right away: `sudo rm /etc/systemd/system/ollama.service.d/my-local-ia.conf && sudo systemctl daemon-reload && sudo systemctl restart ollama` (or option 8 → **Undo**).

---

## 6. Access from other computers

### It works on the server but not from other computers

1. **On the server**, test: `curl http://127.0.0.1:4000/health` → must answer `{"status":true}`. If it does not, the problem is my-local-ia itself (section 4).
2. **Address:** use the server's IP shown at the end of the installation (`hostname -I` on Linux, `ipconfig` on Windows). Both computers must be on the same network.
3. **Firewall:**
   - Linux with ufw: `sudo ufw status` must show `4000/tcp ALLOW <your network>`. To add: `sudo ufw allow from 192.168.1.0/24 to any port 4000 proto tcp`.
   - Linux with firewalld: `sudo firewall-cmd --list-all`. To add: `sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.1.0/24 port port=4000 protocol=tcp accept' && sudo firewall-cmd --reload`.
   - Windows: the rule "my-local-ia (TCP 4000)" must exist in _Windows Defender Firewall → Advanced settings → Inbound rules_, and the network must be **Private** (_Settings → Network & internet_).
4. **Network isolation:** guest Wi-Fi networks and some routers ("AP isolation", "client isolation") block access between devices. Test from a computer connected by cable to the same router.
5. **Server with a public IP:** the installer does not open the port in that case. See _Publishing on the internet_ in the installation guide.

---

## 7. Accounts and passwords

### I forgot the administrator password

- Run the installer and choose **6) Reset a user's password**: type the e-mail and the new password. Works with the default database.

### New users cannot log in

- **Cause:** new sign-ups stay **pending**.
- **Solution:** **Admin Panel → Users** → change the role of the person from _pending_ to _user_. To change the default: **Admin Panel → Settings → General → Default user role**.

### The sign-up link does not appear on the login page

- **Cause:** after the first administrator is created, sign-up may be disabled.
- **Solution:** **Admin Panel → Settings → General → Enable new sign-ups**, or create accounts yourself in **Admin Panel → Users**.

### Everyone was logged out after reinstalling

- **Cause:** the secret key changed (for example, after deleting `/etc/my-local-ia` or `C:\ProgramData\my-local-ia`).
- **Solution:** nothing is lost; everyone just logs in again.

---

## 8. Updates, backups and moving to another server

### "The new version did not start. Going back to the previous one…"

- **Cause:** the new image failed to start. The installer automatically put the previous version back.
- **Solution:**
  1. Check that my-local-ia works (Verify).
  2. If the previous version also fails, the new version may have already converted the database: choose **5) Restore** and pick the backup made just before the update.
  3. Send the logs (section 11) before trying the update again.

### Restoring a backup by hand

If the installer cannot be used (Linux; adjust the file name):

```bash
docker stop my-local-ia
docker run --rm -v my-local-ia-data:/data -v /var/backups/my-local-ia:/backup alpine:3.20 \
  sh -c "find /data -mindepth 1 -delete && tar xzf /backup/my-local-ia-data-YYYYMMDD-HHMMSS.tar.gz -C /data"
docker start my-local-ia
```

### Moving my-local-ia to another server

1. Old server: installer → **4) Back up data now**.
2. Copy the `.tar.gz` file to the new server, into `/var/backups/my-local-ia/` (Windows: `C:\ProgramData\my-local-ia\backups\`).
3. New server: installer → **1) Install**.
4. New server: installer → **5) Restore**, choose the copied file.

---

## 9. The my-local-ia image

### "Could not download ghcr.io/<user>/my-local-ia…"

- **Causes:**
  - The GitHub repository has not built the image yet (the build runs in GitHub Actions and takes 20–40 minutes).
  - The image package is **private**.
  - The GitHub user was typed wrong.
- **Solution:**
  1. On GitHub, open the repository → **Actions**: the latest "build" must be green.
  2. Open your profile → **Packages** → `my-local-ia` → **Package settings** → **Change visibility** → **Public**.
  3. Run **Update** again and choose my-local-ia. Meanwhile, the official version keeps working.

### "The build failed" (image built on the server)

The installed version keeps working: the container is only swapped after the new image is ready. The log shows the exact step (look for the last lines with `ERROR` or `error`).

| What the log shows                                                  | Cause                                    | Fix                                                                                                                             |
| ------------------------------------------------------------------- | ---------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| `JavaScript heap out of memory` or `Killed` during `npm run build`  | Not enough memory to build the interface | Close other programs or give the VM more RAM; on Windows, raise the WSL memory (file `%UserProfile%\.wslconfig`, `memory=12GB`) |
| `no space left on device`                                           | The disk filled up during the build      | Free about 25 GB (see section 10) and run again; `docker builder prune -f` removes old caches                                   |
| `Could not resolve host` / `fatal: unable to access` / `curl: (22)` | No internet or wrong address/branch      | Check the repository address and the branch; open the address in a browser                                                      |
| Error in `pip install` or `npm ci`                                  | Temporary network failure                | Run again: the steps that already worked are cached                                                                             |

---

## 10. Disk space

### "no space left on device" / "Less than 30 GB free"

- **See what uses space:**

  ```bash
  df -h /                      # free space
  docker system df             # images, containers and volumes
  ollama list                  # models and their sizes
  ```

- **Free space safely:**
  - Remove models you do not use: `ollama rm <model>`.
  - Remove Docker images that are no longer used (old versions after updates): `docker image prune -a`. This does **not** delete your data (volumes).
  - Remove old backups in `/var/backups/my-local-ia/` (the installer already keeps only the newest 5).
- **Never** run `docker volume prune` or `docker system prune --volumes` without a backup: they can delete the `my-local-ia-data` volume.

---

## 11. Asking for help

Send:

1. The **report** created by **3) Verify** (path shown at the end of Verify).
2. The **installer log** (`/var/log/my-local-ia-install.log` or `C:\ProgramData\my-local-ia\logs\install.log`).
3. What you were doing and the exact message on the screen (a screenshot helps).

The report and the log never contain passwords or the secret key. They do contain IP addresses and names of models and folders: remove anything you do not want to share.
