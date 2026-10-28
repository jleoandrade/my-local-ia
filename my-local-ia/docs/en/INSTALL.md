# my-local-ia — Installation guide

[Português](../pt-BR/INSTALL.md) · [Español](../es/INSTALL.md) · Troubleshooting: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

This guide installs **my-local-ia** on a server that already runs **Ollama**. You do not need to know Docker or Linux commands beyond copying a file and running one command: the installer asks everything it needs, shows every step and asks before changing anything.

---

## Contents

1. [What gets installed](#1-what-gets-installed)
2. [Requirements](#2-requirements)
3. [Before you start: a 2-minute check](#3-before-you-start-a-2-minute-check)
4. [Installing on Linux](#4-installing-on-linux)
5. [Installing on Windows](#5-installing-on-windows)
6. [What each step of the installer does](#6-what-each-step-of-the-installer-does)
7. [First access](#7-first-access)
8. [The installer menu: update, verify, backup, restore, password, uninstall](#8-the-installer-menu)
9. [Switching from the official version to my-local-ia](#9-switching-from-the-official-version-to-my-local-ia)
10. [Where everything is stored](#10-where-everything-is-stored)
11. [Simulation mode](#11-simulation-mode)
12. [Publishing on the internet (later)](#12-publishing-on-the-internet-later)
13. [Security notes](#13-security-notes)
14. [Useful commands](#14-useful-commands)

---

## 1. What gets installed

```
 Browser (any computer on your network)
        │  http://SERVER-IP:4000
        ▼
 ┌──────────────────────────────┐
 │ my-local-ia (Docker container)│  web interface, users, chats, documents
 │ Open WebUI official image or  │
 │ the my-local-ia build         │
 └──────────────┬───────────────┘
                │  http://127.0.0.1:11434
                ▼
 ┌──────────────────────────────┐
 │ Ollama (already installed)   │  runs the AI models
 └──────────────┬───────────────┘
                ▼
          NVIDIA GPU (VRAM)
```

- **my-local-ia** is the web interface. It runs inside a Docker container called `my-local-ia` and keeps its data (users, chats, settings, uploaded files) in a Docker volume called `my-local-ia-data`.
- **Ollama** keeps running exactly as it is. The installer never changes your models.
- There are two versions:
  - **Official Open WebUI**: the original project, recommended while the my-local-ia build is not published yet.
  - **my-local-ia**: Open WebUI plus the my-local-ia features (hardware-aware model catalog, simulator, disk monitoring…), built from your GitHub repository.

  You can switch between them at any time with the **Update** option, without losing data.

> **License note.** my-local-ia is based on Open WebUI. Its license requires keeping the "Open WebUI" name and logo in the interface, except for deployments with up to 50 users in a 30-day period (or with written permission / an enterprise license).

---

## 2. Requirements

### Linux server (installer: `install-my-local-ia.sh`)

| Item     | Requirement                                                                                                                                                      |
| -------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| System   | Ubuntu 20.04 or newer, Debian 11 or newer and derivatives (Linux Mint, Pop!\_OS…), Fedora, RHEL / Rocky / AlmaLinux / CentOS Stream 8 or newer. 64-bit (x86_64). |
| Access   | A user that can run `sudo`.                                                                                                                                      |
| GPU      | NVIDIA card with the driver installed (`nvidia-smi` must work). Without a GPU it still installs, but in CPU mode.                                                |
| Ollama   | Installed and running on the same server.                                                                                                                        |
| Disk     | At least **30 GB free** (the GPU image is about 6 GB; models are extra).                                                                                         |
| RAM      | 8 GB minimum, 16 GB or more recommended.                                                                                                                         |
| Internet | Needed during installation and updates (to download Docker and the image).                                                                                       |

Docker and the NVIDIA Container Toolkit **do not need to be installed**: the installer installs them if they are missing (after asking).

### Windows computer (installer: `install-my-local-ia.ps1`)

| Item           | Requirement                                                                                                                                                       |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| System         | Windows 10 version 2004 (build 19041) or newer, or Windows 11 — Home, Pro or Enterprise. **Windows Server is not supported** (Docker Desktop does not run on it). |
| Access         | An account with administrator rights.                                                                                                                             |
| Virtualization | Enabled in the BIOS/UEFI. If Windows itself is a virtual machine, _nested virtualization_ must be enabled in the hypervisor.                                      |
| GPU            | NVIDIA card with an up-to-date Windows driver.                                                                                                                    |
| Ollama         | Ollama for Windows, installed and running.                                                                                                                        |
| Disk           | At least **30 GB free** on C:.                                                                                                                                    |
| Internet       | Needed during installation and updates.                                                                                                                           |

Docker Desktop and WSL 2 are installed by the installer if they are missing (Windows has to restart once in that case).

> **Docker Desktop license:** free for personal use, education, open source and companies with fewer than 250 employees **and** less than US$10 million in annual revenue. Larger companies need a paid subscription. On Linux, Docker Engine has no such restriction.

---

## 3. Before you start: a 2-minute check

On the server, confirm that the GPU and Ollama work. If one of these fails, fix it first (see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)).

**Linux**

```bash
nvidia-smi                      # must show your GPU, e.g. "NVIDIA GeForce RTX 3060 … 12288MiB"
ollama list                     # must list your models (an empty list is fine)
curl http://127.0.0.1:11434     # must answer "Ollama is running"
```

**Windows** (PowerShell)

```powershell
nvidia-smi
ollama list
curl.exe http://127.0.0.1:11434
```

---

## 4. Installing on Linux

### 4.1 Copy the installer to the server

Put `install-my-local-ia.sh` in the server's `/tmp` folder. Some ways to do it:

- **From Windows, macOS or Linux with `scp`** (replace `user` and `192.168.1.50`):

  ```bash
  scp install-my-local-ia.sh user@192.168.1.50:/tmp/
  ```

- **From Windows with WinSCP or FileZilla**: connect with SFTP to the server and drag the file to `/tmp`.

> `/tmp` is only where the installer starts from. It saves everything important outside it (see [section 10](#10-where-everything-is-stored)), because `/tmp` is usually emptied when the server restarts.

### 4.2 (Recommended) Use `tmux` if you are connected by SSH

If your SSH connection drops in the middle of the installation, the installer stops. `tmux` keeps it running:

```bash
sudo apt install -y tmux     # Ubuntu/Debian   (Fedora/RHEL: sudo dnf install -y tmux)
tmux new -s install
```

If the connection drops, reconnect and run `tmux attach -t install` to see the installer again.

### 4.3 Run the installer

```bash
sudo bash /tmp/install-my-local-ia.sh
```

1. Choose the language (English, Português or Español).
2. Choose **1) Install**.
3. Answer the questions. Press **Enter** to accept the value shown in brackets, e.g. `Port to access my-local-ia [4000]:`.
4. At the end, the installer shows the address to open in the browser.

The installation takes 5 to 20 minutes, mostly to download the image (several GB) and on the first start.

---

## 5. Installing on Windows

### 5.1 Copy the installer

Create the folder `C:\temp` and put `install-my-local-ia.ps1` in it.

### 5.2 Open PowerShell as administrator

Start menu → type **PowerShell** → right-click **Windows PowerShell** → **Run as administrator**.

### 5.3 Run the installer

```powershell
powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1
```

`-ExecutionPolicy Bypass` lets this one script run without changing the security policy of the computer. If Windows says the file was downloaded from the internet and is blocked, unblock it first:

```powershell
Unblock-File C:\temp\install-my-local-ia.ps1
```

Then choose the language and **1) Install**, as on Linux.

### 5.4 What is different on Windows

- **WSL 2 and Docker Desktop.** If they are missing, the installer installs them with `winget` and asks you to **restart Windows**. After the restart, run the same command again and choose **Install**: it continues with the answers you already gave.
- **Docker Desktop terms.** The first time Docker Desktop opens, it shows a window with its terms. Accept them; the installer waits up to 5 minutes for Docker to be ready.
- **Ollama and Docker.** By default, Ollama on Windows only accepts connections from the computer itself. If the container cannot reach it, the installer offers to set `OLLAMA_HOST=0.0.0.0:11434` for your user and restart Ollama.
- **Firewall and network type.** The installer creates a Windows firewall rule for the port, valid for **Private** and **Domain** networks. If Windows classifies your network as **Public**, the rule does not apply: change it in _Settings → Network & internet → (your connection) → Private network_.
- **Port inside the container.** On Windows, the container listens on 8080 and Docker publishes it on the port you choose (4000 by default). On Linux, it listens directly on the chosen port.

---

## 6. What each step of the installer does

The installation has 11 numbered steps. Everything that changes the system is shown (lines starting with `$` or `>`) and confirmed with you first.

| Step                      | What happens                                                                                                                                                           | Changes the system? |
| ------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------- |
| 1. Checking this server   | Shows system, CPU, RAM, free disk, internet access, GPU and driver, Ollama (version, number of models, models folder), Docker and the network (local IP or public IP). | No                  |
| 2. Questions              | Version (official or my-local-ia), port (default **4000**), Ollama address, Ollama models folder. Then a summary and a confirmation.                                   | Saves your answers  |
| 3. Docker                 | Installs Docker from the official Docker repository if missing (Linux) or Docker Desktop (Windows).                                                                    | Yes, if missing     |
| 4. GPU support            | Linux: installs and configures the NVIDIA Container Toolkit if missing. Both: runs a test container that must see the GPU.                                             | Yes, if missing     |
| 5. Configuration files    | Creates the configuration and a random **secret key** (used to sign logins). Kept on updates so nobody is logged out.                                                  | Yes                 |
| 6. Downloading the image  | Downloads the image (official: `ghcr.io/open-webui/open-webui:cuda`).                                                                                                  | Yes                 |
| 7. Starting               | Starts the container **reachable only from the server itself** and waits until it answers.                                                                             | Yes                 |
| 8. Administrator account  | Asks name, e-mail and password (hidden, typed twice) and creates the first user, who becomes administrator. Skipped if users already exist.                            | Yes                 |
| 9. Opening to the network | Restarts the container so other computers can access it.                                                                                                               | Yes                 |
| 10. Firewall              | Local network: allows the port only for your local network (ufw, firewalld or Windows firewall). Public IP: does **not** open the port.                                | Yes, if confirmed   |
| 11. Final tests           | Container running, web interface answering, GPU visible in the container, connection to Ollama, number of models.                                                      | No                  |

**Why steps 7 and 9 are separate:** the first person who creates an account becomes administrator. Between starting the container and creating your account, the installer keeps my-local-ia reachable only from the server itself, so nobody else on the network can take the administrator account first.

**How the installer detects the access type:** it looks at the IP address of the server. Addresses like `192.168.x.x`, `10.x.x.x` and `172.16–31.x.x` are local networks: the port is opened only for that network. Any other address is public: the port is not opened, and a message points to [section 12](#12-publishing-on-the-internet-later).

---

## 7. First access

1. On any computer of the network, open `http://SERVER-IP:4000` (the installer shows the exact address at the end).
2. Log in with the administrator e-mail and password.
3. Choose a model at the top of the screen and start chatting. The models are the ones installed in Ollama (`ollama list`).

**Adding people**

- **Admin Panel → Users → +**: create the account yourself and give the password to the person; or
- let people sign up on the login page. New accounts stay **pending** until an administrator approves them in **Admin Panel → Users** (change the role from _pending_ to _user_). The sign-up switch and the default role are in **Admin Panel → Settings → General**.

**Checking the connection to Ollama:** **Admin Panel → Settings → Connections**. The Ollama address must be the one shown by the installer (`http://127.0.0.1:11434` on Linux, `http://host.docker.internal:11434` on Windows).

---

## 8. The installer menu

Run the installer again whenever you need one of these options. It remembers your previous answers.

| Option                             | What it does                                                                                                                                                                                                         |
| ---------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **1) Install**                     | Installs, or recreates the container keeping all data.                                                                                                                                                               |
| **2) Update or switch version**    | Downloads the newest image (same version, official or my-local-ia), offers a **backup**, replaces the container and tests it. If the new version does not start, it **goes back to the previous one automatically**. |
| **3) Verify**                      | Diagnostics only: checks everything and saves a **report** file to send when asking for help. Changes nothing.                                                                                                       |
| **4) Back up data now**            | Saves users, chats, settings and uploaded files to a `.tar.gz` file. my-local-ia stops for a few seconds. The 5 newest backups are kept.                                                                             |
| **5) Restore a backup**            | Lists the backups and restores the one you choose (replaces the current data, after confirmation).                                                                                                                   |
| **6) Reset a user's password**     | Sets a new password for any user, including the administrator.                                                                                                                                                       |
| **7) Uninstall**                   | Removes the container and the firewall rule. Data is deleted only if you confirm and type `DELETE`, and a backup is offered first. Docker, Ollama and your models are never removed.                                 |
| **8) Optimize Ollama**             | Turns on flash attention and the compressed context (`q8_0`) in the Ollama service: a conversation takes about half the GPU memory. Run it again to undo. See below.                                                 |
| **9) Unlock the GPU tensor cores** | Installs gpu-unlock (GeForce RTX 20/30/40) and turns it on at boot. Advanced; run it again to see its state or undo it. See below.                                                                                   |

### Optional improvements (options 8 and 9, Linux only)

#### 8) Optimize Ollama

Turns on two settings in the Ollama service, in a file of its own (`/etc/systemd/system/ollama.service.d/my-local-ia.conf`):

- `OLLAMA_FLASH_ATTENTION=1`: a more economical way to compute attention.
- `OLLAMA_KV_CACHE_TYPE=q8_0`: keeps the conversation memory (context) compressed.

Together they make the context take about half the GPU memory: longer chats fit and more of each model stays on the GPU. Answers stay the same. The installer restarts Ollama (answers in progress are interrupted) and checks that it is back. To undo, run option 8 again and choose **Undo**. Your own `sudo systemctl edit ollama` still applies and takes priority.

#### 9) Unlock the GPU tensor cores (gpu-unlock)

GeForce RTX 20, 30 and 40 cards run FP16/BF16/TF32 tensor math at half speed. [gpu-unlock](https://github.com/Zagitta/gpu-unlock), a third-party kernel module, restores the full rate at every boot, before the NVIDIA driver loads. Driver and VBIOS do not change and results are identical.

| Use                                                     | Expected gain |
| ------------------------------------------------------- | ------------- |
| PyTorch FP16/BF16: image generation, fine-tuning        | 25 to 55%     |
| Ollama reading long prompts                             | 0 to 15%      |
| Ollama generating tokens, INT8/INT4 models, FP32, games | none          |

What option 9 does:

1. Checks that the GPU shows up as **PCI Express** and supports the **FLR** reset. If not, it stops and explains (see Proxmox below).
2. Installs `git`, `build-essential` and the kernel headers, downloads gpu-unlock into `/opt/gpu-unlock` and runs `make install` (it builds the `gpu-unlock-dkms` and `gpu-unlock-firmware` packages). It needs internet: it downloads NVIDIA files to generate the firmware. It takes 5 to 15 minutes.
3. Adds `gpu_unlock.targets=all` to `GRUB_CMDLINE_LINUX_DEFAULT` (keeping a copy in `/etc/default/grub.my-local-ia.bak`) and runs `update-grub`.
4. Offers to restart. Then run the installer and choose **3) Verify**: "Optional improvements" shows whether the GPU was unlocked (or run `journalctl -k -b | grep gpu_unlock`; the last line must end in `unlocked`).

**In a Proxmox VM**, the GPU must reach the VM as PCIe. Without that, the unlock fails with error `-95`. On the host:

```bash
qm config <VMID> | grep -E "machine|hostpci"   # needs machine: q35
qm shutdown <VMID>
qm set <VMID> --hostpci0 <GPU address on the host>,pcie=1
qm start <VMID>
```

Install gpu-unlock **inside the VM** (on the host the GPU is held by `vfio-pci`, and the module skips cards that already have a driver).

**Maintenance:** it is applied again at every boot and after suspend; hibernation is not covered. Updating the NVIDIA driver does not affect it. When the kernel is updated, the module is rebuilt if the headers come along (`sudo apt install -y linux-headers-generic`).

**To undo:** run option 9 again and choose **Undo** (removes it from the boot and, if you want, uninstalls the packages). **If the server does not boot:** in the GRUB menu (in Proxmox, from the VM console) press `e`, delete `gpu_unlock.targets=all` from the `linux` line and boot with `Ctrl+X`. Then undo it with option 9.

> gpu-unlock is third-party software, and the firmware it generates derives from NVIDIA material under its own terms (see `firmware/NOTICE.md` in its repository). According to the author the risk is low: the GPU may run slightly warmer, but temperature and power limits stay in place.

---

## 9. Switching from the official version to my-local-ia

When the my-local-ia repository is published on GitHub and its image is built:

1. Run the installer and choose **2) Update or switch version**.
2. Choose **my-local-ia** and type the GitHub user that owns the repository.
3. Accept the backup.

The installer downloads `ghcr.io/<github-user>/my-local-ia:cuda`, keeps all your data and goes back to the previous version if anything fails. If it says the image could not be downloaded, the image is not published yet, or its package is private (see the troubleshooting guide).

### Without GitHub Actions: build the image on the server itself

If you do not want to depend on GitHub Actions (or want to try a change before publishing it), the installer builds the image right here:

1. Run the installer and choose **2) Update or switch version** (or **1) Install** on a new installation).
2. Choose **my-local-ia built here on this server from the source code**.
3. Confirm the GitHub user, the repository address (default: `https://github.com/<user>/my-local-ia`) and the branch (default: `main`).
4. Confirm the build. It takes **20 to 60 minutes** and needs about **25 GB free**.

What happens:

- **Linux:** the code is downloaded with `git` into `/opt/my-local-ia/src` (`git` is installed if missing). Later runs only download the changes.
- **Windows:** the code is downloaded as a ZIP into `C:\ProgramData\my-local-ia\src` (no `git`, so the scripts keep Linux line endings inside the image). The repository must be on GitHub.
- The image is built with the same `Dockerfile` as GitHub Actions, with extra memory for the interface build (half the RAM, between 4 and 12 GB), and is named `my-local-ia:local-cuda` (with GPU) or `my-local-ia:local-main` (without GPU).
- The container swap is the same as a normal update: optional backup, the old container is kept until the new one answers and, if the new one fails, the installer goes back to the old one.
- At the end, the installer offers to remove the build cache and old images to free disk.

To update later: run **Update** and choose **Same version, newest release**. With an image built here, that downloads the new code and builds again.

---

## 10. Where everything is stored

| What                                      | Linux                                          | Windows                                                            |
| ----------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------ |
| Data (users, chats, settings, uploads)    | Docker volume `my-local-ia-data`               | Docker volume `my-local-ia-data`                                   |
| Installer answers                         | `/etc/my-local-ia/installer.conf`              | `C:\ProgramData\my-local-ia\installer.json`                        |
| Container settings and secret key         | `/etc/my-local-ia/my-local-ia.env` (root only) | `C:\ProgramData\my-local-ia\my-local-ia.env` (administrators only) |
| Installer log                             | `/var/log/my-local-ia-install.log`             | `C:\ProgramData\my-local-ia\logs\install.log`                      |
| Diagnostic reports                        | `/var/log/my-local-ia-report-*.txt`            | `C:\ProgramData\my-local-ia\logs\report-*.txt`                     |
| Backups                                   | `/var/backups/my-local-ia/`                    | `C:\ProgramData\my-local-ia\backups\`                              |
| Ollama models (read-only for my-local-ia) | usually `/usr/share/ollama/.ollama/models`     | usually `C:\Users\<you>\.ollama\models`                            |

Passwords are **never** written to the log, the screen or the configuration files.

---

## 11. Simulation mode

To see everything the installer would do, without changing anything:

```bash
sudo bash /tmp/install-my-local-ia.sh --dry-run
```

```powershell
powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1 -DryRun
```

Other options: `--lang en|pt|es` (Linux) and `-Lang en|pt|es` (Windows) choose the language without asking.

---

## 12. Publishing on the internet (later)

The installer only prepares access from the **local network**. If you decide to make my-local-ia reachable from the internet:

- **Preferred: Cloudflare Tunnel.** The `cloudflared` program runs on the server and opens an outgoing connection to Cloudflare, so **no port has to be opened in the router**. Cloudflare provides HTTPS, and you can add **Cloudflare Access** to require an extra login (e-mail code, Google…) before anyone even sees my-local-ia. Guide: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/>
- **If you use port forwarding in the router:** never forward port 4000 directly. Put a reverse proxy with HTTPS (for example Caddy or Nginx) in front, forward only port 443 to it, turn on the Cloudflare proxy (orange cloud) with SSL mode **Full (strict)**, and restrict the router rule to Cloudflare's IP ranges.

In both cases, before publishing:

1. Turn off public sign-up (**Admin Panel → Settings → General**) or keep new users as _pending_.
2. Use strong passwords for every account, especially administrators.
3. Keep my-local-ia updated (**Update** option).
4. Never expose Ollama's port (11434) to the internet: Ollama has no login.

---

## 13. Security notes

- The installer only changes what it shows and you confirm. It never removes Docker, Ollama or models.
- The secret key and the configuration are readable only by root (Linux) or administrators (Windows).
- The administrator password is sent straight to my-local-ia, never on a command line, so it does not appear in the list of processes or in the log.
- On Linux, the container uses the server's network directly (`--network host`) so it can reach Ollama at `127.0.0.1` without exposing Ollama to the network.
- On Windows, if you allow `OLLAMA_HOST=0.0.0.0`, Ollama accepts connections from other computers too, if the Windows firewall allows them. Ollama has no login: keep port 11434 closed to the network in the firewall.

---

## 14. Useful commands

Linux (use `sudo` if your user is not in the `docker` group). On Windows, the same `docker` commands work in PowerShell.

```bash
docker ps                                  # is the my-local-ia container running?
docker logs --tail 100 my-local-ia         # last 100 lines of its log
docker logs -f my-local-ia                 # follow the log live (Ctrl+C to leave)
docker restart my-local-ia                 # restart
docker stop my-local-ia                    # stop
docker start my-local-ia                   # start
docker exec my-local-ia nvidia-smi         # GPU seen from inside the container
docker system df                           # disk used by Docker
ollama ps                                  # loaded models and whether they are on GPU or CPU
```

Open WebUI documentation (the base of my-local-ia): <https://docs.openwebui.com>
