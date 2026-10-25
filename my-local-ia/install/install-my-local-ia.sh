#!/usr/bin/env bash
if [ -f "$0" ] && grep -q $'\r' "$0"; then sed -i 's/\r$//' "$0" 2>/dev/null && exec bash "$0" "$@"; f=$(mktemp); tr -d '\r' <"$0" >"$f"; exec bash "$f" "$@"; fi # Windows line endings (CRLF) break bash: fix them and restart. Must stay on line 2, before any blank line.
# my-local-ia installer for Linux.
#
# Installs Open WebUI (the official image or the my-local-ia build) next to an
# Ollama that is already running on this server, with NVIDIA GPU support, and
# keeps it updated, backed up and diagnosable. Every step is shown on screen,
# every change asks for confirmation and everything is logged.
#
# Usage:  sudo bash install-my-local-ia.sh [--dry-run] [--lang en|pt|es]
#   --dry-run   show every command without changing anything
#   --lang      interface language (default: from the system locale)

set -Eeuo pipefail

readonly CONTAINER="my-local-ia"
readonly PREVIOUS_CONTAINER="my-local-ia-previous"
readonly VOLUME="my-local-ia-data"
readonly DEFAULT_PORT=4000
readonly DEFAULT_OLLAMA_URL="http://127.0.0.1:11434"
readonly CONF_DIR="/etc/my-local-ia"
readonly CONF_FILE="$CONF_DIR/installer.conf"
readonly ENV_FILE="$CONF_DIR/my-local-ia.env"
readonly BACKUP_DIR="/var/backups/my-local-ia"
readonly OFFICIAL_IMAGE_GPU="ghcr.io/open-webui/open-webui:cuda"
readonly OFFICIAL_IMAGE_CPU="ghcr.io/open-webui/open-webui:main"
readonly CUSTOM_IMAGE_NAME="my-local-ia"  # published as ghcr.io/<github user>/my-local-ia
readonly HEALTH_TIMEOUT=900                # first start can take minutes (it downloads models)
readonly MIN_FREE_GB=30
readonly KEEP_BACKUPS=5
readonly GPU_TEST_IMAGE="ubuntu:24.04"
readonly HELPER_IMAGE="alpine:3.20"

LOG_FILE="/var/log/my-local-ia-install.log"
DRY_RUN=0
READ_ONLY=0       # Verify never changes anything
LANG_CODE=""
STEP=0
STEP_TOTAL=0

# Settings saved in $CONF_FILE between runs.
IMAGE_KIND=""      # official | custom
GITHUB_USER=""
IMAGE=""
PORT=""
OLLAMA_URL=""
MODELS_DIR=""
USE_GPU=""         # yes | no

# Filled by the checks.
OS_ID="" OS_LIKE="" OS_NAME="" PKG="" DOCKER_DISTRO="" DOCKER_CODENAME=""
LAN_IP="" LAN_SUBNET="" ACCESS_MODE=""
GPU_LIST="" GPU_DRIVER="" HAS_NVIDIA_HW=0
SAVED_PORT=""
ADMIN_TOKEN=""

############################################
# Messages (English, Portuguese, Spanish)
############################################

# MSG_pt and MSG_es are read through the nameref in t().
# shellcheck disable=SC2034
declare -A MSG_en MSG_pt MSG_es

MSG_en=(
  [title]="my-local-ia installer (Open WebUI + Ollama)"
  [dry_run_banner]="SIMULATION MODE: commands are shown, nothing is changed."
  [choose_lang]="Language / Idioma"
  [menu_title]="What do you want to do?"
  [menu_install]="Install"
  [menu_update]="Update or switch version (official / my-local-ia)"
  [menu_verify]="Verify (diagnostics only, changes nothing)"
  [menu_backup]="Back up data now"
  [menu_restore]="Restore a backup"
  [menu_reset_pw]="Reset a user's password"
  [menu_uninstall]="Uninstall"
  [menu_exit]="Exit"
  [menu_prompt]="Option"
  [invalid_option]="Invalid option."
  [yes_default]="Y/n"
  [no_default]="y/N"
  [continue_q]="Continue?"
  [cancelled]="Cancelled. Nothing else was changed."
  [interrupted]="Interrupted. Run the script again: it reuses the answers already given."
  [error_at]="Error in: %s"
  [see_log]="Full log: %s"
  [see_docs]="Help: docs/%s/TROUBLESHOOTING.md (in the my-local-ia folder)"
  [need_root]="Run this script as root: sudo bash %s"
  [log_at]="Log of this run: %s"
  [ssh_hint]="You are connected over SSH. If the connection drops, the installation stops. Tip: run it inside 'tmux' or 'screen'."
  [step_checks]="Checking this server (changes nothing)"
  [step_questions]="Questions"
  [step_docker]="Docker"
  [step_gpu]="GPU support for containers (NVIDIA Container Toolkit)"
  [step_config]="Configuration files"
  [step_pull]="Downloading the image"
  [step_start]="Starting (only reachable from this server for now)"
  [step_admin]="Administrator account"
  [step_open]="Opening to the local network"
  [step_firewall]="Firewall"
  [step_tests]="Final tests"
  [step_replace]="Switching to the new version"
  [os]="System: %s"
  [os_unsupported]="This distribution is not supported by the automatic Docker installation (%s). Supported: Ubuntu, Debian and derivatives, Fedora, RHEL, Rocky, Alma, CentOS Stream."
  [cpu]="CPU: %s (%s threads)"
  [ram]="RAM: %s GB"
  [disk]="Free disk on %s: %s GB"
  [disk_low]="Less than %s GB free. The GPU image alone takes about 6 GB, plus your models."
  [curl_missing]="'curl' is missing and is needed to continue."
  [install_curl_q]="Install curl now?"
  [internet_ok]="Internet: OK (image registry reachable)"
  [internet_fail]="Could not reach ghcr.io (image registry). Check the internet connection, DNS or proxy."
  [gpu_found]="GPU: %s"
  [gpu_driver]="NVIDIA driver: %s"
  [gpu_no_driver]="An NVIDIA card was found, but the driver is not installed (nvidia-smi is missing)."
  [gpu_none]="No NVIDIA GPU found. Open WebUI will run without GPU (models still run in Ollama)."
  [gpu_continue_cpu_q]="Continue without GPU support? (Install the NVIDIA driver first for full speed.)"
  [ollama_ok]="Ollama %s is answering at %s"
  [ollama_models]="Ollama models installed: %s"
  [ollama_dir]="Ollama models folder: %s"
  [ollama_dir_missing]="Ollama models folder not found. Disk monitoring will not see the models."
  [ollama_down]="Ollama is not answering at %s."
  [ollama_start_q]="The 'ollama' service exists but is stopped. Start it now?"
  [ollama_missing]="Ollama does not seem to be installed. Open WebUI will start, but without local models."
  [ollama_continue_q]="Continue anyway?"
  [docker_ok]="Docker: %s"
  [docker_missing]="Docker is not installed."
  [docker_stopped]="Docker is installed but not running."
  [toolkit_ok]="NVIDIA Container Toolkit: installed and configured in Docker"
  [toolkit_missing]="NVIDIA Container Toolkit: not installed"
  [toolkit_unconfigured]="NVIDIA Container Toolkit: installed, but not configured in Docker"
  [net_lan]="Network: local network (IP %s, network %s)"
  [net_public]="Network: this server has a PUBLIC IP (%s). The port will NOT be opened in the firewall automatically."
  [net_unknown]="Network: could not detect the IP address."
  [existing_install]="my-local-ia is already installed on this server."
  [existing_what]="Use 'Update' to change version, 'Verify' to diagnose, or reinstall (data is kept)."
  [reinstall_q]="Recreate the container now? Users, chats and settings are kept."
  [q_version]="Which version do you want to install?"
  [q_version_official]="Official Open WebUI (recommended for now)"
  [q_version_custom]="my-local-ia (custom build from your GitHub repository)"
  [q_github_user]="Your GitHub user (owner of the my-local-ia repository)"
  [q_port]="Port to access my-local-ia"
  [port_invalid]="Invalid port. Use a number between 1024 and 65535."
  [port_busy]="Port %s is already in use on this server. Choose another one."
  [q_ollama_url]="Ollama address"
  [q_models_dir]="Ollama models folder"
  [q_admin_intro]="Administrator account of my-local-ia (the first user, with full access)."
  [q_admin_name]="Administrator name"
  [q_admin_email]="Administrator e-mail (used to log in)"
  [email_invalid]="Invalid e-mail."
  [q_admin_pw]="Password (minimum 8 characters, hidden)"
  [q_admin_pw2]="Repeat the password"
  [pw_short]="The password must have at least 8 characters."
  [pw_mismatch]="The passwords do not match."
  [pw_invalid_chars]="The password cannot contain control characters."
  [summary_title]="Summary of what will be done:"
  [summary_image]="Image: %s"
  [summary_port]="Address: http://%s:%s"
  [summary_gpu]="GPU: %s"
  [summary_ollama]="Ollama: %s"
  [gpu_off]="not used"
  [docker_install_q]="Install Docker now (official Docker repository)?"
  [docker_installed]="Docker installed and running."
  [docker_start_q]="Start Docker now?"
  [docker_required]="Docker is required. Stopping here."
  [podman_conflict_q]="The 'podman-docker' package conflicts with Docker. Remove it?"
  [toolkit_install_q]="Install the NVIDIA Container Toolkit (lets containers use the GPU)?"
  [toolkit_configure_q]="Configure the NVIDIA runtime in Docker and restart Docker?"
  [gpu_test]="Testing the GPU inside a container…"
  [gpu_test_ok]="The GPU is visible inside containers."
  [gpu_test_fail]="The GPU is NOT visible inside containers. See 'GPU not visible in the container' in the troubleshooting guide."
  [gpu_skip]="No GPU: skipping this step."
  [config_written]="Configuration saved in %s (readable only by root)."
  [secret_kept]="Existing secret key kept (users stay logged in)."
  [secret_new]="New secret key generated."
  [pull_q]="Download %s now? (several GB the first time)"
  [pull_ok]="Image downloaded."
  [pull_fail_custom]="Could not download %s. The my-local-ia image is probably not published yet. Install the official version now and switch later with 'Update'."
  [pull_fail]="Could not download the image. Check the internet connection and the log."
  [start_q]="Create and start the container now?"
  [waiting]="Waiting for my-local-ia to answer (up to %s min)…"
  [waiting_progress]="still starting… %ss (the first start downloads extra files and can take several minutes)"
  [health_ok]="my-local-ia is answering."
  [health_timeout]="my-local-ia did not answer in time. Last lines of its log:"
  [container_died]="The container stopped while starting. Last lines of its log:"
  [admin_exists]="Users already exist: the administrator account is kept as it is."
  [admin_created]="Administrator created: %s"
  [admin_failed]="Could not create the administrator. Answer from the server: %s"
  [open_q]="Restart my-local-ia so other computers on the network can access it?"
  [opened]="my-local-ia now accepts connections on port %s."
  [fw_ufw_q]="Allow port %s in ufw, only for the local network %s?"
  [fw_firewalld_q]="Allow port %s in firewalld, only for the local network %s?"
  [fw_none]="No active firewall (ufw/firewalld) found. Any device that can reach this server can open the port."
  [fw_public_skip]="Public IP: the port was not opened. To publish it, see 'Publishing on the internet' in the installation guide."
  [fw_done]="Firewall rule created."
  [test_container]="Container running: %s (image %s)"
  [test_container_fail]="The container is not running."
  [test_health]="Web interface answering on port %s"
  [test_health_fail]="Web interface is not answering on port %s"
  [test_gpu]="GPU inside the container: %s"
  [test_gpu_fail]="GPU not visible inside the container."
  [test_ollama]="Connection from my-local-ia to Ollama: OK"
  [test_ollama_fail]="my-local-ia cannot reach Ollama at %s"
  [test_models]="Models visible in my-local-ia: %s"
  [test_listen]="Listening on all network interfaces (port %s)"
  [test_listen_local]="Listening only on this server (port %s)"
  [test_hw]="Hardware detected by my-local-ia: %s"
  [done_title]="Done!"
  [done_url]="Open in a browser: http://%s:%s"
  [done_login]="Log in with: %s"
  [done_users]="To add people: Admin Panel → Users. New sign-ups stay pending until an admin approves them."
  [done_update]="To update or switch to my-local-ia later: run this script again and choose 'Update'."
  [report_saved]="Report saved in %s (send this file when asking for help)."
  [not_installed]="my-local-ia is not installed on this server."
  [update_current]="Installed image: %s"
  [q_update_version]="Which version do you want?"
  [q_update_keep]="Same version, newest release"
  [backup_q]="Make a backup before updating? (recommended)"
  [backup_stop_note]="my-local-ia stops for a few seconds during the backup."
  [backup_done]="Backup saved: %s (%s)"
  [backup_cleanup]="Old backups removed (keeping the newest %s)."
  [backup_none]="No backups found in %s."
  [backup_list]="Available backups:"
  [q_backup_pick]="Number of the backup to restore"
  [restore_warn]="The current data (users, chats, settings) will be REPLACED by the backup."
  [restore_done]="Backup restored."
  [update_swap]="Replacing the container (the old one is kept until the new one answers)…"
  [update_ok]="Update finished. Image: %s"
  [update_rollback]="The new version did not start. Going back to the previous one…"
  [rollback_done]="Previous version restored. If the data was already converted by the new version, restore the backup made before the update (option 'Restore')."
  [q_reset_email]="E-mail of the user"
  [reset_done]="Password changed for %s."
  [reset_notfound]="No user with the e-mail %s."
  [reset_unsupported]="This option only works with the default database (SQLite)."
  [uninstall_warn]="This removes the my-local-ia container. Docker, Ollama and your models are NOT touched."
  [uninstall_q]="Remove the container?"
  [uninstall_data_q]="Also DELETE all data (users, chats, settings)? This cannot be undone."
  [uninstall_data_confirm]="Type DELETE to confirm"
  [uninstall_backup_q]="Make a backup before deleting?"
  [uninstall_conf_q]="Remove the configuration in %s?"
  [uninstall_done]="my-local-ia removed."
  [data_kept]="Data kept in the Docker volume '%s'. Installing again reuses it."
  [verify_title]="Diagnostics"
  [verify_ok]="Everything OK."
  [verify_problems]="%s problem(s) found. See the messages above and the troubleshooting guide."
)

# shellcheck disable=SC2034
MSG_pt=(
  [title]="Instalador do my-local-ia (Open WebUI + Ollama)"
  [dry_run_banner]="MODO SIMULAÇÃO: os comandos são mostrados, nada é alterado."
  [choose_lang]="Language / Idioma"
  [menu_title]="O que você quer fazer?"
  [menu_install]="Instalar"
  [menu_update]="Atualizar ou trocar de versão (oficial / my-local-ia)"
  [menu_verify]="Verificar (só diagnóstico, não muda nada)"
  [menu_backup]="Fazer backup dos dados agora"
  [menu_restore]="Restaurar um backup"
  [menu_reset_pw]="Redefinir a senha de um usuário"
  [menu_uninstall]="Desinstalar"
  [menu_exit]="Sair"
  [menu_prompt]="Opção"
  [invalid_option]="Opção inválida."
  [yes_default]="S/n"
  [no_default]="s/N"
  [continue_q]="Continuar?"
  [cancelled]="Cancelado. Nada mais foi alterado."
  [interrupted]="Interrompido. Rode o script de novo: ele reaproveita as respostas já dadas."
  [error_at]="Erro em: %s"
  [see_log]="Log completo: %s"
  [see_docs]="Ajuda: docs/%s/TROUBLESHOOTING.md (na pasta my-local-ia)"
  [need_root]="Rode este script como root: sudo bash %s"
  [log_at]="Log desta execução: %s"
  [ssh_hint]="Você está conectado por SSH. Se a conexão cair, a instalação para. Dica: rode dentro do 'tmux' ou do 'screen'."
  [step_checks]="Verificando este servidor (não muda nada)"
  [step_questions]="Perguntas"
  [step_docker]="Docker"
  [step_gpu]="Suporte à placa de vídeo nos contêineres (NVIDIA Container Toolkit)"
  [step_config]="Arquivos de configuração"
  [step_pull]="Baixando a imagem"
  [step_start]="Iniciando (por enquanto, acessível só por este servidor)"
  [step_admin]="Conta de administrador"
  [step_open]="Liberando para a rede local"
  [step_firewall]="Firewall"
  [step_tests]="Testes finais"
  [step_replace]="Trocando para a nova versão"
  [os]="Sistema: %s"
  [os_unsupported]="Esta distribuição não é suportada pela instalação automática do Docker (%s). Suportadas: Ubuntu, Debian e derivadas, Fedora, RHEL, Rocky, Alma, CentOS Stream."
  [cpu]="Processador: %s (%s threads)"
  [ram]="RAM: %s GB"
  [disk]="Disco livre em %s: %s GB"
  [disk_low]="Menos de %s GB livres. Só a imagem com GPU ocupa uns 6 GB, fora os seus modelos."
  [curl_missing]="O 'curl' não está instalado e é necessário para continuar."
  [install_curl_q]="Instalar o curl agora?"
  [internet_ok]="Internet: OK (repositório de imagens acessível)"
  [internet_fail]="Não foi possível acessar o ghcr.io (repositório de imagens). Verifique a internet, o DNS ou o proxy."
  [gpu_found]="Placa de vídeo: %s"
  [gpu_driver]="Driver NVIDIA: %s"
  [gpu_no_driver]="Foi encontrada uma placa NVIDIA, mas o driver não está instalado (falta o nvidia-smi)."
  [gpu_none]="Nenhuma placa NVIDIA encontrada. O Open WebUI vai rodar sem GPU (os modelos continuam rodando no Ollama)."
  [gpu_continue_cpu_q]="Continuar sem suporte à placa de vídeo? (Para velocidade total, instale antes o driver NVIDIA.)"
  [ollama_ok]="Ollama %s respondendo em %s"
  [ollama_models]="Modelos instalados no Ollama: %s"
  [ollama_dir]="Pasta de modelos do Ollama: %s"
  [ollama_dir_missing]="Pasta de modelos do Ollama não encontrada. O monitoramento de disco não vai enxergar os modelos."
  [ollama_down]="O Ollama não está respondendo em %s."
  [ollama_start_q]="O serviço 'ollama' existe, mas está parado. Iniciar agora?"
  [ollama_missing]="O Ollama parece não estar instalado. O Open WebUI vai abrir, mas sem modelos locais."
  [ollama_continue_q]="Continuar mesmo assim?"
  [docker_ok]="Docker: %s"
  [docker_missing]="O Docker não está instalado."
  [docker_stopped]="O Docker está instalado, mas parado."
  [toolkit_ok]="NVIDIA Container Toolkit: instalado e configurado no Docker"
  [toolkit_missing]="NVIDIA Container Toolkit: não instalado"
  [toolkit_unconfigured]="NVIDIA Container Toolkit: instalado, mas não configurado no Docker"
  [net_lan]="Rede: rede local (IP %s, rede %s)"
  [net_public]="Rede: este servidor tem IP PÚBLICO (%s). A porta NÃO será liberada no firewall automaticamente."
  [net_unknown]="Rede: não foi possível detectar o endereço IP."
  [existing_install]="O my-local-ia já está instalado neste servidor."
  [existing_what]="Use 'Atualizar' para trocar de versão, 'Verificar' para diagnosticar, ou reinstale (os dados são mantidos)."
  [reinstall_q]="Recriar o contêiner agora? Usuários, conversas e configurações são mantidos."
  [q_version]="Qual versão você quer instalar?"
  [q_version_official]="Open WebUI oficial (recomendado por enquanto)"
  [q_version_custom]="my-local-ia (versão personalizada do seu repositório no GitHub)"
  [q_github_user]="Seu usuário do GitHub (dono do repositório my-local-ia)"
  [q_port]="Porta de acesso ao my-local-ia"
  [port_invalid]="Porta inválida. Use um número entre 1024 e 65535."
  [port_busy]="A porta %s já está em uso neste servidor. Escolha outra."
  [q_ollama_url]="Endereço do Ollama"
  [q_models_dir]="Pasta de modelos do Ollama"
  [q_admin_intro]="Conta de administrador do my-local-ia (o primeiro usuário, com acesso total)."
  [q_admin_name]="Nome do administrador"
  [q_admin_email]="E-mail do administrador (usado no login)"
  [email_invalid]="E-mail inválido."
  [q_admin_pw]="Senha (mínimo de 8 caracteres, oculta)"
  [q_admin_pw2]="Repita a senha"
  [pw_short]="A senha precisa ter pelo menos 8 caracteres."
  [pw_mismatch]="As senhas não conferem."
  [pw_invalid_chars]="A senha não pode ter caracteres de controle."
  [summary_title]="Resumo do que será feito:"
  [summary_image]="Imagem: %s"
  [summary_port]="Endereço: http://%s:%s"
  [summary_gpu]="Placa de vídeo: %s"
  [summary_ollama]="Ollama: %s"
  [gpu_off]="não usada"
  [docker_install_q]="Instalar o Docker agora (repositório oficial do Docker)?"
  [docker_installed]="Docker instalado e rodando."
  [docker_start_q]="Iniciar o Docker agora?"
  [docker_required]="O Docker é necessário. Parando aqui."
  [podman_conflict_q]="O pacote 'podman-docker' conflita com o Docker. Removê-lo?"
  [toolkit_install_q]="Instalar o NVIDIA Container Toolkit (permite que os contêineres usem a placa de vídeo)?"
  [toolkit_configure_q]="Configurar o runtime NVIDIA no Docker e reiniciar o Docker?"
  [gpu_test]="Testando a placa de vídeo dentro de um contêiner…"
  [gpu_test_ok]="A placa de vídeo aparece dentro dos contêineres."
  [gpu_test_fail]="A placa de vídeo NÃO aparece dentro dos contêineres. Veja 'Placa de vídeo não aparece no contêiner' no guia de solução de problemas."
  [gpu_skip]="Sem placa de vídeo: pulando esta etapa."
  [config_written]="Configuração salva em %s (só o root consegue ler)."
  [secret_kept]="Chave secreta existente mantida (os usuários continuam logados)."
  [secret_new]="Nova chave secreta gerada."
  [pull_q]="Baixar %s agora? (vários GB na primeira vez)"
  [pull_ok]="Imagem baixada."
  [pull_fail_custom]="Não foi possível baixar %s. Provavelmente a imagem do my-local-ia ainda não foi publicada. Instale a versão oficial agora e troque depois em 'Atualizar'."
  [pull_fail]="Não foi possível baixar a imagem. Verifique a internet e o log."
  [start_q]="Criar e iniciar o contêiner agora?"
  [waiting]="Aguardando o my-local-ia responder (até %s min)…"
  [waiting_progress]="ainda iniciando… %ss (a primeira inicialização baixa arquivos extras e pode levar alguns minutos)"
  [health_ok]="O my-local-ia está respondendo."
  [health_timeout]="O my-local-ia não respondeu a tempo. Últimas linhas do log dele:"
  [container_died]="O contêiner parou durante a inicialização. Últimas linhas do log dele:"
  [admin_exists]="Já existem usuários: a conta de administrador fica como está."
  [admin_created]="Administrador criado: %s"
  [admin_failed]="Não foi possível criar o administrador. Resposta do servidor: %s"
  [open_q]="Reiniciar o my-local-ia para que outros computadores da rede possam acessar?"
  [opened]="O my-local-ia agora aceita conexões na porta %s."
  [fw_ufw_q]="Liberar a porta %s no ufw, só para a rede local %s?"
  [fw_firewalld_q]="Liberar a porta %s no firewalld, só para a rede local %s?"
  [fw_none]="Nenhum firewall ativo (ufw/firewalld). Qualquer dispositivo que alcance este servidor consegue abrir a porta."
  [fw_public_skip]="IP público: a porta não foi liberada. Para publicar, veja 'Publicar na internet' no guia de instalação."
  [fw_done]="Regra de firewall criada."
  [test_container]="Contêiner rodando: %s (imagem %s)"
  [test_container_fail]="O contêiner não está rodando."
  [test_health]="Interface web respondendo na porta %s"
  [test_health_fail]="A interface web não está respondendo na porta %s"
  [test_gpu]="Placa de vídeo dentro do contêiner: %s"
  [test_gpu_fail]="A placa de vídeo não aparece dentro do contêiner."
  [test_ollama]="Conexão do my-local-ia com o Ollama: OK"
  [test_ollama_fail]="O my-local-ia não consegue falar com o Ollama em %s"
  [test_models]="Modelos visíveis no my-local-ia: %s"
  [test_listen]="Aceitando conexões de toda a rede (porta %s)"
  [test_listen_local]="Aceitando conexões só deste servidor (porta %s)"
  [test_hw]="Hardware detectado pelo my-local-ia: %s"
  [done_title]="Pronto!"
  [done_url]="Abra no navegador: http://%s:%s"
  [done_login]="Entre com: %s"
  [done_users]="Para adicionar pessoas: Painel do admin → Usuários. Novos cadastros ficam pendentes até um admin aprovar."
  [done_update]="Para atualizar ou trocar para o my-local-ia depois: rode este script de novo e escolha 'Atualizar'."
  [report_saved]="Relatório salvo em %s (mande este arquivo ao pedir ajuda)."
  [not_installed]="O my-local-ia não está instalado neste servidor."
  [update_current]="Imagem instalada: %s"
  [q_update_version]="Qual versão você quer?"
  [q_update_keep]="A mesma versão, na atualização mais recente"
  [backup_q]="Fazer backup antes de atualizar? (recomendado)"
  [backup_stop_note]="O my-local-ia para por alguns segundos durante o backup."
  [backup_done]="Backup salvo: %s (%s)"
  [backup_cleanup]="Backups antigos removidos (ficam os %s mais recentes)."
  [backup_none]="Nenhum backup encontrado em %s."
  [backup_list]="Backups disponíveis:"
  [q_backup_pick]="Número do backup a restaurar"
  [restore_warn]="Os dados atuais (usuários, conversas, configurações) serão SUBSTITUÍDOS pelo backup."
  [restore_done]="Backup restaurado."
  [update_swap]="Trocando o contêiner (o antigo é mantido até o novo responder)…"
  [update_ok]="Atualização concluída. Imagem: %s"
  [update_rollback]="A versão nova não iniciou. Voltando para a anterior…"
  [rollback_done]="Versão anterior restaurada. Se os dados já tiverem sido convertidos pela versão nova, restaure o backup feito antes da atualização (opção 'Restaurar')."
  [q_reset_email]="E-mail do usuário"
  [reset_done]="Senha alterada para %s."
  [reset_notfound]="Nenhum usuário com o e-mail %s."
  [reset_unsupported]="Esta opção só funciona com o banco de dados padrão (SQLite)."
  [uninstall_warn]="Isto remove o contêiner do my-local-ia. Docker, Ollama e seus modelos NÃO são mexidos."
  [uninstall_q]="Remover o contêiner?"
  [uninstall_data_q]="APAGAR também todos os dados (usuários, conversas, configurações)? Não tem volta."
  [uninstall_data_confirm]="Digite DELETE para confirmar"
  [uninstall_backup_q]="Fazer backup antes de apagar?"
  [uninstall_conf_q]="Remover a configuração em %s?"
  [uninstall_done]="my-local-ia removido."
  [data_kept]="Dados mantidos no volume do Docker '%s'. Instalar de novo reaproveita os dados."
  [verify_title]="Diagnóstico"
  [verify_ok]="Tudo OK."
  [verify_problems]="%s problema(s) encontrado(s). Veja as mensagens acima e o guia de solução de problemas."
)

# shellcheck disable=SC2034
MSG_es=(
  [title]="Instalador de my-local-ia (Open WebUI + Ollama)"
  [dry_run_banner]="MODO SIMULACIÓN: se muestran los comandos, no se cambia nada."
  [choose_lang]="Language / Idioma"
  [menu_title]="¿Qué quieres hacer?"
  [menu_install]="Instalar"
  [menu_update]="Actualizar o cambiar de versión (oficial / my-local-ia)"
  [menu_verify]="Verificar (solo diagnóstico, no cambia nada)"
  [menu_backup]="Hacer copia de seguridad ahora"
  [menu_restore]="Restaurar una copia de seguridad"
  [menu_reset_pw]="Restablecer la contraseña de un usuario"
  [menu_uninstall]="Desinstalar"
  [menu_exit]="Salir"
  [menu_prompt]="Opción"
  [invalid_option]="Opción no válida."
  [yes_default]="S/n"
  [no_default]="s/N"
  [continue_q]="¿Continuar?"
  [cancelled]="Cancelado. No se cambió nada más."
  [interrupted]="Interrumpido. Ejecuta el script de nuevo: reutiliza las respuestas ya dadas."
  [error_at]="Error en: %s"
  [see_log]="Registro completo: %s"
  [see_docs]="Ayuda: docs/%s/TROUBLESHOOTING.md (en la carpeta my-local-ia)"
  [need_root]="Ejecuta este script como root: sudo bash %s"
  [log_at]="Registro de esta ejecución: %s"
  [ssh_hint]="Estás conectado por SSH. Si la conexión se cae, la instalación se detiene. Consejo: ejecútalo dentro de 'tmux' o 'screen'."
  [step_checks]="Revisando este servidor (no cambia nada)"
  [step_questions]="Preguntas"
  [step_docker]="Docker"
  [step_gpu]="Soporte de GPU para contenedores (NVIDIA Container Toolkit)"
  [step_config]="Archivos de configuración"
  [step_pull]="Descargando la imagen"
  [step_start]="Iniciando (por ahora, accesible solo desde este servidor)"
  [step_admin]="Cuenta de administrador"
  [step_open]="Abriendo a la red local"
  [step_firewall]="Firewall"
  [step_tests]="Pruebas finales"
  [step_replace]="Cambiando a la nueva versión"
  [os]="Sistema: %s"
  [os_unsupported]="Esta distribución no es compatible con la instalación automática de Docker (%s). Compatibles: Ubuntu, Debian y derivadas, Fedora, RHEL, Rocky, Alma, CentOS Stream."
  [cpu]="Procesador: %s (%s hilos)"
  [ram]="RAM: %s GB"
  [disk]="Disco libre en %s: %s GB"
  [disk_low]="Menos de %s GB libres. Solo la imagen con GPU ocupa unos 6 GB, además de tus modelos."
  [curl_missing]="Falta 'curl' y es necesario para continuar."
  [install_curl_q]="¿Instalar curl ahora?"
  [internet_ok]="Internet: OK (registro de imágenes accesible)"
  [internet_fail]="No se pudo acceder a ghcr.io (registro de imágenes). Revisa la conexión a internet, el DNS o el proxy."
  [gpu_found]="GPU: %s"
  [gpu_driver]="Controlador NVIDIA: %s"
  [gpu_no_driver]="Se encontró una tarjeta NVIDIA, pero el controlador no está instalado (falta nvidia-smi)."
  [gpu_none]="No se encontró GPU NVIDIA. Open WebUI funcionará sin GPU (los modelos siguen ejecutándose en Ollama)."
  [gpu_continue_cpu_q]="¿Continuar sin soporte de GPU? (Para máxima velocidad, instala antes el controlador NVIDIA.)"
  [ollama_ok]="Ollama %s respondiendo en %s"
  [ollama_models]="Modelos instalados en Ollama: %s"
  [ollama_dir]="Carpeta de modelos de Ollama: %s"
  [ollama_dir_missing]="No se encontró la carpeta de modelos de Ollama. El monitoreo de disco no verá los modelos."
  [ollama_down]="Ollama no responde en %s."
  [ollama_start_q]="El servicio 'ollama' existe pero está detenido. ¿Iniciarlo ahora?"
  [ollama_missing]="Ollama no parece estar instalado. Open WebUI se abrirá, pero sin modelos locales."
  [ollama_continue_q]="¿Continuar de todos modos?"
  [docker_ok]="Docker: %s"
  [docker_missing]="Docker no está instalado."
  [docker_stopped]="Docker está instalado pero detenido."
  [toolkit_ok]="NVIDIA Container Toolkit: instalado y configurado en Docker"
  [toolkit_missing]="NVIDIA Container Toolkit: no instalado"
  [toolkit_unconfigured]="NVIDIA Container Toolkit: instalado, pero no configurado en Docker"
  [net_lan]="Red: red local (IP %s, red %s)"
  [net_public]="Red: este servidor tiene IP PÚBLICA (%s). El puerto NO se abrirá en el firewall automáticamente."
  [net_unknown]="Red: no se pudo detectar la dirección IP."
  [existing_install]="my-local-ia ya está instalado en este servidor."
  [existing_what]="Usa 'Actualizar' para cambiar de versión, 'Verificar' para diagnosticar, o reinstala (los datos se conservan)."
  [reinstall_q]="¿Recrear el contenedor ahora? Usuarios, chats y ajustes se conservan."
  [q_version]="¿Qué versión quieres instalar?"
  [q_version_official]="Open WebUI oficial (recomendado por ahora)"
  [q_version_custom]="my-local-ia (versión personalizada de tu repositorio en GitHub)"
  [q_github_user]="Tu usuario de GitHub (dueño del repositorio my-local-ia)"
  [q_port]="Puerto de acceso a my-local-ia"
  [port_invalid]="Puerto no válido. Usa un número entre 1024 y 65535."
  [port_busy]="El puerto %s ya está en uso en este servidor. Elige otro."
  [q_ollama_url]="Dirección de Ollama"
  [q_models_dir]="Carpeta de modelos de Ollama"
  [q_admin_intro]="Cuenta de administrador de my-local-ia (el primer usuario, con acceso total)."
  [q_admin_name]="Nombre del administrador"
  [q_admin_email]="Correo del administrador (para iniciar sesión)"
  [email_invalid]="Correo no válido."
  [q_admin_pw]="Contraseña (mínimo 8 caracteres, oculta)"
  [q_admin_pw2]="Repite la contraseña"
  [pw_short]="La contraseña debe tener al menos 8 caracteres."
  [pw_mismatch]="Las contraseñas no coinciden."
  [pw_invalid_chars]="La contraseña no puede tener caracteres de control."
  [summary_title]="Resumen de lo que se hará:"
  [summary_image]="Imagen: %s"
  [summary_port]="Dirección: http://%s:%s"
  [summary_gpu]="GPU: %s"
  [summary_ollama]="Ollama: %s"
  [gpu_off]="no se usa"
  [docker_install_q]="¿Instalar Docker ahora (repositorio oficial de Docker)?"
  [docker_installed]="Docker instalado y en ejecución."
  [docker_start_q]="¿Iniciar Docker ahora?"
  [docker_required]="Docker es necesario. Se detiene aquí."
  [podman_conflict_q]="El paquete 'podman-docker' entra en conflicto con Docker. ¿Quitarlo?"
  [toolkit_install_q]="¿Instalar NVIDIA Container Toolkit (permite que los contenedores usen la GPU)?"
  [toolkit_configure_q]="¿Configurar el runtime de NVIDIA en Docker y reiniciar Docker?"
  [gpu_test]="Probando la GPU dentro de un contenedor…"
  [gpu_test_ok]="La GPU es visible dentro de los contenedores."
  [gpu_test_fail]="La GPU NO es visible dentro de los contenedores. Consulta 'La GPU no aparece en el contenedor' en la guía de solución de problemas."
  [gpu_skip]="Sin GPU: se omite este paso."
  [config_written]="Configuración guardada en %s (solo root puede leerla)."
  [secret_kept]="Se conservó la clave secreta existente (los usuarios siguen con sesión iniciada)."
  [secret_new]="Nueva clave secreta generada."
  [pull_q]="¿Descargar %s ahora? (varios GB la primera vez)"
  [pull_ok]="Imagen descargada."
  [pull_fail_custom]="No se pudo descargar %s. Probablemente la imagen de my-local-ia aún no está publicada. Instala la versión oficial ahora y cambia después con 'Actualizar'."
  [pull_fail]="No se pudo descargar la imagen. Revisa la conexión a internet y el registro."
  [start_q]="¿Crear e iniciar el contenedor ahora?"
  [waiting]="Esperando a que my-local-ia responda (hasta %s min)…"
  [waiting_progress]="todavía iniciando… %ss (el primer inicio descarga archivos extra y puede tardar varios minutos)"
  [health_ok]="my-local-ia está respondiendo."
  [health_timeout]="my-local-ia no respondió a tiempo. Últimas líneas de su registro:"
  [container_died]="El contenedor se detuvo durante el inicio. Últimas líneas de su registro:"
  [admin_exists]="Ya existen usuarios: la cuenta de administrador se deja como está."
  [admin_created]="Administrador creado: %s"
  [admin_failed]="No se pudo crear el administrador. Respuesta del servidor: %s"
  [open_q]="¿Reiniciar my-local-ia para que otros equipos de la red puedan acceder?"
  [opened]="my-local-ia ahora acepta conexiones en el puerto %s."
  [fw_ufw_q]="¿Permitir el puerto %s en ufw, solo para la red local %s?"
  [fw_firewalld_q]="¿Permitir el puerto %s en firewalld, solo para la red local %s?"
  [fw_none]="No hay firewall activo (ufw/firewalld). Cualquier dispositivo que llegue a este servidor puede abrir el puerto."
  [fw_public_skip]="IP pública: no se abrió el puerto. Para publicarlo, consulta 'Publicar en internet' en la guía de instalación."
  [fw_done]="Regla de firewall creada."
  [test_container]="Contenedor en ejecución: %s (imagen %s)"
  [test_container_fail]="El contenedor no está en ejecución."
  [test_health]="Interfaz web respondiendo en el puerto %s"
  [test_health_fail]="La interfaz web no responde en el puerto %s"
  [test_gpu]="GPU dentro del contenedor: %s"
  [test_gpu_fail]="La GPU no es visible dentro del contenedor."
  [test_ollama]="Conexión de my-local-ia con Ollama: OK"
  [test_ollama_fail]="my-local-ia no puede conectar con Ollama en %s"
  [test_models]="Modelos visibles en my-local-ia: %s"
  [test_listen]="Aceptando conexiones de toda la red (puerto %s)"
  [test_listen_local]="Aceptando conexiones solo de este servidor (puerto %s)"
  [test_hw]="Hardware detectado por my-local-ia: %s"
  [done_title]="¡Listo!"
  [done_url]="Abre en el navegador: http://%s:%s"
  [done_login]="Inicia sesión con: %s"
  [done_users]="Para agregar personas: Panel de administración → Usuarios. Los nuevos registros quedan pendientes hasta que un administrador los apruebe."
  [done_update]="Para actualizar o cambiar a my-local-ia después: ejecuta este script de nuevo y elige 'Actualizar'."
  [report_saved]="Informe guardado en %s (envía este archivo al pedir ayuda)."
  [not_installed]="my-local-ia no está instalado en este servidor."
  [update_current]="Imagen instalada: %s"
  [q_update_version]="¿Qué versión quieres?"
  [q_update_keep]="La misma versión, en su última actualización"
  [backup_q]="¿Hacer copia de seguridad antes de actualizar? (recomendado)"
  [backup_stop_note]="my-local-ia se detiene unos segundos durante la copia."
  [backup_done]="Copia guardada: %s (%s)"
  [backup_cleanup]="Copias antiguas eliminadas (se conservan las %s más recientes)."
  [backup_none]="No se encontraron copias en %s."
  [backup_list]="Copias disponibles:"
  [q_backup_pick]="Número de la copia a restaurar"
  [restore_warn]="Los datos actuales (usuarios, chats, ajustes) serán REEMPLAZADOS por la copia."
  [restore_done]="Copia restaurada."
  [update_swap]="Reemplazando el contenedor (el anterior se conserva hasta que el nuevo responda)…"
  [update_ok]="Actualización terminada. Imagen: %s"
  [update_rollback]="La nueva versión no inició. Volviendo a la anterior…"
  [rollback_done]="Versión anterior restaurada. Si la nueva versión ya convirtió los datos, restaura la copia hecha antes de la actualización (opción 'Restaurar')."
  [q_reset_email]="Correo del usuario"
  [reset_done]="Contraseña cambiada para %s."
  [reset_notfound]="No hay ningún usuario con el correo %s."
  [reset_unsupported]="Esta opción solo funciona con la base de datos predeterminada (SQLite)."
  [uninstall_warn]="Esto quita el contenedor de my-local-ia. Docker, Ollama y tus modelos NO se tocan."
  [uninstall_q]="¿Quitar el contenedor?"
  [uninstall_data_q]="¿BORRAR también todos los datos (usuarios, chats, ajustes)? No se puede deshacer."
  [uninstall_data_confirm]="Escribe DELETE para confirmar"
  [uninstall_backup_q]="¿Hacer copia de seguridad antes de borrar?"
  [uninstall_conf_q]="¿Quitar la configuración en %s?"
  [uninstall_done]="my-local-ia eliminado."
  [data_kept]="Datos conservados en el volumen de Docker '%s'. Instalar de nuevo los reutiliza."
  [verify_title]="Diagnóstico"
  [verify_ok]="Todo OK."
  [verify_problems]="Se encontraron %s problema(s). Revisa los mensajes de arriba y la guía de solución de problemas."
)

############################################
# Output helpers
############################################

if [[ -t 1 ]]; then
  C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_DIM=$'\e[2m' C_OK=$'\e[32m' C_WARN=$'\e[33m' C_ERR=$'\e[31m' C_STEP=$'\e[1;36m'
else
  C_RESET="" C_BOLD="" C_DIM="" C_OK="" C_WARN="" C_ERR="" C_STEP=""
fi

# t KEY [ARGS...]: message in the chosen language, falling back to English.
t() {
  local key=$1
  shift
  local -n table="MSG_${LANG_CODE:-en}"
  local fmt=${table[$key]:-${MSG_en[$key]:-$key}}
  # shellcheck disable=SC2059  # the message is the format string by design
  printf "$fmt" "$@"
}

log_plain() { printf '%s\n' "$*" 2>/dev/null >>"$LOG_FILE" || true; }
say() {
  local color=$1
  shift
  printf '%s%s%s\n' "$color" "$*" "$C_RESET"
  log_plain "$*"
}
info() { say "" "  $*"; }
ok() { say "$C_OK" "  ✔ $*"; }
warn() { say "$C_WARN" "  ! $*"; }
fail() { say "$C_ERR" "  ✖ $*"; }
step() {
  STEP=$((STEP + 1))
  printf '\n'
  say "$C_STEP" "[$STEP/$STEP_TOTAL] $*"
}

docs_lang() {
  case $LANG_CODE in pt) echo "pt-BR" ;; es) echo "es" ;; *) echo "en" ;; esac
}

die() {
  fail "$*"
  info "$(t see_log "$LOG_FILE")"
  info "$(t see_docs "$(docs_lang)")"
  exit 1
}

# run CMD [ARGS...]: shows the command, runs it and logs its output.
run() {
  say "$C_DIM" "    \$ $*"
  if ((DRY_RUN)); then
    return 0
  fi
  local rc
  set +e
  # stdin is closed so no command can swallow the answers typed for the next questions.
  "$@" </dev/null 2>&1 | tee -a "$LOG_FILE" | sed -u 's/^/    /'
  rc=${PIPESTATUS[0]}
  set -e
  return "$rc"
}

# write_file PATH CONTENT [MODE]: shows and writes a file (never used for secrets).
write_file() {
  local path=$1 content=$2 mode=${3:-644}
  say "$C_DIM" "    > $path"
  log_plain "$content"
  if ((DRY_RUN)); then
    return 0
  fi
  printf '%s\n' "$content" >"$path"
  chmod "$mode" "$path"
}

# The helpers below write into the caller's variable by name, so their own
# locals use a __ prefix that no caller uses.
read_line() {
  local __rl_var=$1 __rl_prompt=$2 __rl_answer=""
  read -r -p "$__rl_prompt" __rl_answer || true
  printf -v "$__rl_var" '%s' "$__rl_answer"
}

# ask VAR "Question" [default]
ask() {
  local __ask_var=$1 __ask_prompt=$2 __ask_default=${3:-} __ask_answer
  read_line __ask_answer "  $__ask_prompt${__ask_default:+ [$__ask_default]}: "
  __ask_answer=${__ask_answer:-$__ask_default}
  printf -v "$__ask_var" '%s' "$__ask_answer"
  log_plain "  $__ask_prompt: $__ask_answer"
}

ask_secret() {
  local __as_var=$1 __as_prompt=$2 __as_answer=""
  read -r -s -p "  $__as_prompt: " __as_answer || true
  printf '\n'
  printf -v "$__as_var" '%s' "$__as_answer"
  log_plain "  $__as_prompt: ********"
}

# confirm "Question" [Y|N]: default answer when Enter is pressed.
confirm() {
  local __cf_prompt=$1 __cf_default=${2:-Y} __cf_hint __cf_answer
  if [[ $__cf_default == Y ]]; then __cf_hint=$(t yes_default); else __cf_hint=$(t no_default); fi
  read_line __cf_answer "  $__cf_prompt [$__cf_hint]: "
  __cf_answer=${__cf_answer:-$__cf_default}
  log_plain "  $__cf_prompt: $__cf_answer"
  case ${__cf_answer,,} in
    y | yes | s | sim | si | sí) return 0 ;;
    *) return 1 ;;
  esac
}

confirm_or_stop() {
  if ! confirm "$1" "${2:-Y}"; then
    warn "$(t cancelled)"
    exit 0
  fi
}

# choose VAR "Question" option1 option2 ...: VAR gets the option number.
choose() {
  local __ch_var=$1 __ch_prompt=$2 __ch_answer __ch_i
  shift 2
  info "$__ch_prompt"
  for __ch_i in $(seq 1 $#); do
    info "  $__ch_i) ${!__ch_i}"
  done
  while true; do
    read_line __ch_answer "  $(t menu_prompt) [1]: "
    __ch_answer=${__ch_answer:-1}
    if [[ $__ch_answer =~ ^[0-9]+$ ]] && ((__ch_answer >= 1 && __ch_answer <= $#)); then
      printf -v "$__ch_var" '%s' "$__ch_answer"
      log_plain "  -> $__ch_answer"
      return 0
    fi
    warn "$(t invalid_option)"
  done
}

on_error() {
  local line=$1 cmd=$2
  fail "$(t error_at "line $line: $cmd")"
  info "$(t see_log "$LOG_FILE")"
  info "$(t see_docs "$(docs_lang)")"
}
trap 'on_error $LINENO "$BASH_COMMAND"' ERR
trap 'printf "\n"; warn "$(t interrupted)"; exit 130' INT

############################################
# Settings
############################################

load_conf() {
  if [[ -r $CONF_FILE ]]; then
    # shellcheck source=/dev/null
    source "$CONF_FILE"
  fi
}

save_conf() {
  local content
  content=$(printf '%s=%q\n' \
    LANG_CODE "$LANG_CODE" IMAGE_KIND "$IMAGE_KIND" GITHUB_USER "$GITHUB_USER" IMAGE "$IMAGE" \
    PORT "$PORT" OLLAMA_URL "$OLLAMA_URL" MODELS_DIR "$MODELS_DIR" USE_GPU "$USE_GPU")
  run install -d -m 700 "$CONF_DIR"
  write_file "$CONF_FILE" "# my-local-ia installer settings (no secrets here)
$content" 600
}

# Secrets go to the env file only: never to the screen, the log or a command line.
write_env_file() {
  local secret=""
  if [[ -r $ENV_FILE ]]; then
    secret=$(sed -n 's/^WEBUI_SECRET_KEY=//p' "$ENV_FILE")
  fi
  if [[ -n $secret ]]; then
    ok "$(t secret_kept)"
  else
    secret=$(head -c 48 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 48)
    ok "$(t secret_new)"
  fi
  say "$C_DIM" "    > $ENV_FILE"
  if ((DRY_RUN)); then
    return 0
  fi
  install -d -m 700 "$CONF_DIR"
  (
    umask 077
    {
      echo "# my-local-ia container settings. Readable only by root: contains the secret key."
      echo "PORT=$PORT"
      echo "OLLAMA_BASE_URL=$OLLAMA_URL"
      echo "WEBUI_SECRET_KEY=$secret"
      echo "MY_LOCAL_IA_OLLAMA_MODELS_DIR=/ollama-models"
    } >"$ENV_FILE"
  )
  ok "$(t config_written "$CONF_DIR")"
}

official_image() {
  if [[ $USE_GPU == yes ]]; then echo "$OFFICIAL_IMAGE_GPU"; else echo "$OFFICIAL_IMAGE_CPU"; fi
}

custom_image() {
  local tag=main
  if [[ $USE_GPU == yes ]]; then tag=cuda; fi
  echo "ghcr.io/${GITHUB_USER,,}/$CUSTOM_IMAGE_NAME:$tag"
}

############################################
# Checks (read-only)
############################################

detect_os() {
  eval "$(
    # shellcheck source=/dev/null
    . /etc/os-release
    printf 'OS_ID=%q OS_LIKE=%q OS_NAME=%q _CODENAME=%q _UBUNTU_CODENAME=%q\n' \
      "${ID:-}" "${ID_LIKE:-}" "${PRETTY_NAME:-unknown}" "${VERSION_CODENAME:-}" "${UBUNTU_CODENAME:-}"
  )"
  case " $OS_ID $OS_LIKE " in
    *" ubuntu "*)
      PKG=apt DOCKER_DISTRO=ubuntu DOCKER_CODENAME=${_UBUNTU_CODENAME:-$_CODENAME} ;;
    *" debian "*)
      PKG=apt DOCKER_DISTRO=debian DOCKER_CODENAME=$_CODENAME ;;
    *" fedora "*)
      if [[ $OS_ID == fedora ]]; then PKG=dnf DOCKER_DISTRO=fedora; else PKG=dnf DOCKER_DISTRO=centos; fi ;;
    *" rhel "* | *" centos "*)
      PKG=dnf
      if [[ $OS_ID == rhel ]]; then DOCKER_DISTRO=rhel; else DOCKER_DISTRO=centos; fi ;;
    *) PKG=unknown ;;
  esac
  info "$(t os "$OS_NAME")"
}

check_resources() {
  local cpu threads ram free_root path free
  cpu=$(awk -F: '/model name/ {sub(/^[ \t]+/, "", $2); print $2; exit}' /proc/cpuinfo 2>/dev/null)
  threads=$(nproc 2>/dev/null || echo "?")
  ram=$(awk '/MemTotal/ {printf "%.1f", $2 / 1048576}' /proc/meminfo 2>/dev/null)
  info "$(t cpu "${cpu:-?}" "$threads")"
  info "$(t ram "${ram:-?}")"
  for path in / /var/lib/docker; do
    [[ -d $path ]] || continue
    free=$(df -BG --output=avail "$path" 2>/dev/null | tail -1 | tr -dc '0-9' || true)
    info "$(t disk "$path" "${free:-?}")"
    if [[ $path == / ]]; then free_root=$free; fi
  done
  if [[ -n ${free_root:-} ]] && ((free_root < MIN_FREE_GB)); then
    warn "$(t disk_low "$MIN_FREE_GB")"
  fi
}

install_packages() {
  case $PKG in
    apt) run apt-get update && run env DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
    dnf) run dnf install -y "$@" ;;
    *) return 1 ;;
  esac
}

check_curl() {
  if command -v curl >/dev/null; then
    return 0
  fi
  warn "$(t curl_missing)"
  confirm_or_stop "$(t install_curl_q)"
  install_packages curl ca-certificates || die "$(t curl_missing)"
}

check_internet() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 15 https://ghcr.io/v2/ || true)
  if [[ $code =~ ^[2-4][0-9][0-9]$ ]]; then
    ok "$(t internet_ok)"
  else
    warn "$(t internet_fail)"
    return 1
  fi
}

check_gpu() {
  HAS_NVIDIA_HW=0
  if command -v lspci >/dev/null && lspci 2>/dev/null | grep -qi 'nvidia'; then
    HAS_NVIDIA_HW=1
  fi
  if command -v nvidia-smi >/dev/null && GPU_LIST=$(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null) && [[ -n $GPU_LIST ]]; then
    local line
    while IFS= read -r line; do
      ok "$(t gpu_found "$line")"
    done <<<"$GPU_LIST"
    GPU_DRIVER=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || true)
    info "$(t gpu_driver "$GPU_DRIVER")"
    return 0
  fi
  GPU_LIST=""
  if ((HAS_NVIDIA_HW)); then
    warn "$(t gpu_no_driver)"
  else
    info "$(t gpu_none)"
  fi
  return 1
}

ollama_version() {
  curl -s --max-time 5 "$1/api/version" 2>/dev/null | sed -n 's/.*"version":"\([^"]*\)".*/\1/p' || true
}

count_models() {
  # Each model in /api/tags has one "model": key.
  grep -o '"model":' | wc -l | tr -d ' '
}

find_models_dir() {
  local env_dir home
  if command -v systemctl >/dev/null; then
    env_dir=$(systemctl show ollama --property=Environment --value </dev/null 2>/dev/null | tr ' ' '\n' | sed -n 's/^OLLAMA_MODELS=//p' | head -1 || true)
    if [[ -n $env_dir && -d $env_dir ]]; then
      echo "$env_dir"
      return
    fi
  fi
  if [[ -d /usr/share/ollama/.ollama/models ]]; then
    echo /usr/share/ollama/.ollama/models
    return
  fi
  if [[ -n ${SUDO_USER:-} ]]; then
    home=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    if [[ -d $home/.ollama/models ]]; then
      echo "$home/.ollama/models"
      return
    fi
  fi
  if [[ -d /root/.ollama/models ]]; then
    echo /root/.ollama/models
  fi
}

check_ollama() {
  local url=${OLLAMA_URL:-$DEFAULT_OLLAMA_URL} version models
  version=$(ollama_version "$url")
  if [[ -z $version ]] && ((!READ_ONLY)) && command -v systemctl >/dev/null && systemctl list-unit-files ollama.service </dev/null >/dev/null 2>&1 &&
    ! systemctl is-active --quiet ollama </dev/null; then
    warn "$(t ollama_down "$url")"
    if confirm "$(t ollama_start_q)"; then
      run systemctl start ollama
      sleep 3
      version=$(ollama_version "$url")
    fi
  fi
  if [[ -n $version ]]; then
    ok "$(t ollama_ok "$version" "$url")"
    models=$(curl -s --max-time 10 "$url/api/tags" | count_models || true)
    info "$(t ollama_models "$models")"
  else
    if command -v ollama >/dev/null; then
      warn "$(t ollama_down "$url")"
    else
      warn "$(t ollama_missing)"
    fi
    if ((!READ_ONLY)); then confirm_or_stop "$(t ollama_continue_q)" N; fi
  fi
  MODELS_DIR=${MODELS_DIR:-$(find_models_dir)}
  if [[ -n $MODELS_DIR ]]; then
    info "$(t ollama_dir "$MODELS_DIR")"
  else
    warn "$(t ollama_dir_missing)"
  fi
}

docker_ready() { command -v docker >/dev/null && docker info >/dev/null 2>&1; }

nvidia_runtime_configured() { docker info --format '{{json .Runtimes}}' 2>/dev/null | grep -q nvidia; }

check_docker() {
  if ! command -v docker >/dev/null; then
    warn "$(t docker_missing)"
    return 1
  fi
  if ! docker info >/dev/null 2>&1; then
    warn "$(t docker_stopped)"
    return 1
  fi
  ok "$(t docker_ok "$(docker --version)")"
  if [[ -n $GPU_LIST ]]; then
    if ! command -v nvidia-ctk >/dev/null; then
      warn "$(t toolkit_missing)"
    elif ! nvidia_runtime_configured; then
      warn "$(t toolkit_unconfigured)"
    else
      ok "$(t toolkit_ok)"
    fi
  fi
}

is_private_ip() {
  case $1 in
    10.* | 192.168.* | 172.1[6-9].* | 172.2[0-9].* | 172.3[01].*) return 0 ;;
    100.6[4-9].* | 100.[7-9][0-9].* | 100.1[01][0-9].* | 100.12[0-7].*) return 0 ;;  # carrier-grade NAT
  esac
  return 1
}

# network_of 192.168.1.20/24 -> 192.168.1.0/24
network_of() {
  local ip=${1%/*} prefix=${1#*/} a b c d n mask
  IFS=. read -r a b c d <<<"$ip"
  n=$(((a << 24) | (b << 16) | (c << 8) | d))
  mask=$(((0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF))
  n=$((n & mask))
  printf '%d.%d.%d.%d/%d' $(((n >> 24) & 255)) $(((n >> 16) & 255)) $(((n >> 8) & 255)) $((n & 255)) "$prefix"
}

check_network() {
  local route iface cidr
  route=$(ip -4 route get 1.1.1.1 2>/dev/null | head -1 || true)
  LAN_IP=$(awk '{for (i = 1; i <= NF; i++) if ($i == "src") {print $(i + 1); exit}}' <<<"$route")
  iface=$(awk '{for (i = 1; i <= NF; i++) if ($i == "dev") {print $(i + 1); exit}}' <<<"$route")
  if [[ -z $LAN_IP ]]; then
    ACCESS_MODE=unknown
    warn "$(t net_unknown)"
    return
  fi
  cidr=$(ip -o -4 addr show dev "$iface" 2>/dev/null | awk -v ip="$LAN_IP" '{split($4, a, "/"); if (a[1] == ip) {print $4; exit}}' || true)
  LAN_SUBNET=$(network_of "${cidr:-$LAN_IP/24}")
  if is_private_ip "$LAN_IP"; then
    ACCESS_MODE=lan
    ok "$(t net_lan "$LAN_IP" "$LAN_SUBNET")"
  else
    ACCESS_MODE=public
    warn "$(t net_public "$LAN_IP")"
  fi
}

container_exists() { docker_ready && docker ps -a --format '{{.Names}}' | grep -qx "$1"; }
container_running() { [[ $(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null) == true ]]; }

port_in_use() {
  ss -Hltn "sport = :$1" 2>/dev/null | grep -q .
}

run_checks() {
  detect_os
  check_resources
  check_curl
  check_internet || true
  if ! check_gpu; then
    if ((HAS_NVIDIA_HW)); then
      confirm_or_stop "$(t gpu_continue_cpu_q)" N
    fi
  fi
  check_ollama
  check_docker || true
  check_network
}

############################################
# Install steps
############################################

ask_questions() {
  local choice
  if [[ -n $GPU_LIST ]]; then USE_GPU=yes; else USE_GPU=no; fi

  choose choice "$(t q_version)" "$(t q_version_official)" "$(t q_version_custom)"
  if ((choice == 2)); then
    IMAGE_KIND=custom
    while [[ -z $GITHUB_USER || ! $GITHUB_USER =~ ^[A-Za-z0-9-]+$ ]]; do
      ask GITHUB_USER "$(t q_github_user)" "$GITHUB_USER"
    done
    IMAGE=$(custom_image)
  else
    IMAGE_KIND=official
    IMAGE=$(official_image)
  fi

  while true; do
    ask PORT "$(t q_port)" "${PORT:-$DEFAULT_PORT}"
    if ! [[ $PORT =~ ^[0-9]+$ ]] || ((PORT < 1024 || PORT > 65535)); then
      warn "$(t port_invalid)"
    elif port_in_use "$PORT" && ! { [[ $PORT == "$SAVED_PORT" ]] && container_exists "$CONTAINER"; }; then
      warn "$(t port_busy "$PORT")"
    else
      break
    fi
  done

  ask OLLAMA_URL "$(t q_ollama_url)" "${OLLAMA_URL:-$DEFAULT_OLLAMA_URL}"
  ask MODELS_DIR "$(t q_models_dir)" "$MODELS_DIR"
}

ask_admin() {
  info "$(t q_admin_intro)"
  ask ADMIN_NAME "$(t q_admin_name)" "Admin"
  while true; do
    ask ADMIN_EMAIL "$(t q_admin_email)"
    [[ $ADMIN_EMAIL =~ ^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$ ]] && break
    warn "$(t email_invalid)"
  done
  local again
  while true; do
    ask_secret ADMIN_PASSWORD "$(t q_admin_pw)"
    if ((${#ADMIN_PASSWORD} < 8)); then
      warn "$(t pw_short)"
      continue
    fi
    if [[ $ADMIN_PASSWORD == *[[:cntrl:]]* ]]; then
      warn "$(t pw_invalid_chars)"
      continue
    fi
    ask_secret again "$(t q_admin_pw2)"
    [[ $again == "$ADMIN_PASSWORD" ]] && break
    warn "$(t pw_mismatch)"
  done
}

install_docker() {
  if docker_ready; then
    ok "$(t docker_ok "$(docker --version)")"
    return
  fi
  if command -v docker >/dev/null; then
    warn "$(t docker_stopped)"
    confirm "$(t docker_start_q)" || die "$(t docker_required)"
    run systemctl enable --now docker
    return
  fi
  [[ $PKG != unknown ]] || die "$(t os_unsupported "$OS_NAME")"
  confirm "$(t docker_install_q)" || die "$(t docker_required)"
  if [[ $PKG == apt ]]; then
    install_packages ca-certificates curl gnupg
    run install -m 0755 -d /etc/apt/keyrings
    run curl -fsSL "https://download.docker.com/linux/$DOCKER_DISTRO/gpg" -o /etc/apt/keyrings/docker.asc
    run chmod a+r /etc/apt/keyrings/docker.asc
    write_file /etc/apt/sources.list.d/docker.list \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/$DOCKER_DISTRO $DOCKER_CODENAME stable"
    install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  else
    if rpm -q podman-docker >/dev/null 2>&1; then
      confirm "$(t podman_conflict_q)" || die "$(t docker_required)"
      run dnf remove -y podman-docker
    fi
    run curl -fsSL "https://download.docker.com/linux/$DOCKER_DISTRO/docker-ce.repo" -o /etc/yum.repos.d/docker-ce.repo
    install_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi
  run systemctl enable --now docker
  ok "$(t docker_installed)"
}

install_gpu_support() {
  if [[ $USE_GPU != yes ]]; then
    info "$(t gpu_skip)"
    return
  fi
  if ! command -v nvidia-ctk >/dev/null; then
    confirm_or_stop "$(t toolkit_install_q)"
    if [[ $PKG == apt ]]; then
      install_packages ca-certificates curl gnupg
      run curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey -o /tmp/nvidia-container-toolkit.gpgkey
      run gpg --batch --yes --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg /tmp/nvidia-container-toolkit.gpgkey
      local list
      list=$(curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list |
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g')
      write_file /etc/apt/sources.list.d/nvidia-container-toolkit.list "$list"
    else
      run curl -fsSL https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo -o /etc/yum.repos.d/nvidia-container-toolkit.repo
    fi
    install_packages nvidia-container-toolkit
  fi
  if ! nvidia_runtime_configured || ((DRY_RUN)); then
    confirm_or_stop "$(t toolkit_configure_q)"
    run nvidia-ctk runtime configure --runtime=docker
    run systemctl restart docker
  fi
  info "$(t gpu_test)"
  if run docker run --rm --gpus all "$GPU_TEST_IMAGE" nvidia-smi -L; then
    ok "$(t gpu_test_ok)"
  else
    die "$(t gpu_test_fail)"
  fi
}

selinux_enforcing() { command -v getenforce >/dev/null && [[ $(getenforce 2>/dev/null) == Enforcing ]]; }

# start_container HOST: 127.0.0.1 while the admin is created, 0.0.0.0 afterwards.
start_container() {
  local host=$1 args
  args=(run -d --name "$CONTAINER" --restart unless-stopped --network host
    -v "$VOLUME:/app/backend/data" --env-file "$ENV_FILE" -e "HOST=$host"
    --label "app=my-local-ia")
  if [[ $USE_GPU == yes ]]; then args+=(--gpus all); fi
  if [[ -n $MODELS_DIR && -d $MODELS_DIR ]]; then args+=(-v "$MODELS_DIR:/ollama-models:ro"); fi
  if selinux_enforcing; then args+=(--security-opt label=disable); fi
  args+=("$IMAGE")
  run docker "${args[@]}"
}

wait_for_health() {
  local waited=0 code
  info "$(t waiting $((HEALTH_TIMEOUT / 60)))"
  if ((DRY_RUN)); then
    return 0
  fi
  while ((waited < HEALTH_TIMEOUT)); do
    code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$PORT/health" || true)
    if [[ $code == 200 ]]; then
      ok "$(t health_ok)"
      return 0
    fi
    if ! container_running "$CONTAINER"; then
      fail "$(t container_died)"
      docker logs --tail 40 "$CONTAINER" 2>&1 | tee -a "$LOG_FILE" | sed 's/^/    /'
      return 1
    fi
    sleep 5
    waited=$((waited + 5))
    if ((waited % 30 == 0)); then
      info "$(t waiting_progress "$waited")"
    fi
  done
  fail "$(t health_timeout)"
  docker logs --tail 40 "$CONTAINER" 2>&1 | tee -a "$LOG_FILE" | sed 's/^/    /'
  return 1
}

json_escape() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '%s' "$s"
}

needs_onboarding() {
  ((DRY_RUN)) && return 0
  curl -s --max-time 10 "http://127.0.0.1:$PORT/api/config" | grep -q '"onboarding": *true'
}

create_admin() {
  if ((DRY_RUN)); then
    say "$C_DIM" "    \$ curl -X POST http://127.0.0.1:$PORT/api/v1/auths/signup  (password sent through stdin)"
    ok "$(t admin_created "$ADMIN_EMAIL")"
    return 0
  fi
  local body response
  body=$(printf '{"name":"%s","email":"%s","password":"%s"}' \
    "$(json_escape "$ADMIN_NAME")" "$(json_escape "$ADMIN_EMAIL")" "$(json_escape "$ADMIN_PASSWORD")")
  response=$(printf '%s' "$body" | curl -s --max-time 30 -X POST -H 'Content-Type: application/json' \
    --data-binary @- "http://127.0.0.1:$PORT/api/v1/auths/signup" || true)
  body=""
  if grep -q '"role": *"admin"' <<<"$response"; then
    ADMIN_TOKEN=$(sed -n 's/.*"token": *"\([^"]*\)".*/\1/p' <<<"$response")
    ok "$(t admin_created "$ADMIN_EMAIL")"
  else
    die "$(t admin_failed "$(head -c 300 <<<"$response")")"
  fi
}

open_firewall() {
  if [[ $ACCESS_MODE == public ]]; then
    warn "$(t fw_public_skip)"
    return
  fi
  if [[ -z $LAN_SUBNET ]]; then
    warn "$(t net_unknown)"
    return 0
  fi
  if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q 'Status: active'; then
    if confirm "$(t fw_ufw_q "$PORT" "$LAN_SUBNET")"; then
      run ufw allow from "$LAN_SUBNET" to any port "$PORT" proto tcp comment my-local-ia
      ok "$(t fw_done)"
    fi
  elif command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
    if confirm "$(t fw_firewalld_q "$PORT" "$LAN_SUBNET")"; then
      run firewall-cmd --permanent --add-rich-rule="rule family=ipv4 source address=$LAN_SUBNET port port=$PORT protocol=tcp accept"
      run firewall-cmd --reload
      ok "$(t fw_done)"
    fi
  else
    info "$(t fw_none)"
  fi
}

close_firewall() {
  [[ -n ${PORT:-} ]] || return 0
  if command -v ufw >/dev/null && ufw status 2>/dev/null | grep -q "$PORT.*my-local-ia"; then
    local subnet
    subnet=$(ufw status 2>/dev/null | awk -v p="$PORT/tcp" '$1 == p && /my-local-ia/ {print $3; exit}' || true)
    [[ -n $subnet ]] && run ufw delete allow from "$subnet" to any port "$PORT" proto tcp
  fi
  if command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
    local rule
    while IFS= read -r rule; do
      [[ -n $rule ]] && run firewall-cmd --permanent --remove-rich-rule="$rule"
    done < <(firewall-cmd --permanent --list-rich-rules 2>/dev/null | grep "port=\"$PORT\"" || true)
    run firewall-cmd --reload
  fi
}

############################################
# Tests
############################################

PROBLEMS=0

problem() {
  fail "$*"
  PROBLEMS=$((PROBLEMS + 1))
}

run_tests() {
  PROBLEMS=0
  if ((DRY_RUN)); then
    info "(dry-run)"
    return 0
  fi
  if ! container_running "$CONTAINER"; then
    problem "$(t test_container_fail)"
    return 0
  fi
  ok "$(t test_container "$CONTAINER" "$(docker inspect -f '{{.Config.Image}}' "$CONTAINER")")"

  if [[ $(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "http://127.0.0.1:$PORT/health" || true) == 200 ]]; then
    ok "$(t test_health "$PORT")"
  else
    problem "$(t test_health_fail "$PORT")"
  fi

  if ss -Hltn "sport = :$PORT" 2>/dev/null | grep -Eq '(0\.0\.0\.0|\*|\[::\]):'; then
    ok "$(t test_listen "$PORT")"
  else
    info "$(t test_listen_local "$PORT")"
  fi

  if [[ $USE_GPU == yes ]]; then
    local gpu
    if gpu=$(docker exec "$CONTAINER" nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null) && [[ -n $gpu ]]; then
      ok "$(t test_gpu "$(head -1 <<<"$gpu")")"
    else
      problem "$(t test_gpu_fail)"
    fi
  fi

  if docker exec "$CONTAINER" curl -s --max-time 5 "$OLLAMA_URL/api/version" 2>/dev/null | grep -q version; then
    ok "$(t test_ollama)"
    local models
    if [[ -n $ADMIN_TOKEN ]]; then
      models=$(curl -s --max-time 15 -H "Authorization: Bearer $ADMIN_TOKEN" "http://127.0.0.1:$PORT/ollama/api/tags" | count_models || true)
    else
      models=$(docker exec "$CONTAINER" curl -s --max-time 10 "$OLLAMA_URL/api/tags" 2>/dev/null | count_models || true)
    fi
    info "$(t test_models "$models")"
  else
    problem "$(t test_ollama_fail "$OLLAMA_URL")"
  fi

  if [[ $IMAGE_KIND == custom && -n $ADMIN_TOKEN ]]; then
    local hw
    hw=$(curl -s --max-time 15 -H "Authorization: Bearer $ADMIN_TOKEN" "http://127.0.0.1:$PORT/api/v1/my-local-ia/hardware" || true)
    info "$(t test_hw "$(sed -n 's/.*"vram_gb": *\([0-9.]*\).*"ram_total_gb": *\([0-9.]*\).*/VRAM \1 GB, RAM \2 GB/p' <<<"$hw")")"
  fi
}

############################################
# Backups
############################################

helper_image() {
  # The app image already has tar; fall back to a tiny image if it is gone.
  if [[ -n ${IMAGE:-} ]] && docker image inspect "$IMAGE" >/dev/null 2>&1; then echo "$IMAGE"; else echo "$HELPER_IMAGE"; fi
}

backup_data() {
  local name was_running=0 size
  name="my-local-ia-data-$(date +%Y%m%d-%H%M%S).tar.gz"
  run install -d -m 700 "$BACKUP_DIR"
  if container_running "$CONTAINER"; then
    was_running=1
    info "$(t backup_stop_note)"
    run docker stop "$CONTAINER"
  fi
  run docker run --rm --entrypoint tar -v "$VOLUME:/data:ro" -v "$BACKUP_DIR:/backup" "$(helper_image)" czf "/backup/$name" -C /data .
  if ((was_running)); then
    run docker start "$CONTAINER"
  fi
  size=$(du -h "$BACKUP_DIR/$name" 2>/dev/null | cut -f1 || echo "?")
  ok "$(t backup_done "$BACKUP_DIR/$name" "$size")"
  # Keep only the newest backups.
  local old
  # shellcheck disable=SC2012  # file names are generated by this script
  old=$(ls -1t "$BACKUP_DIR"/my-local-ia-data-*.tar.gz 2>/dev/null | tail -n +$((KEEP_BACKUPS + 1)) || true)
  if [[ -n $old ]]; then
    while IFS= read -r name; do run rm -f "$name"; done <<<"$old"
    info "$(t backup_cleanup "$KEEP_BACKUPS")"
  fi
}

restore_backup() {
  local files=() i choice file
  mapfile -t files < <(ls -1t "$BACKUP_DIR"/my-local-ia-data-*.tar.gz 2>/dev/null || true)
  if ((${#files[@]} == 0)); then
    warn "$(t backup_none "$BACKUP_DIR")"
    return
  fi
  info "$(t backup_list)"
  for i in "${!files[@]}"; do
    info "  $((i + 1))) $(basename "${files[$i]}")  $(du -h "${files[$i]}" | cut -f1)"
  done
  while true; do
    ask choice "$(t q_backup_pick)" 1
    [[ $choice =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#files[@]})) && break
    warn "$(t invalid_option)"
  done
  file=$(basename "${files[$((choice - 1))]}")
  warn "$(t restore_warn)"
  confirm_or_stop "$(t continue_q)" N
  if container_running "$CONTAINER"; then run docker stop "$CONTAINER"; fi
  run docker run --rm --entrypoint sh -v "$VOLUME:/data" -v "$BACKUP_DIR:/backup:ro" "$(helper_image)" \
    -c "find /data -mindepth 1 -delete && tar xzf '/backup/$file' -C /data"
  if container_exists "$CONTAINER"; then
    run docker start "$CONTAINER"
    wait_for_health || true
  fi
  ok "$(t restore_done)"
}

############################################
# Menu actions
############################################

require_installed() {
  if ! container_exists "$CONTAINER" && ((!DRY_RUN)); then
    warn "$(t not_installed)"
    exit 1
  fi
}

action_install() {
  STEP_TOTAL=11
  step "$(t step_checks)"
  run_checks

  if container_exists "$CONTAINER"; then
    warn "$(t existing_install)"
    info "$(t existing_what)"
    confirm_or_stop "$(t reinstall_q)" N
  fi

  step "$(t step_questions)"
  ask_questions
  printf '\n'
  info "$(t summary_title)"
  info "  $(t summary_image "$IMAGE")"
  info "  $(t summary_port "${LAN_IP:-127.0.0.1}" "$PORT")"
  if [[ $USE_GPU == yes ]]; then
    info "  $(t summary_gpu "$(head -1 <<<"$GPU_LIST")")"
  else
    info "  $(t summary_gpu "$(t gpu_off)")"
  fi
  info "  $(t summary_ollama "$OLLAMA_URL")"
  confirm_or_stop "$(t continue_q)"
  save_conf

  step "$(t step_docker)"
  install_docker

  step "$(t step_gpu)"
  install_gpu_support

  step "$(t step_config)"
  write_env_file

  step "$(t step_pull)"
  confirm_or_stop "$(t pull_q "$IMAGE")"
  if ! run docker pull "$IMAGE"; then
    if [[ $IMAGE_KIND == custom ]]; then die "$(t pull_fail_custom "$IMAGE")"; fi
    die "$(t pull_fail)"
  fi
  ok "$(t pull_ok)"

  step "$(t step_start)"
  confirm_or_stop "$(t start_q)"
  if container_exists "$CONTAINER"; then run docker rm -f "$CONTAINER"; fi
  start_container 127.0.0.1
  wait_for_health || die "$(t health_timeout)"

  step "$(t step_admin)"
  if needs_onboarding; then
    ask_admin
    create_admin
    ADMIN_PASSWORD=""
  else
    ok "$(t admin_exists)"
  fi

  step "$(t step_open)"
  confirm_or_stop "$(t open_q)"
  run docker rm -f "$CONTAINER"
  start_container 0.0.0.0
  wait_for_health || die "$(t health_timeout)"
  ok "$(t opened "$PORT")"

  step "$(t step_firewall)"
  open_firewall

  step "$(t step_tests)"
  run_tests

  printf '\n'
  say "$C_OK$C_BOLD" "$(t done_title)"
  info "$(t done_url "${LAN_IP:-127.0.0.1}" "$PORT")"
  if [[ -n ${ADMIN_EMAIL:-} ]]; then info "$(t done_login "$ADMIN_EMAIL")"; fi
  info "$(t done_users)"
  info "$(t done_update)"
  info "$(t log_at "$LOG_FILE")"
}

action_update() {
  require_installed
  STEP_TOTAL=4
  step "$(t step_checks)"
  check_gpu || true
  if [[ -n $GPU_LIST ]]; then USE_GPU=yes; else USE_GPU=${USE_GPU:-no}; fi
  local current choice
  current=$(docker inspect -f '{{.Config.Image}}' "$CONTAINER" 2>/dev/null || echo "$IMAGE")
  info "$(t update_current "$current")"

  step "$(t step_questions)"
  choose choice "$(t q_update_version)" "$(t q_update_keep)" "$(t q_version_official)" "$(t q_version_custom)"
  case $choice in
    1) IMAGE=${current:-$IMAGE} ;;
    2) IMAGE_KIND=official IMAGE=$(official_image) ;;
    3)
      IMAGE_KIND=custom
      while [[ -z $GITHUB_USER || ! $GITHUB_USER =~ ^[A-Za-z0-9-]+$ ]]; do
        ask GITHUB_USER "$(t q_github_user)" "$GITHUB_USER"
      done
      IMAGE=$(custom_image)
      ;;
  esac
  info "$(t summary_image "$IMAGE")"
  confirm_or_stop "$(t continue_q)"

  step "$(t step_pull)"
  if ! run docker pull "$IMAGE"; then
    if [[ $IMAGE_KIND == custom ]]; then die "$(t pull_fail_custom "$IMAGE")"; fi
    die "$(t pull_fail)"
  fi
  ok "$(t pull_ok)"
  if confirm "$(t backup_q)"; then backup_data; fi
  save_conf

  step "$(t step_replace)"
  info "$(t update_swap)"
  if container_exists "$PREVIOUS_CONTAINER"; then run docker rm -f "$PREVIOUS_CONTAINER"; fi
  run docker rename "$CONTAINER" "$PREVIOUS_CONTAINER"
  run docker stop "$PREVIOUS_CONTAINER"
  start_container 0.0.0.0
  if wait_for_health; then
    run docker rm "$PREVIOUS_CONTAINER"
    ok "$(t update_ok "$IMAGE")"
    run_tests
  else
    warn "$(t update_rollback)"
    run docker rm -f "$CONTAINER"
    run docker rename "$PREVIOUS_CONTAINER" "$CONTAINER"
    run docker start "$CONTAINER"
    wait_for_health || true
    die "$(t rollback_done)"
  fi
}

action_verify() {
  READ_ONLY=1
  STEP_TOTAL=2
  step "$(t step_checks)"
  detect_os
  check_resources
  if command -v curl >/dev/null; then check_internet || PROBLEMS=$((PROBLEMS + 1)); fi
  check_gpu || true
  check_ollama
  check_docker || true
  check_network
  local before=$PROBLEMS

  step "$(t verify_title)"
  if container_exists "$CONTAINER"; then
    run_tests
    PROBLEMS=$((PROBLEMS + before))
  else
    warn "$(t not_installed)"
    PROBLEMS=$((before + 1))
  fi

  local report
  report="/var/log/my-local-ia-report-$(date +%Y%m%d-%H%M%S).txt"
  if ((!DRY_RUN)); then
    {
      echo "my-local-ia diagnostics — $(date -Is)"
      echo "System: $OS_NAME / kernel $(uname -r)"
      echo "Settings: IMAGE=$IMAGE PORT=$PORT OLLAMA_URL=$OLLAMA_URL MODELS_DIR=$MODELS_DIR USE_GPU=$USE_GPU"
      echo "--- nvidia-smi"; nvidia-smi 2>&1 || true
      echo "--- docker"; docker version 2>&1 || true
      echo "--- container"; docker ps -a --filter "name=$CONTAINER" 2>&1 || true
      echo "--- container log (last 100 lines)"; docker logs --tail 100 "$CONTAINER" 2>&1 || true
      echo "--- disk"; df -h 2>&1 || true
      echo "--- listening ports"; ss -ltn 2>&1 || true
    } >"$report" 2>&1
    chmod 600 "$report"
    info "$(t report_saved "$report")"
  fi
  printf '\n'
  if ((PROBLEMS == 0)); then ok "$(t verify_ok)"; else warn "$(t verify_problems "$PROBLEMS")"; fi
}

action_backup() {
  require_installed
  backup_data
}

action_restore() {
  require_installed
  restore_backup
}

action_reset_password() {
  require_installed
  local email password again
  ask email "$(t q_reset_email)"
  while true; do
    ask_secret password "$(t q_admin_pw)"
    ((${#password} >= 8)) || { warn "$(t pw_short)"; continue; }
    ask_secret again "$(t q_admin_pw2)"
    [[ $again == "$password" ]] && break
    warn "$(t pw_mismatch)"
  done
  if ((DRY_RUN)); then
    say "$C_DIM" "    \$ docker exec -i $CONTAINER python3 -  (new password sent through stdin)"
    return 0
  fi
  local result
  # bcrypt hashes are accepted by Open WebUI next to its default argon2 ones.
  result=$(printf '{"e":"%s","p":"%s"}' "$(json_escape "$email")" "$(json_escape "$password")" |
    docker exec -i "$CONTAINER" python3 -c '
import json, os, sqlite3, sys
import bcrypt
db = "/app/backend/data/webui.db"
if not os.path.exists(db):
    print("nodb"); sys.exit()
d = json.load(sys.stdin)
h = bcrypt.hashpw(d["p"].encode(), bcrypt.gensalt()).decode()
c = sqlite3.connect(db)
n = c.execute("UPDATE auth SET password = ? WHERE lower(email) = lower(?)", (h, d["e"])).rowcount
c.commit()
print(n)' 2>&1 || true)
  password=""
  case $result in
    nodb) warn "$(t reset_unsupported)" ;;
    0) warn "$(t reset_notfound "$email")" ;;
    1) ok "$(t reset_done "$email")" ;;
    *) die "$result" ;;
  esac
}

action_uninstall() {
  warn "$(t uninstall_warn)"
  confirm_or_stop "$(t uninstall_q)" N
  if container_exists "$CONTAINER"; then run docker rm -f "$CONTAINER"; fi
  if container_exists "$PREVIOUS_CONTAINER"; then run docker rm -f "$PREVIOUS_CONTAINER"; fi
  close_firewall
  if confirm "$(t uninstall_data_q)" N; then
    local typed
    ask typed "$(t uninstall_data_confirm)"
    if [[ $typed == DELETE ]]; then
      if confirm "$(t uninstall_backup_q)"; then backup_data; fi
      run docker volume rm "$VOLUME"
    else
      info "$(t data_kept "$VOLUME")"
    fi
  else
    info "$(t data_kept "$VOLUME")"
  fi
  if [[ -d $CONF_DIR ]] && confirm "$(t uninstall_conf_q "$CONF_DIR")" N; then
    run rm -rf "$CONF_DIR"
  fi
  ok "$(t uninstall_done)"
}

############################################
# Main
############################################

usage() {
  sed -n '3,13p' "$0" | sed 's/^# \{0,1\}//'
}

detect_language() {
  case ${LC_ALL:-${LANG:-}} in
    pt*) echo pt ;;
    es*) echo es ;;
    *) echo en ;;
  esac
}

main() {
  while (($#)); do
    case $1 in
      --dry-run) DRY_RUN=1 ;;
      --lang) LANG_CODE=${2:-}; shift ;;
      --lang=*) LANG_CODE=${1#*=} ;;
      -h | --help) usage; exit 0 ;;
      *) usage; exit 2 ;;
    esac
    shift
  done

  local cli_lang=$LANG_CODE
  load_conf
  SAVED_PORT=$PORT
  LANG_CODE=${cli_lang:-${LANG_CODE:-}}

  if ((EUID != 0)); then
    if ((DRY_RUN)); then
      LOG_FILE="/tmp/my-local-ia-install-dry-run.log"
    else
      LANG_CODE=${LANG_CODE:-$(detect_language)}
      fail "$(t need_root "$0")"
      exit 1
    fi
  fi
  touch "$LOG_FILE" 2>/dev/null && chmod 600 "$LOG_FILE" 2>/dev/null || true
  log_plain ""
  log_plain "===== $(date -Is) $0 $* ====="

  if [[ -z $LANG_CODE ]]; then
    local detected choice
    detected=$(detect_language)
    LANG_CODE=$detected
    printf '%s\n' "$(t choose_lang)"
    printf '  1) English   2) Português   3) Español\n'
    read_line choice "  [$(case $detected in pt) echo 2 ;; es) echo 3 ;; *) echo 1 ;; esac)]: "
    case ${choice:-x} in
      1) LANG_CODE=en ;;
      2) LANG_CODE=pt ;;
      3) LANG_CODE=es ;;
    esac
  fi
  [[ $LANG_CODE =~ ^(en|pt|es)$ ]] || LANG_CODE=en

  printf '\n'
  say "$C_BOLD" "$(t title)"
  if ((DRY_RUN)); then warn "$(t dry_run_banner)"; fi
  info "$(t log_at "$LOG_FILE")"
  if [[ -n ${SSH_CONNECTION:-} && -z ${TMUX:-} && ${TERM:-} != screen* ]]; then
    warn "$(t ssh_hint)"
  fi

  printf '\n'
  local option
  while true; do
    info "$(t menu_title)"
    info "  1) $(t menu_install)"
    info "  2) $(t menu_update)"
    info "  3) $(t menu_verify)"
    info "  4) $(t menu_backup)"
    info "  5) $(t menu_restore)"
    info "  6) $(t menu_reset_pw)"
    info "  7) $(t menu_uninstall)"
    info "  0) $(t menu_exit)"
    read_line option "  $(t menu_prompt): "
    log_plain "  menu -> $option"
    case $option in
      1) action_install; break ;;
      2) action_update; break ;;
      3) action_verify; break ;;
      4) action_backup; break ;;
      5) action_restore; break ;;
      6) action_reset_password; break ;;
      7) action_uninstall; break ;;
      0 | q) exit 0 ;;
      *) warn "$(t invalid_option)" ;;
    esac
  done
}

main "$@"
