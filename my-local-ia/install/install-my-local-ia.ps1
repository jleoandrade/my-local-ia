<#
.SYNOPSIS
    my-local-ia installer for Windows.

.DESCRIPTION
    Installs Open WebUI (the official image or the my-local-ia build) in Docker
    Desktop next to an Ollama that is already running on this computer, with
    NVIDIA GPU support, and keeps it updated, backed up and diagnosable. Every
    step is shown on screen, every change asks for confirmation and everything
    is logged.

    Run it from an elevated PowerShell (Run as administrator):
        powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1

.PARAMETER DryRun
    Show every command without changing anything.

.PARAMETER Lang
    Interface language: en, pt or es (default: from the Windows language).
#>
[CmdletBinding()]
param(
    [switch]$DryRun,
    [ValidateSet('', 'en', 'pt', 'es')]
    [string]$Lang = ''
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = New-Object Text.UTF8Encoding $false

$Container = 'my-local-ia'
$PreviousContainer = 'my-local-ia-previous'
$Volume = 'my-local-ia-data'
$DefaultPort = 4000
$DefaultOllamaUrl = 'http://host.docker.internal:11434'  # as seen from inside the container
$HostOllamaUrl = 'http://127.0.0.1:11434'                # as seen from Windows
$ConfDir = Join-Path $env:ProgramData 'my-local-ia'
$ConfFile = Join-Path $ConfDir 'installer.json'
$EnvFile = Join-Path $ConfDir 'my-local-ia.env'
$LogDir = Join-Path $ConfDir 'logs'
$LogFile = Join-Path $LogDir 'install.log'
$BackupDir = Join-Path $ConfDir 'backups'
$OfficialImageGpu = 'ghcr.io/open-webui/open-webui:cuda'
$OfficialImageCpu = 'ghcr.io/open-webui/open-webui:main'
$CustomImageName = 'my-local-ia'
$LocalImageName = 'my-local-ia'   # built on this computer as my-local-ia:local-<cuda|main>
$SourceDir = Join-Path $ConfDir 'src'
$MinBuildFreeGb = 25
$HealthTimeout = 900
$MinFreeGb = 30
$KeepBackups = 5
$GpuTestImage = 'ubuntu:24.04'
$HelperImage = 'alpine:3.20'
$DockerDesktopExe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
$OllamaAppExe = Join-Path $env:LOCALAPPDATA 'Programs\Ollama\ollama app.exe'

$Script:IsDryRun = [bool]$DryRun
$Script:ReadOnly = $false
$Script:LangCode = $Lang
$Script:Step = 0
$Script:StepTotal = 0
$Script:Problems = 0
$Script:AdminToken = ''
$Script:GpuList = @()
$Script:LanIp = ''
$Script:NetCategory = ''
$Script:AccessMode = ''

# Settings saved in $ConfFile between runs (no secrets).
$Script:Conf = [ordered]@{
    LangCode   = ''
    ImageKind  = ''
    GithubUser = ''
    RepoUrl    = ''
    RepoBranch = ''
    Image      = ''
    Port       = ''
    OllamaUrl  = ''
    ModelsDir  = ''
    UseGpu     = ''
    Pending    = ''   # 'restart' while Windows must restart after installing WSL / Docker Desktop
}

############################################
# Messages (English, Portuguese, Spanish)
############################################

$Messages = @{
    en = @{
        admin_created = 'Administrator created: {0}'
        admin_exists = 'Users already exist: the administrator account is kept as it is.'
        admin_failed = 'Could not create the administrator. Answer from the server: {0}'
        backup_cleanup = 'Old backups removed (keeping the newest {0}).'
        backup_done = 'Backup saved: {0} ({1})'
        backup_list = 'Available backups:'
        backup_none = 'No backups found in {0}.'
        backup_q = 'Make a backup before updating? (recommended)'
        backup_stop_note = 'my-local-ia stops for a few seconds during the backup.'
        cancelled = 'Cancelled. Nothing else was changed.'
        choose_lang = 'Language / Idioma'
        config_written = 'Configuration saved in {0} (readable only by administrators).'
        container_died = 'The container stopped while starting. Last lines of its log:'
        continue_q = 'Continue?'
        cpu = 'CPU: {0} ({1} threads)'
        data_kept = 'Data kept in the Docker volume ''{0}''. Installing again reuses it.'
        disk = 'Free disk on {0}: {1} GB'
        disk_low = 'Less than {0} GB free. The GPU image alone takes about 6 GB, plus your models.'
        docker_install_q = 'Install Docker Desktop now (with winget)?'
        docker_installed = 'Docker Desktop is running.'
        docker_missing = 'Docker Desktop is not installed.'
        docker_ok = 'Docker: {0}'
        docker_required = 'Docker is required. Stopping here.'
        docker_start_timeout = 'Docker Desktop did not start. Open it from the Start menu, wait for ''Engine running'' and run this script again.'
        docker_starting = 'Starting Docker Desktop (up to {0} min). If a window asks you to accept the terms, accept them.'
        docker_stopped = 'Docker Desktop is installed but not running.'
        done_login = 'Log in with: {0}'
        done_title = 'Done!'
        done_update = 'To update or switch to my-local-ia later: run this script again and choose ''Update''.'
        done_url = 'Open in a browser: http://{0}:{1}'
        done_users = 'To add people: Admin Panel → Users. New sign-ups stay pending until an admin approves them.'
        dry_run_banner = 'SIMULATION MODE: commands are shown, nothing is changed.'
        email_invalid = 'Invalid e-mail.'
        error_at = 'Error in: {0}'
        existing_install = 'my-local-ia is already installed on this server.'
        existing_what = 'Use ''Update'' to change version, ''Verify'' to diagnose, or reinstall (data is kept).'
        fw_done = 'Firewall rule created.'
        fw_public_profile = 'Windows marks this network as ''Public'', where the rule does not apply. Change it in Settings > Network & internet > (your connection) > Private network.'
        fw_public_skip = 'Public IP: the port was not opened. To publish it, see ''Publishing on the internet'' in the installation guide.'
        fw_windows_q = 'Allow port {0} in the Windows firewall, only for the local network?'
        gpu_continue_cpu_q = 'Continue without GPU support? (Install the NVIDIA driver first for full speed.)'
        gpu_driver = 'NVIDIA driver: {0}'
        gpu_found = 'GPU: {0}'
        gpu_no_driver = 'An NVIDIA card was found, but the driver is not installed (nvidia-smi is missing).'
        gpu_none = 'No NVIDIA GPU found. Open WebUI will run without GPU (models still run in Ollama).'
        gpu_off = 'not used'
        gpu_skip = 'No GPU: skipping this step.'
        gpu_test = 'Testing the GPU inside a container…'
        gpu_test_fail = 'The GPU is NOT visible inside containers. Update the NVIDIA driver for Windows and check ''GPU not visible in the container'' in the troubleshooting guide.'
        gpu_test_ok = 'The GPU is visible inside containers.'
        health_ok = 'my-local-ia is answering.'
        health_timeout = 'my-local-ia did not answer in time. Last lines of its log:'
        internet_fail = 'Could not reach ghcr.io (image registry). Check the internet connection, DNS or proxy.'
        internet_ok = 'Internet: OK (image registry reachable)'
        invalid_option = 'Invalid option.'
        log_at = 'Log of this run: {0}'
        menu_backup = 'Back up data now'
        menu_exit = 'Exit'
        menu_install = 'Install'
        menu_prompt = 'Option'
        menu_reset_pw = 'Reset a user''s password'
        menu_restore = 'Restore a backup'
        menu_title = 'What do you want to do?'
        menu_uninstall = 'Uninstall'
        menu_update = 'Update or switch version (official / my-local-ia)'
        menu_verify = 'Verify (diagnostics only, changes nothing)'
        need_root = 'Run this script from PowerShell opened as Administrator: powershell -ExecutionPolicy Bypass -File "{0}"'
        net_lan = 'Network: local network (IP {0}, network {1})'
        net_public = 'Network: this server has a PUBLIC IP ({0}). The port will NOT be opened in the firewall automatically.'
        net_unknown = 'Network: could not detect the IP address.'
        no_default = 'y/N'
        not_installed = 'my-local-ia is not installed on this server.'
        ollama_container_fail = 'my-local-ia cannot reach Ollama. By default, Ollama on Windows only accepts connections from this computer itself, not from Docker.'
        ollama_continue_q = 'Continue anyway?'
        ollama_dir = 'Ollama models folder: {0}'
        ollama_dir_missing = 'Ollama models folder not found. Disk monitoring will not see the models.'
        ollama_down = 'Ollama is not answering at {0}.'
        ollama_host_done = 'Ollama restarted and reachable from my-local-ia.'
        ollama_host_q = 'Let Ollama accept connections from Docker? (sets OLLAMA_HOST=0.0.0.0:11434 for your user and restarts Ollama)'
        ollama_missing = 'Ollama does not seem to be installed. Open WebUI will start, but without local models.'
        ollama_models = 'Ollama models installed: {0}'
        ollama_ok = 'Ollama {0} is answering at {1}'
        ollama_start_q = 'Ollama is installed but not running. Start it now?'
        open_q = 'Restart my-local-ia so other computers on the network can access it?'
        opened = 'my-local-ia now accepts connections on port {0}.'
        os = 'System: {0}'
        os_unsupported = 'Windows Server is not supported by Docker Desktop ({0}). Use Windows 10/11 Pro or Enterprise, or a Linux server with install-my-local-ia.sh.'
        port_busy = 'Port {0} is already in use on this server. Choose another one.'
        port_invalid = 'Invalid port. Use a number between 1024 and 65535.'
        pull_fail = 'Could not download the image. Check the internet connection and the log.'
        pull_fail_custom = 'Could not download {0}. The my-local-ia image is probably not published yet. Install the official version now and switch later with ''Update''.'
        pull_ok = 'Image downloaded.'
        pull_q = 'Download {0} now? (several GB the first time)'
        pw_mismatch = 'The passwords do not match.'
        pw_short = 'The password must have at least 8 characters.'
        q_admin_email = 'Administrator e-mail (used to log in)'
        q_admin_intro = 'Administrator account of my-local-ia (the first user, with full access).'
        q_admin_name = 'Administrator name'
        q_admin_pw = 'Password (minimum 8 characters, hidden)'
        q_admin_pw2 = 'Repeat the password'
        q_backup_pick = 'Number of the backup to restore'
        q_github_user = 'Your GitHub user (owner of the my-local-ia repository)'
        q_models_dir = 'Ollama models folder'
        q_ollama_url = 'Ollama address'
        q_port = 'Port to access my-local-ia'
        q_reset_email = 'E-mail of the user'
        q_update_keep = 'Same version, newest release'
        q_update_version = 'Which version do you want?'
        q_version = 'Which version do you want to install?'
        q_version_custom = 'my-local-ia (custom build from your GitHub repository)'
        q_version_local = 'my-local-ia built here on this computer from the source code (20–60 minutes)'
        q_repo_url = 'Address of the my-local-ia repository on GitHub'
        q_repo_branch = 'Branch'
        step_build = 'Building the my-local-ia image on this computer'
        build_q = 'Build {0} now? It takes 20–60 minutes and about {1} GB of disk.'
        build_disk_low = 'Only {0} GB free on C:; the build needs about {1} GB. Free space first or it may fail halfway.'
        build_source = 'Source code: {0} ({1}), commit {2}'
        build_ok = 'Image built: {0}'
        build_fail = 'The build failed. The installed version was not touched. The log shows the step that failed.'
        build_clean_q = 'Remove the build cache and old my-local-ia images to free disk?'
        q_version_official = 'Official Open WebUI (recommended for now)'
        ram = 'RAM: {0} GB'
        reboot_needed = 'Restart Windows now. Then run this script again and choose Install: it continues from where it stopped.'
        reinstall_q = 'Recreate the container now? Users, chats and settings are kept.'
        report_saved = 'Report saved in {0} (send this file when asking for help).'
        reset_done = 'Password changed for {0}.'
        reset_notfound = 'No user with the e-mail {0}.'
        reset_unsupported = 'This option only works with the default database (SQLite).'
        restore_done = 'Backup restored.'
        restore_warn = 'The current data (users, chats, settings) will be REPLACED by the backup.'
        resuming = 'Continuing the installation with the answers given before the restart.'
        rollback_done = 'Previous version restored. If the data was already converted by the new version, restore the backup made before the update (option ''Restore'').'
        secret_kept = 'Existing secret key kept (users stay logged in).'
        secret_new = 'New secret key generated.'
        see_docs = 'Help: docs/{0}/TROUBLESHOOTING.md (in the my-local-ia folder)'
        see_log = 'Full log: {0}'
        start_q = 'Create and start the container now?'
        step_admin = 'Administrator account'
        step_checks = 'Checking this server (changes nothing)'
        step_config = 'Configuration files'
        step_docker = 'Docker'
        step_firewall = 'Firewall'
        step_gpu = 'GPU support in Docker Desktop'
        step_open = 'Opening to the local network'
        step_pull = 'Downloading the image'
        step_questions = 'Questions'
        step_replace = 'Switching to the new version'
        step_start = 'Starting (only reachable from this server for now)'
        step_tests = 'Final tests'
        summary_gpu = 'GPU: {0}'
        summary_image = 'Image: {0}'
        summary_ollama = 'Ollama: {0}'
        summary_port = 'Address: http://{0}:{1}'
        summary_title = 'Summary of what will be done:'
        test_container = 'Container running: {0} (image {1})'
        test_container_fail = 'The container is not running.'
        test_gpu = 'GPU inside the container: {0}'
        test_gpu_fail = 'GPU not visible inside the container.'
        test_health = 'Web interface answering on port {0}'
        test_health_fail = 'Web interface is not answering on port {0}'
        test_hw = 'Hardware detected by my-local-ia: {0}'
        test_listen = 'Listening on all network interfaces (port {0})'
        test_listen_local = 'Listening only on this server (port {0})'
        test_models = 'Models visible in my-local-ia: {0}'
        test_ollama = 'Connection from my-local-ia to Ollama: OK'
        test_ollama_fail = 'my-local-ia cannot reach Ollama at {0}'
        title = 'my-local-ia installer (Open WebUI + Ollama)'
        uninstall_backup_q = 'Make a backup before deleting?'
        uninstall_conf_q = 'Remove the configuration in {0}?'
        uninstall_data_confirm = 'Type DELETE to confirm'
        uninstall_data_q = 'Also DELETE all data (users, chats, settings)? This cannot be undone.'
        uninstall_done = 'my-local-ia removed.'
        uninstall_q = 'Remove the container?'
        uninstall_warn = 'This removes the my-local-ia container. Docker, Ollama and your models are NOT touched.'
        update_current = 'Installed image: {0}'
        update_ok = 'Update finished. Image: {0}'
        update_rollback = 'The new version did not start. Going back to the previous one…'
        update_swap = 'Replacing the container (the old one is kept until the new one answers)…'
        verify_ok = 'Everything OK.'
        verify_problems = '{0} problem(s) found. See the messages above and the troubleshooting guide.'
        verify_title = 'Diagnostics'
        waiting = 'Waiting for my-local-ia to answer (up to {0} min)…'
        waiting_progress = 'still starting… {0}s (the first start downloads extra files and can take several minutes)'
        windows_too_old = 'This Windows is too old for WSL 2. Update to Windows 10 version 2004 (build 19041) or newer.'
        winget_missing = 'winget is not available. Install ''App Installer'' from the Microsoft Store, or install Docker Desktop from docker.com, then run this script again.'
        wsl_install_q = 'Install WSL 2 now? Windows must restart afterwards.'
        wsl_missing = 'WSL 2 (Windows Subsystem for Linux) is not installed. Docker Desktop needs it.'
        yes_default = 'Y/n'
    }
    pt = @{
        admin_created = 'Administrador criado: {0}'
        admin_exists = 'Já existem usuários: a conta de administrador fica como está.'
        admin_failed = 'Não foi possível criar o administrador. Resposta do servidor: {0}'
        backup_cleanup = 'Backups antigos removidos (ficam os {0} mais recentes).'
        backup_done = 'Backup salvo: {0} ({1})'
        backup_list = 'Backups disponíveis:'
        backup_none = 'Nenhum backup encontrado em {0}.'
        backup_q = 'Fazer backup antes de atualizar? (recomendado)'
        backup_stop_note = 'O my-local-ia para por alguns segundos durante o backup.'
        cancelled = 'Cancelado. Nada mais foi alterado.'
        choose_lang = 'Language / Idioma'
        config_written = 'Configuração salva em {0} (só administradores conseguem ler).'
        container_died = 'O contêiner parou durante a inicialização. Últimas linhas do log dele:'
        continue_q = 'Continuar?'
        cpu = 'Processador: {0} ({1} threads)'
        data_kept = 'Dados mantidos no volume do Docker ''{0}''. Instalar de novo reaproveita os dados.'
        disk = 'Disco livre em {0}: {1} GB'
        disk_low = 'Menos de {0} GB livres. Só a imagem com GPU ocupa uns 6 GB, fora os seus modelos.'
        docker_install_q = 'Instalar o Docker Desktop agora (pelo winget)?'
        docker_installed = 'O Docker Desktop está rodando.'
        docker_missing = 'O Docker Desktop não está instalado.'
        docker_ok = 'Docker: {0}'
        docker_required = 'O Docker é necessário. Parando aqui.'
        docker_start_timeout = 'O Docker Desktop não iniciou. Abra-o pelo menu Iniciar, espere aparecer ''Engine running'' e rode este script de novo.'
        docker_starting = 'Iniciando o Docker Desktop (até {0} min). Se uma janela pedir para aceitar os termos, aceite.'
        docker_stopped = 'O Docker Desktop está instalado, mas não está rodando.'
        done_login = 'Entre com: {0}'
        done_title = 'Pronto!'
        done_update = 'Para atualizar ou trocar para o my-local-ia depois: rode este script de novo e escolha ''Atualizar''.'
        done_url = 'Abra no navegador: http://{0}:{1}'
        done_users = 'Para adicionar pessoas: Painel do admin → Usuários. Novos cadastros ficam pendentes até um admin aprovar.'
        dry_run_banner = 'MODO SIMULAÇÃO: os comandos são mostrados, nada é alterado.'
        email_invalid = 'E-mail inválido.'
        error_at = 'Erro em: {0}'
        existing_install = 'O my-local-ia já está instalado neste servidor.'
        existing_what = 'Use ''Atualizar'' para trocar de versão, ''Verificar'' para diagnosticar, ou reinstale (os dados são mantidos).'
        fw_done = 'Regra de firewall criada.'
        fw_public_profile = 'O Windows marcou esta rede como ''Pública'', onde a regra não vale. Mude em Configurações > Rede e Internet > (sua conexão) > Rede privada.'
        fw_public_skip = 'IP público: a porta não foi liberada. Para publicar, veja ''Publicar na internet'' no guia de instalação.'
        fw_windows_q = 'Liberar a porta {0} no firewall do Windows, só para a rede local?'
        gpu_continue_cpu_q = 'Continuar sem suporte à placa de vídeo? (Para velocidade total, instale antes o driver NVIDIA.)'
        gpu_driver = 'Driver NVIDIA: {0}'
        gpu_found = 'Placa de vídeo: {0}'
        gpu_no_driver = 'Foi encontrada uma placa NVIDIA, mas o driver não está instalado (falta o nvidia-smi).'
        gpu_none = 'Nenhuma placa NVIDIA encontrada. O Open WebUI vai rodar sem GPU (os modelos continuam rodando no Ollama).'
        gpu_off = 'não usada'
        gpu_skip = 'Sem placa de vídeo: pulando esta etapa.'
        gpu_test = 'Testando a placa de vídeo dentro de um contêiner…'
        gpu_test_fail = 'A placa de vídeo NÃO aparece dentro dos contêineres. Atualize o driver NVIDIA do Windows e veja ''Placa de vídeo não aparece no contêiner'' no guia de solução de problemas.'
        gpu_test_ok = 'A placa de vídeo aparece dentro dos contêineres.'
        health_ok = 'O my-local-ia está respondendo.'
        health_timeout = 'O my-local-ia não respondeu a tempo. Últimas linhas do log dele:'
        internet_fail = 'Não foi possível acessar o ghcr.io (repositório de imagens). Verifique a internet, o DNS ou o proxy.'
        internet_ok = 'Internet: OK (repositório de imagens acessível)'
        invalid_option = 'Opção inválida.'
        log_at = 'Log desta execução: {0}'
        menu_backup = 'Fazer backup dos dados agora'
        menu_exit = 'Sair'
        menu_install = 'Instalar'
        menu_prompt = 'Opção'
        menu_reset_pw = 'Redefinir a senha de um usuário'
        menu_restore = 'Restaurar um backup'
        menu_title = 'O que você quer fazer?'
        menu_uninstall = 'Desinstalar'
        menu_update = 'Atualizar ou trocar de versão (oficial / my-local-ia)'
        menu_verify = 'Verificar (só diagnóstico, não muda nada)'
        need_root = 'Rode este script no PowerShell aberto como Administrador: powershell -ExecutionPolicy Bypass -File "{0}"'
        net_lan = 'Rede: rede local (IP {0}, rede {1})'
        net_public = 'Rede: este servidor tem IP PÚBLICO ({0}). A porta NÃO será liberada no firewall automaticamente.'
        net_unknown = 'Rede: não foi possível detectar o endereço IP.'
        no_default = 's/N'
        not_installed = 'O my-local-ia não está instalado neste servidor.'
        ollama_container_fail = 'O my-local-ia não consegue falar com o Ollama. Por padrão, o Ollama no Windows só aceita conexões do próprio computador, não do Docker.'
        ollama_continue_q = 'Continuar mesmo assim?'
        ollama_dir = 'Pasta de modelos do Ollama: {0}'
        ollama_dir_missing = 'Pasta de modelos do Ollama não encontrada. O monitoramento de disco não vai enxergar os modelos.'
        ollama_down = 'O Ollama não está respondendo em {0}.'
        ollama_host_done = 'Ollama reiniciado e acessível pelo my-local-ia.'
        ollama_host_q = 'Deixar o Ollama aceitar conexões do Docker? (define OLLAMA_HOST=0.0.0.0:11434 para o seu usuário e reinicia o Ollama)'
        ollama_missing = 'O Ollama parece não estar instalado. O Open WebUI vai abrir, mas sem modelos locais.'
        ollama_models = 'Modelos instalados no Ollama: {0}'
        ollama_ok = 'Ollama {0} respondendo em {1}'
        ollama_start_q = 'O Ollama está instalado, mas não está rodando. Iniciar agora?'
        open_q = 'Reiniciar o my-local-ia para que outros computadores da rede possam acessar?'
        opened = 'O my-local-ia agora aceita conexões na porta {0}.'
        os = 'Sistema: {0}'
        os_unsupported = 'O Windows Server não é suportado pelo Docker Desktop ({0}). Use Windows 10/11 Pro ou Enterprise, ou um servidor Linux com o install-my-local-ia.sh.'
        port_busy = 'A porta {0} já está em uso neste servidor. Escolha outra.'
        port_invalid = 'Porta inválida. Use um número entre 1024 e 65535.'
        pull_fail = 'Não foi possível baixar a imagem. Verifique a internet e o log.'
        pull_fail_custom = 'Não foi possível baixar {0}. Provavelmente a imagem do my-local-ia ainda não foi publicada. Instale a versão oficial agora e troque depois em ''Atualizar''.'
        pull_ok = 'Imagem baixada.'
        pull_q = 'Baixar {0} agora? (vários GB na primeira vez)'
        pw_mismatch = 'As senhas não conferem.'
        pw_short = 'A senha precisa ter pelo menos 8 caracteres.'
        q_admin_email = 'E-mail do administrador (usado no login)'
        q_admin_intro = 'Conta de administrador do my-local-ia (o primeiro usuário, com acesso total).'
        q_admin_name = 'Nome do administrador'
        q_admin_pw = 'Senha (mínimo de 8 caracteres, oculta)'
        q_admin_pw2 = 'Repita a senha'
        q_backup_pick = 'Número do backup a restaurar'
        q_github_user = 'Seu usuário do GitHub (dono do repositório my-local-ia)'
        q_models_dir = 'Pasta de modelos do Ollama'
        q_ollama_url = 'Endereço do Ollama'
        q_port = 'Porta de acesso ao my-local-ia'
        q_reset_email = 'E-mail do usuário'
        q_update_keep = 'A mesma versão, na atualização mais recente'
        q_update_version = 'Qual versão você quer?'
        q_version = 'Qual versão você quer instalar?'
        q_version_custom = 'my-local-ia (versão personalizada do seu repositório no GitHub)'
        q_version_local = 'my-local-ia compilado aqui neste computador a partir do código-fonte (20–60 minutos)'
        q_repo_url = 'Endereço do repositório do my-local-ia no GitHub'
        q_repo_branch = 'Branch'
        step_build = 'Compilando a imagem do my-local-ia neste computador'
        build_q = 'Compilar {0} agora? Leva de 20 a 60 minutos e uns {1} GB de disco.'
        build_disk_low = 'Só há {0} GB livres no C:; a compilação precisa de uns {1} GB. Libere espaço antes, senão ela pode falhar no meio.'
        build_source = 'Código-fonte: {0} ({1}), commit {2}'
        build_ok = 'Imagem compilada: {0}'
        build_fail = 'A compilação falhou. A versão instalada não foi alterada. O log mostra a etapa que falhou.'
        build_clean_q = 'Apagar o cache de compilação e imagens antigas do my-local-ia para liberar disco?'
        q_version_official = 'Open WebUI oficial (recomendado por enquanto)'
        ram = 'RAM: {0} GB'
        reboot_needed = 'Reinicie o Windows agora. Depois rode este script de novo e escolha Instalar: ele continua de onde parou.'
        reinstall_q = 'Recriar o contêiner agora? Usuários, conversas e configurações são mantidos.'
        report_saved = 'Relatório salvo em {0} (mande este arquivo ao pedir ajuda).'
        reset_done = 'Senha alterada para {0}.'
        reset_notfound = 'Nenhum usuário com o e-mail {0}.'
        reset_unsupported = 'Esta opção só funciona com o banco de dados padrão (SQLite).'
        restore_done = 'Backup restaurado.'
        restore_warn = 'Os dados atuais (usuários, conversas, configurações) serão SUBSTITUÍDOS pelo backup.'
        resuming = 'Continuando a instalação com as respostas dadas antes de reiniciar.'
        rollback_done = 'Versão anterior restaurada. Se os dados já tiverem sido convertidos pela versão nova, restaure o backup feito antes da atualização (opção ''Restaurar'').'
        secret_kept = 'Chave secreta existente mantida (os usuários continuam logados).'
        secret_new = 'Nova chave secreta gerada.'
        see_docs = 'Ajuda: docs/{0}/TROUBLESHOOTING.md (na pasta my-local-ia)'
        see_log = 'Log completo: {0}'
        start_q = 'Criar e iniciar o contêiner agora?'
        step_admin = 'Conta de administrador'
        step_checks = 'Verificando este servidor (não muda nada)'
        step_config = 'Arquivos de configuração'
        step_docker = 'Docker'
        step_firewall = 'Firewall'
        step_gpu = 'Suporte à placa de vídeo no Docker Desktop'
        step_open = 'Liberando para a rede local'
        step_pull = 'Baixando a imagem'
        step_questions = 'Perguntas'
        step_replace = 'Trocando para a nova versão'
        step_start = 'Iniciando (por enquanto, acessível só por este servidor)'
        step_tests = 'Testes finais'
        summary_gpu = 'Placa de vídeo: {0}'
        summary_image = 'Imagem: {0}'
        summary_ollama = 'Ollama: {0}'
        summary_port = 'Endereço: http://{0}:{1}'
        summary_title = 'Resumo do que será feito:'
        test_container = 'Contêiner rodando: {0} (imagem {1})'
        test_container_fail = 'O contêiner não está rodando.'
        test_gpu = 'Placa de vídeo dentro do contêiner: {0}'
        test_gpu_fail = 'A placa de vídeo não aparece dentro do contêiner.'
        test_health = 'Interface web respondendo na porta {0}'
        test_health_fail = 'A interface web não está respondendo na porta {0}'
        test_hw = 'Hardware detectado pelo my-local-ia: {0}'
        test_listen = 'Aceitando conexões de toda a rede (porta {0})'
        test_listen_local = 'Aceitando conexões só deste servidor (porta {0})'
        test_models = 'Modelos visíveis no my-local-ia: {0}'
        test_ollama = 'Conexão do my-local-ia com o Ollama: OK'
        test_ollama_fail = 'O my-local-ia não consegue falar com o Ollama em {0}'
        title = 'Instalador do my-local-ia (Open WebUI + Ollama)'
        uninstall_backup_q = 'Fazer backup antes de apagar?'
        uninstall_conf_q = 'Remover a configuração em {0}?'
        uninstall_data_confirm = 'Digite DELETE para confirmar'
        uninstall_data_q = 'APAGAR também todos os dados (usuários, conversas, configurações)? Não tem volta.'
        uninstall_done = 'my-local-ia removido.'
        uninstall_q = 'Remover o contêiner?'
        uninstall_warn = 'Isto remove o contêiner do my-local-ia. Docker, Ollama e seus modelos NÃO são mexidos.'
        update_current = 'Imagem instalada: {0}'
        update_ok = 'Atualização concluída. Imagem: {0}'
        update_rollback = 'A versão nova não iniciou. Voltando para a anterior…'
        update_swap = 'Trocando o contêiner (o antigo é mantido até o novo responder)…'
        verify_ok = 'Tudo OK.'
        verify_problems = '{0} problema(s) encontrado(s). Veja as mensagens acima e o guia de solução de problemas.'
        verify_title = 'Diagnóstico'
        waiting = 'Aguardando o my-local-ia responder (até {0} min)…'
        waiting_progress = 'ainda iniciando… {0}s (a primeira inicialização baixa arquivos extras e pode levar alguns minutos)'
        windows_too_old = 'Este Windows é antigo demais para o WSL 2. Atualize para o Windows 10 versão 2004 (build 19041) ou mais novo.'
        winget_missing = 'O winget não está disponível. Instale o ''Instalador de Aplicativo'' pela Microsoft Store, ou instale o Docker Desktop pelo site docker.com, e rode este script de novo.'
        wsl_install_q = 'Instalar o WSL 2 agora? O Windows precisa reiniciar depois.'
        wsl_missing = 'O WSL 2 (Subsistema do Windows para Linux) não está instalado. O Docker Desktop precisa dele.'
        yes_default = 'S/n'
    }
    es = @{
        admin_created = 'Administrador creado: {0}'
        admin_exists = 'Ya existen usuarios: la cuenta de administrador se deja como está.'
        admin_failed = 'No se pudo crear el administrador. Respuesta del servidor: {0}'
        backup_cleanup = 'Copias antiguas eliminadas (se conservan las {0} más recientes).'
        backup_done = 'Copia guardada: {0} ({1})'
        backup_list = 'Copias disponibles:'
        backup_none = 'No se encontraron copias en {0}.'
        backup_q = '¿Hacer copia de seguridad antes de actualizar? (recomendado)'
        backup_stop_note = 'my-local-ia se detiene unos segundos durante la copia.'
        cancelled = 'Cancelado. No se cambió nada más.'
        choose_lang = 'Language / Idioma'
        config_written = 'Configuración guardada en {0} (solo los administradores pueden leerla).'
        container_died = 'El contenedor se detuvo durante el inicio. Últimas líneas de su registro:'
        continue_q = '¿Continuar?'
        cpu = 'Procesador: {0} ({1} hilos)'
        data_kept = 'Datos conservados en el volumen de Docker ''{0}''. Instalar de nuevo los reutiliza.'
        disk = 'Disco libre en {0}: {1} GB'
        disk_low = 'Menos de {0} GB libres. Solo la imagen con GPU ocupa unos 6 GB, además de tus modelos.'
        docker_install_q = '¿Instalar Docker Desktop ahora (con winget)?'
        docker_installed = 'Docker Desktop está en ejecución.'
        docker_missing = 'Docker Desktop no está instalado.'
        docker_ok = 'Docker: {0}'
        docker_required = 'Docker es necesario. Se detiene aquí.'
        docker_start_timeout = 'Docker Desktop no inició. Ábrelo desde el menú Inicio, espera a que diga ''Engine running'' y ejecuta este script de nuevo.'
        docker_starting = 'Iniciando Docker Desktop (hasta {0} min). Si una ventana te pide aceptar los términos, acéptalos.'
        docker_stopped = 'Docker Desktop está instalado pero no está en ejecución.'
        done_login = 'Inicia sesión con: {0}'
        done_title = '¡Listo!'
        done_update = 'Para actualizar o cambiar a my-local-ia después: ejecuta este script de nuevo y elige ''Actualizar''.'
        done_url = 'Abre en el navegador: http://{0}:{1}'
        done_users = 'Para agregar personas: Panel de administración → Usuarios. Los nuevos registros quedan pendientes hasta que un administrador los apruebe.'
        dry_run_banner = 'MODO SIMULACIÓN: se muestran los comandos, no se cambia nada.'
        email_invalid = 'Correo no válido.'
        error_at = 'Error en: {0}'
        existing_install = 'my-local-ia ya está instalado en este servidor.'
        existing_what = 'Usa ''Actualizar'' para cambiar de versión, ''Verificar'' para diagnosticar, o reinstala (los datos se conservan).'
        fw_done = 'Regla de firewall creada.'
        fw_public_profile = 'Windows marcó esta red como ''Pública'', donde la regla no se aplica. Cámbialo en Configuración > Red e Internet > (tu conexión) > Red privada.'
        fw_public_skip = 'IP pública: no se abrió el puerto. Para publicarlo, consulta ''Publicar en internet'' en la guía de instalación.'
        fw_windows_q = '¿Permitir el puerto {0} en el firewall de Windows, solo para la red local?'
        gpu_continue_cpu_q = '¿Continuar sin soporte de GPU? (Para máxima velocidad, instala antes el controlador NVIDIA.)'
        gpu_driver = 'Controlador NVIDIA: {0}'
        gpu_found = 'GPU: {0}'
        gpu_no_driver = 'Se encontró una tarjeta NVIDIA, pero el controlador no está instalado (falta nvidia-smi).'
        gpu_none = 'No se encontró GPU NVIDIA. Open WebUI funcionará sin GPU (los modelos siguen ejecutándose en Ollama).'
        gpu_off = 'no se usa'
        gpu_skip = 'Sin GPU: se omite este paso.'
        gpu_test = 'Probando la GPU dentro de un contenedor…'
        gpu_test_fail = 'La GPU NO es visible dentro de los contenedores. Actualiza el controlador NVIDIA de Windows y consulta ''La GPU no aparece en el contenedor'' en la guía de solución de problemas.'
        gpu_test_ok = 'La GPU es visible dentro de los contenedores.'
        health_ok = 'my-local-ia está respondiendo.'
        health_timeout = 'my-local-ia no respondió a tiempo. Últimas líneas de su registro:'
        internet_fail = 'No se pudo acceder a ghcr.io (registro de imágenes). Revisa la conexión a internet, el DNS o el proxy.'
        internet_ok = 'Internet: OK (registro de imágenes accesible)'
        invalid_option = 'Opción no válida.'
        log_at = 'Registro de esta ejecución: {0}'
        menu_backup = 'Hacer copia de seguridad ahora'
        menu_exit = 'Salir'
        menu_install = 'Instalar'
        menu_prompt = 'Opción'
        menu_reset_pw = 'Restablecer la contraseña de un usuario'
        menu_restore = 'Restaurar una copia de seguridad'
        menu_title = '¿Qué quieres hacer?'
        menu_uninstall = 'Desinstalar'
        menu_update = 'Actualizar o cambiar de versión (oficial / my-local-ia)'
        menu_verify = 'Verificar (solo diagnóstico, no cambia nada)'
        need_root = 'Ejecuta este script en PowerShell abierto como Administrador: powershell -ExecutionPolicy Bypass -File "{0}"'
        net_lan = 'Red: red local (IP {0}, red {1})'
        net_public = 'Red: este servidor tiene IP PÚBLICA ({0}). El puerto NO se abrirá en el firewall automáticamente.'
        net_unknown = 'Red: no se pudo detectar la dirección IP.'
        no_default = 's/N'
        not_installed = 'my-local-ia no está instalado en este servidor.'
        ollama_container_fail = 'my-local-ia no puede conectar con Ollama. Por defecto, Ollama en Windows solo acepta conexiones del propio equipo, no de Docker.'
        ollama_continue_q = '¿Continuar de todos modos?'
        ollama_dir = 'Carpeta de modelos de Ollama: {0}'
        ollama_dir_missing = 'No se encontró la carpeta de modelos de Ollama. El monitoreo de disco no verá los modelos.'
        ollama_down = 'Ollama no responde en {0}.'
        ollama_host_done = 'Ollama reiniciado y accesible desde my-local-ia.'
        ollama_host_q = '¿Permitir que Ollama acepte conexiones de Docker? (define OLLAMA_HOST=0.0.0.0:11434 para tu usuario y reinicia Ollama)'
        ollama_missing = 'Ollama no parece estar instalado. Open WebUI se abrirá, pero sin modelos locales.'
        ollama_models = 'Modelos instalados en Ollama: {0}'
        ollama_ok = 'Ollama {0} respondiendo en {1}'
        ollama_start_q = 'Ollama está instalado pero no está en ejecución. ¿Iniciarlo ahora?'
        open_q = '¿Reiniciar my-local-ia para que otros equipos de la red puedan acceder?'
        opened = 'my-local-ia ahora acepta conexiones en el puerto {0}.'
        os = 'Sistema: {0}'
        os_unsupported = 'Windows Server no es compatible con Docker Desktop ({0}). Usa Windows 10/11 Pro o Enterprise, o un servidor Linux con install-my-local-ia.sh.'
        port_busy = 'El puerto {0} ya está en uso en este servidor. Elige otro.'
        port_invalid = 'Puerto no válido. Usa un número entre 1024 y 65535.'
        pull_fail = 'No se pudo descargar la imagen. Revisa la conexión a internet y el registro.'
        pull_fail_custom = 'No se pudo descargar {0}. Probablemente la imagen de my-local-ia aún no está publicada. Instala la versión oficial ahora y cambia después con ''Actualizar''.'
        pull_ok = 'Imagen descargada.'
        pull_q = '¿Descargar {0} ahora? (varios GB la primera vez)'
        pw_mismatch = 'Las contraseñas no coinciden.'
        pw_short = 'La contraseña debe tener al menos 8 caracteres.'
        q_admin_email = 'Correo del administrador (para iniciar sesión)'
        q_admin_intro = 'Cuenta de administrador de my-local-ia (el primer usuario, con acceso total).'
        q_admin_name = 'Nombre del administrador'
        q_admin_pw = 'Contraseña (mínimo 8 caracteres, oculta)'
        q_admin_pw2 = 'Repite la contraseña'
        q_backup_pick = 'Número de la copia a restaurar'
        q_github_user = 'Tu usuario de GitHub (dueño del repositorio my-local-ia)'
        q_models_dir = 'Carpeta de modelos de Ollama'
        q_ollama_url = 'Dirección de Ollama'
        q_port = 'Puerto de acceso a my-local-ia'
        q_reset_email = 'Correo del usuario'
        q_update_keep = 'La misma versión, en su última actualización'
        q_update_version = '¿Qué versión quieres?'
        q_version = '¿Qué versión quieres instalar?'
        q_version_custom = 'my-local-ia (versión personalizada de tu repositorio en GitHub)'
        q_version_local = 'my-local-ia compilado aquí en este equipo desde el código fuente (20–60 minutos)'
        q_repo_url = 'Dirección del repositorio de my-local-ia en GitHub'
        q_repo_branch = 'Rama'
        step_build = 'Compilando la imagen de my-local-ia en este equipo'
        build_q = '¿Compilar {0} ahora? Tarda de 20 a 60 minutos y ocupa unos {1} GB de disco.'
        build_disk_low = 'Solo hay {0} GB libres en C:; la compilación necesita unos {1} GB. Libera espacio antes o puede fallar a mitad.'
        build_source = 'Código fuente: {0} ({1}), commit {2}'
        build_ok = 'Imagen compilada: {0}'
        build_fail = 'La compilación falló. La versión instalada no se tocó. El registro muestra el paso que falló.'
        build_clean_q = '¿Borrar la caché de compilación y las imágenes antiguas de my-local-ia para liberar disco?'
        q_version_official = 'Open WebUI oficial (recomendado por ahora)'
        ram = 'RAM: {0} GB'
        reboot_needed = 'Reinicia Windows ahora. Después ejecuta este script de nuevo y elige Instalar: continúa donde se quedó.'
        reinstall_q = '¿Recrear el contenedor ahora? Usuarios, chats y ajustes se conservan.'
        report_saved = 'Informe guardado en {0} (envía este archivo al pedir ayuda).'
        reset_done = 'Contraseña cambiada para {0}.'
        reset_notfound = 'No hay ningún usuario con el correo {0}.'
        reset_unsupported = 'Esta opción solo funciona con la base de datos predeterminada (SQLite).'
        restore_done = 'Copia restaurada.'
        restore_warn = 'Los datos actuales (usuarios, chats, ajustes) serán REEMPLAZADOS por la copia.'
        resuming = 'Continuando la instalación con las respuestas dadas antes del reinicio.'
        rollback_done = 'Versión anterior restaurada. Si la nueva versión ya convirtió los datos, restaura la copia hecha antes de la actualización (opción ''Restaurar'').'
        secret_kept = 'Se conservó la clave secreta existente (los usuarios siguen con sesión iniciada).'
        secret_new = 'Nueva clave secreta generada.'
        see_docs = 'Ayuda: docs/{0}/TROUBLESHOOTING.md (en la carpeta my-local-ia)'
        see_log = 'Registro completo: {0}'
        start_q = '¿Crear e iniciar el contenedor ahora?'
        step_admin = 'Cuenta de administrador'
        step_checks = 'Revisando este servidor (no cambia nada)'
        step_config = 'Archivos de configuración'
        step_docker = 'Docker'
        step_firewall = 'Firewall'
        step_gpu = 'Soporte de GPU en Docker Desktop'
        step_open = 'Abriendo a la red local'
        step_pull = 'Descargando la imagen'
        step_questions = 'Preguntas'
        step_replace = 'Cambiando a la nueva versión'
        step_start = 'Iniciando (por ahora, accesible solo desde este servidor)'
        step_tests = 'Pruebas finales'
        summary_gpu = 'GPU: {0}'
        summary_image = 'Imagen: {0}'
        summary_ollama = 'Ollama: {0}'
        summary_port = 'Dirección: http://{0}:{1}'
        summary_title = 'Resumen de lo que se hará:'
        test_container = 'Contenedor en ejecución: {0} (imagen {1})'
        test_container_fail = 'El contenedor no está en ejecución.'
        test_gpu = 'GPU dentro del contenedor: {0}'
        test_gpu_fail = 'La GPU no es visible dentro del contenedor.'
        test_health = 'Interfaz web respondiendo en el puerto {0}'
        test_health_fail = 'La interfaz web no responde en el puerto {0}'
        test_hw = 'Hardware detectado por my-local-ia: {0}'
        test_listen = 'Aceptando conexiones de toda la red (puerto {0})'
        test_listen_local = 'Aceptando conexiones solo de este servidor (puerto {0})'
        test_models = 'Modelos visibles en my-local-ia: {0}'
        test_ollama = 'Conexión de my-local-ia con Ollama: OK'
        test_ollama_fail = 'my-local-ia no puede conectar con Ollama en {0}'
        title = 'Instalador de my-local-ia (Open WebUI + Ollama)'
        uninstall_backup_q = '¿Hacer copia de seguridad antes de borrar?'
        uninstall_conf_q = '¿Quitar la configuración en {0}?'
        uninstall_data_confirm = 'Escribe DELETE para confirmar'
        uninstall_data_q = '¿BORRAR también todos los datos (usuarios, chats, ajustes)? No se puede deshacer.'
        uninstall_done = 'my-local-ia eliminado.'
        uninstall_q = '¿Quitar el contenedor?'
        uninstall_warn = 'Esto quita el contenedor de my-local-ia. Docker, Ollama y tus modelos NO se tocan.'
        update_current = 'Imagen instalada: {0}'
        update_ok = 'Actualización terminada. Imagen: {0}'
        update_rollback = 'La nueva versión no inició. Volviendo a la anterior…'
        update_swap = 'Reemplazando el contenedor (el anterior se conserva hasta que el nuevo responda)…'
        verify_ok = 'Todo OK.'
        verify_problems = 'Se encontraron {0} problema(s). Revisa los mensajes de arriba y la guía de solución de problemas.'
        verify_title = 'Diagnóstico'
        waiting = 'Esperando a que my-local-ia responda (hasta {0} min)…'
        waiting_progress = 'todavía iniciando… {0}s (el primer inicio descarga archivos extra y puede tardar varios minutos)'
        windows_too_old = 'Este Windows es demasiado antiguo para WSL 2. Actualiza a Windows 10 versión 2004 (compilación 19041) o posterior.'
        winget_missing = 'winget no está disponible. Instala ''Instalador de aplicación'' desde Microsoft Store, o instala Docker Desktop desde docker.com, y ejecuta este script de nuevo.'
        wsl_install_q = '¿Instalar WSL 2 ahora? Windows debe reiniciarse después.'
        wsl_missing = 'WSL 2 (Subsistema de Windows para Linux) no está instalado. Docker Desktop lo necesita.'
        yes_default = 'S/n'
    }
}

############################################
# Output helpers
############################################

# Msg KEY [VALUES...]: message in the chosen language, falling back to English.
# Msg, Run and Capture are simple functions on purpose: in an advanced function,
# arguments such as -o, -w or -d would be taken as PowerShell's common parameters.
function Msg {
    $key = $args[0]
    $values = @($args | Select-Object -Skip 1)
    $code = $Script:LangCode
    if (-not $code) { $code = 'en' }
    $fmt = $Messages[$code][$key]
    if (-not $fmt) { $fmt = $Messages['en'][$key] }
    if (-not $fmt) { return $key }
    if ($values.Count -gt 0) { return ($fmt -f $values) }
    return $fmt
}

function Write-Log([string]$Text) {
    try { Add-Content -Path $LogFile -Value $Text -Encoding UTF8 } catch { }
}

function Say([string]$Text, [string]$Color = 'Gray') {
    Write-Host $Text -ForegroundColor $Color
    Write-Log $Text
}
function Info([string]$Text) { Say "  $Text" 'Gray' }
function Ok([string]$Text) { Say "  [OK] $Text" 'Green' }
function Warn([string]$Text) { Say "  [!] $Text" 'Yellow' }
function Fail([string]$Text) { Say "  [X] $Text" 'Red' }
function Step([string]$Text) {
    $Script:Step++
    Write-Host ''
    Say "[$($Script:Step)/$($Script:StepTotal)] $Text" 'Cyan'
}

function Docs-Lang {
    switch ($Script:LangCode) { 'pt' { 'pt-BR' } 'es' { 'es' } default { 'en' } }
}

function Stop-WithError([string]$Text) {
    Fail $Text
    Info (Msg 'see_log' $LogFile)
    Info (Msg 'see_docs' (Docs-Lang))
    exit 1
}

# Run PROGRAM [ARGS...]: shows the command, runs it and logs its output. Returns $true on success.
function Run {
    $file = $args[0]
    $arguments = @($args | Select-Object -Skip 1)
    Say ("    > $file " + ($arguments -join ' ')) 'DarkGray'
    if ($Script:IsDryRun) { return $true }
    if (-not (Test-Command $file)) { Fail "$file ?"; return $false }
    $ErrorActionPreference = 'Continue'   # native tools write progress to stderr
    & $file @arguments 2>&1 | ForEach-Object {
        $line = "$_"
        Write-Host "    $line" -ForegroundColor DarkGray
        Write-Log $line
    }
    return ($LASTEXITCODE -eq 0)
}

# Capture PROGRAM [ARGS...]: runs a program quietly and returns its output (for checks that change nothing).
function Capture {
    $file = $args[0]
    $arguments = @($args | Select-Object -Skip 1)
    if (-not (Test-Command $file)) {
        $Script:LastExit = 127
        return ''
    }
    $ErrorActionPreference = 'Continue'
    try {
        $out = & $file @arguments 2>$null
        $Script:LastExit = $LASTEXITCODE
        return ($out -join "`n")
    } catch {
        $Script:LastExit = 1
        return ''
    }
}

function Test-Command([string]$Name) { [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

function Ask([string]$Prompt, [string]$Default = '') {
    $suffix = ''
    if ($Default) { $suffix = " [$Default]" }
    $answer = Read-Host "  $Prompt$suffix"
    if (-not $answer) { $answer = $Default }
    Write-Log "  ${Prompt}: $answer"
    return $answer
}

function Ask-Secret([string]$Prompt) {
    $secure = Read-Host "  $Prompt" -AsSecureString
    Write-Log "  ${Prompt}: ********"
    $ptr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
    try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ptr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ptr) }
}

function Confirm([string]$Prompt, [string]$Default = 'Y') {
    if ($Default -eq 'Y') { $hint = Msg 'yes_default' } else { $hint = Msg 'no_default' }
    $answer = Read-Host "  $Prompt [$hint]"
    if (-not $answer) { $answer = $Default }
    Write-Log "  ${Prompt}: $answer"
    return ($answer.ToLower() -in @('y', 'yes', 's', 'sim', 'si', 'sí'))
}

function Confirm-OrStop([string]$Prompt, [string]$Default = 'Y') {
    if (-not (Confirm $Prompt $Default)) {
        Warn (Msg 'cancelled')
        exit 0
    }
}

function Choose([string]$Prompt, [string[]]$Options) {
    Info $Prompt
    for ($i = 0; $i -lt $Options.Count; $i++) { Info "  $($i + 1)) $($Options[$i])" }
    while ($true) {
        $answer = Read-Host "  $(Msg 'menu_prompt') [1]"
        if (-not $answer) { $answer = '1' }
        $n = 0
        if ([int]::TryParse($answer, [ref]$n) -and $n -ge 1 -and $n -le $Options.Count) {
            Write-Log "  -> $n"
            return $n
        }
        Warn (Msg 'invalid_option')
    }
}

############################################
# Settings
############################################

function Load-Conf {
    if (Test-Path $ConfFile) {
        try {
            $saved = Get-Content $ConfFile -Raw | ConvertFrom-Json
            foreach ($key in @($Script:Conf.Keys)) {
                if ($null -ne $saved.$key) { $Script:Conf[$key] = [string]$saved.$key }
            }
        } catch { }
    }
}

function Protect-ConfDir {
    # Only Administrators (S-1-5-32-544) and SYSTEM (S-1-5-18): names differ by Windows language, SIDs don't.
    $null = Capture icacls.exe $ConfDir /inheritance:r /grant:r '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-18:(OI)(CI)F'
}

function Save-Conf {
    Say "    > $ConfFile" 'DarkGray'
    if ($Script:IsDryRun) { return }
    New-Item -ItemType Directory -Force -Path $ConfDir | Out-Null
    $Script:Conf | ConvertTo-Json | Set-Content -Path $ConfFile -Encoding UTF8
}

function Write-EnvFile {
    $secret = ''
    if (Test-Path $EnvFile) {
        $line = Get-Content $EnvFile | Where-Object { $_ -like 'WEBUI_SECRET_KEY=*' } | Select-Object -First 1
        if ($line) { $secret = $line.Substring('WEBUI_SECRET_KEY='.Length) }
    }
    if ($secret) {
        Ok (Msg 'secret_kept')
    } else {
        $bytes = New-Object byte[] 48
        [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
        $secret = ([Convert]::ToBase64String($bytes) -replace '[^A-Za-z0-9]', '').Substring(0, 48)
        Ok (Msg 'secret_new')
    }
    Say "    > $EnvFile" 'DarkGray'
    if ($Script:IsDryRun) { return }
    $content = @(
        '# my-local-ia container settings. Readable only by administrators: contains the secret key.'
        "OLLAMA_BASE_URL=$($Script:Conf.OllamaUrl)"
        "WEBUI_SECRET_KEY=$secret"
        'MY_LOCAL_IA_OLLAMA_MODELS_DIR=/ollama-models'
    )
    [IO.File]::WriteAllLines($EnvFile, $content)  # UTF-8 without BOM: Docker reads it as plain text
    Protect-ConfDir
    Ok (Msg 'config_written' $ConfDir)
}

function Official-Image {
    if ($Script:Conf.UseGpu -eq 'yes') { $OfficialImageGpu } else { $OfficialImageCpu }
}

function Custom-Image {
    $tag = 'main'
    if ($Script:Conf.UseGpu -eq 'yes') { $tag = 'cuda' }
    "ghcr.io/$($Script:Conf.GithubUser.ToLower())/${CustomImageName}:$tag"
}

function Ask-GithubUser {
    do {
        $Script:Conf.GithubUser = Ask (Msg 'q_github_user') $Script:Conf.GithubUser
    } while ($Script:Conf.GithubUser -notmatch '^[A-Za-z0-9-]+$')
}

function Local-Image {
    $tag = 'local-main'
    if ($Script:Conf.UseGpu -eq 'yes') { $tag = 'local-cuda' }
    "${LocalImageName}:$tag"
}

function Ask-Repo {
    Ask-GithubUser
    $default = $Script:Conf.RepoUrl
    if (-not $default) { $default = "https://github.com/$($Script:Conf.GithubUser)/my-local-ia" }
    do {
        $Script:Conf.RepoUrl = (Ask (Msg 'q_repo_url') $default) -replace '\.git$', '' -replace '/+$', ''
    } while ($Script:Conf.RepoUrl -notmatch '^https://github\.com/[^/]+/[^/]+$')
    $branch = $Script:Conf.RepoBranch
    if (-not $branch) { $branch = 'main' }
    $Script:Conf.RepoBranch = Ask (Msg 'q_repo_branch') $branch
}

############################################
# Checks (read-only)
############################################

function Test-Admin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal $identity).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Check-Os {
    $os = Get-CimInstance Win32_OperatingSystem
    Info (Msg 'os' "$($os.Caption) (build $($os.BuildNumber))")
    if ($os.ProductType -ne 1) { Stop-WithError (Msg 'os_unsupported' $os.Caption) }
    if ([int]$os.BuildNumber -lt 19041) { Stop-WithError (Msg 'windows_too_old') }
}

function Check-Resources {
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $os = Get-CimInstance Win32_OperatingSystem
    Info (Msg 'cpu' $cpu.Name.Trim() ([Environment]::ProcessorCount))
    Info (Msg 'ram' ([math]::Round($os.TotalVisibleMemorySize / 1MB, 1)))
    $drive = Get-PSDrive -Name C
    $free = [math]::Floor($drive.Free / 1GB)
    Info (Msg 'disk' 'C:' $free)
    if ($free -lt $MinFreeGb) { Warn (Msg 'disk_low' $MinFreeGb) }
}

function Get-HttpStatus([string]$Url, [int]$Timeout = 10) {
    $code = Capture curl.exe -s -o NUL -w '%{http_code}' --max-time $Timeout $Url
    if ($code -match '^\d{3}$') { return [int]$code }
    return 0
}

function Check-Internet {
    $code = Get-HttpStatus 'https://ghcr.io/v2/' 15
    if ($code -ge 200 -and $code -lt 500) { Ok (Msg 'internet_ok'); return $true }
    Warn (Msg 'internet_fail')
    return $false
}

function Check-Gpu {
    $Script:GpuList = @()
    $hasNvidia = [bool](Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' })
    if (Test-Command nvidia-smi) {
        $out = Capture nvidia-smi --query-gpu=name,memory.total --format=csv,noheader
        if ($Script:LastExit -eq 0 -and $out) {
            $Script:GpuList = @($out -split "`n" | Where-Object { $_.Trim() })
            foreach ($gpu in $Script:GpuList) { Ok (Msg 'gpu_found' $gpu.Trim()) }
            $driver = (Capture nvidia-smi --query-gpu=driver_version --format=csv,noheader) -split "`n" | Select-Object -First 1
            Info (Msg 'gpu_driver' $driver)
            return $true
        }
    }
    if ($hasNvidia) {
        Warn (Msg 'gpu_no_driver')
        if (-not $Script:ReadOnly) { Confirm-OrStop (Msg 'gpu_continue_cpu_q') 'N' }
    } else {
        Info (Msg 'gpu_none')
    }
    return $false
}

function Get-OllamaVersion([string]$Url) {
    try { return (Invoke-RestMethod -Uri "$Url/api/version" -TimeoutSec 5).version } catch { return '' }
}

function Count-OllamaModels([string]$Url) {
    try { return @((Invoke-RestMethod -Uri "$Url/api/tags" -TimeoutSec 10).models).Count } catch { return 0 }
}

function Find-ModelsDir {
    foreach ($scope in 'User', 'Machine') {
        $dir = [Environment]::GetEnvironmentVariable('OLLAMA_MODELS', $scope)
        if ($dir -and (Test-Path $dir)) { return $dir }
    }
    $default = Join-Path $env:USERPROFILE '.ollama\models'
    if (Test-Path $default) { return $default }
    return ''
}

function Check-Ollama {
    $version = Get-OllamaVersion $HostOllamaUrl
    if (-not $version -and -not $Script:ReadOnly -and (Test-Path $OllamaAppExe)) {
        Warn (Msg 'ollama_down' $HostOllamaUrl)
        if (Confirm (Msg 'ollama_start_q')) {
            if (-not $Script:IsDryRun) {
                Start-Process -FilePath $OllamaAppExe
                Start-Sleep -Seconds 5
            }
            $version = Get-OllamaVersion $HostOllamaUrl
        }
    }
    if ($version) {
        Ok (Msg 'ollama_ok' $version $HostOllamaUrl)
        Info (Msg 'ollama_models' (Count-OllamaModels $HostOllamaUrl))
    } else {
        if ((Test-Command ollama) -or (Test-Path $OllamaAppExe)) { Warn (Msg 'ollama_down' $HostOllamaUrl) } else { Warn (Msg 'ollama_missing') }
        if (-not $Script:ReadOnly) { Confirm-OrStop (Msg 'ollama_continue_q') 'N' }
    }
    if (-not $Script:Conf.ModelsDir) { $Script:Conf.ModelsDir = Find-ModelsDir }
    if ($Script:Conf.ModelsDir) { Info (Msg 'ollama_dir' $Script:Conf.ModelsDir) } else { Warn (Msg 'ollama_dir_missing') }
}

function Test-Wsl {
    $null = Capture wsl.exe --status
    return ($Script:LastExit -eq 0)
}

function Test-DockerReady {
    if (-not (Test-Command docker)) { return $false }
    $null = Capture docker info
    return ($Script:LastExit -eq 0)
}

function Check-Docker {
    if (-not (Test-Wsl)) { Warn (Msg 'wsl_missing') }
    if (-not (Test-Command docker)) { Warn (Msg 'docker_missing'); return $false }
    if (-not (Test-DockerReady)) { Warn (Msg 'docker_stopped'); return $false }
    Ok (Msg 'docker_ok' (Capture docker --version))
    return $true
}

function Test-PrivateIp([string]$Ip) {
    return ($Ip -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.|100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.)')
}

function Check-Network {
    $config = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
    if (-not $config) {
        $Script:AccessMode = 'unknown'
        Warn (Msg 'net_unknown')
        return
    }
    $address = $config.IPv4Address | Select-Object -First 1
    $Script:LanIp = $address.IPAddress
    $Script:NetCategory = "$($config.NetProfile.NetworkCategory)"
    if (Test-PrivateIp $Script:LanIp) {
        $Script:AccessMode = 'lan'
        Ok (Msg 'net_lan' $Script:LanIp "$($Script:LanIp)/$($address.PrefixLength)")
    } else {
        $Script:AccessMode = 'public'
        Warn (Msg 'net_public' $Script:LanIp)
    }
}

function Test-ContainerExists([string]$Name) {
    if (-not (Test-DockerReady)) { return $false }
    $names = Capture docker ps -a --format '{{.Names}}'
    return (@($names -split "`n") -contains $Name)
}

function Test-ContainerRunning([string]$Name) {
    return ((Capture docker inspect -f '{{.State.Running}}' $Name) -eq 'true')
}

function Test-PortInUse([int]$Port) {
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

############################################
# Install steps
############################################

function Ask-Questions {
    if ($Script:GpuList.Count -gt 0) { $Script:Conf.UseGpu = 'yes' } else { $Script:Conf.UseGpu = 'no' }
    $choice = Choose (Msg 'q_version') @((Msg 'q_version_official'), (Msg 'q_version_custom'), (Msg 'q_version_local'))
    switch ($choice) {
        2 { $Script:Conf.ImageKind = 'custom'; Ask-GithubUser; $Script:Conf.Image = Custom-Image }
        3 { $Script:Conf.ImageKind = 'local'; Ask-Repo; $Script:Conf.Image = Local-Image }
        default { $Script:Conf.ImageKind = 'official'; $Script:Conf.Image = Official-Image }
    }

    $savedPort = $Script:Conf.Port
    while ($true) {
        $default = $Script:Conf.Port
        if (-not $default) { $default = "$DefaultPort" }
        $answer = Ask (Msg 'q_port') $default
        $port = 0
        if (-not [int]::TryParse($answer, [ref]$port) -or $port -lt 1024 -or $port -gt 65535) {
            Warn (Msg 'port_invalid')
        } elseif ((Test-PortInUse $port) -and -not ("$port" -eq $savedPort -and (Test-ContainerExists $Container))) {
            Warn (Msg 'port_busy' $port)
        } else {
            $Script:Conf.Port = "$port"
            break
        }
    }
    $default = $Script:Conf.OllamaUrl
    if (-not $default) { $default = $DefaultOllamaUrl }
    $Script:Conf.OllamaUrl = Ask (Msg 'q_ollama_url') $default
    $Script:Conf.ModelsDir = Ask (Msg 'q_models_dir') $Script:Conf.ModelsDir
}

function Ask-Admin {
    Info (Msg 'q_admin_intro')
    $Script:AdminName = Ask (Msg 'q_admin_name') 'Admin'
    while ($true) {
        $Script:AdminEmail = Ask (Msg 'q_admin_email')
        if ($Script:AdminEmail -match '^[^@\s]+@[^@\s]+\.[^@\s]+$') { break }
        Warn (Msg 'email_invalid')
    }
    while ($true) {
        $Script:AdminPassword = Ask-Secret (Msg 'q_admin_pw')
        if ($Script:AdminPassword.Length -lt 8) { Warn (Msg 'pw_short'); continue }
        $again = Ask-Secret (Msg 'q_admin_pw2')
        if ($again -ceq $Script:AdminPassword) { break }
        Warn (Msg 'pw_mismatch')
    }
}

function Wait-DockerDesktop {
    if (Test-DockerReady) { return }
    if (-not (Test-Path $DockerDesktopExe)) { Stop-WithError (Msg 'docker_required') }
    Info (Msg 'docker_starting' 5)
    if ($Script:IsDryRun) { return }
    Start-Process -FilePath $DockerDesktopExe
    for ($waited = 0; $waited -lt 300; $waited += 5) {
        Start-Sleep -Seconds 5
        if (Test-DockerReady) { Ok (Msg 'docker_installed'); return }
    }
    Stop-WithError (Msg 'docker_start_timeout')
}

function Install-Docker {
    if (Test-DockerReady) { Ok (Msg 'docker_ok' (Capture docker --version)); return }
    if (Test-Command docker) {
        Warn (Msg 'docker_stopped')
        Wait-DockerDesktop
        return
    }
    if (-not (Test-Command winget)) { Stop-WithError (Msg 'winget_missing') }
    $needsRestart = $false
    if (-not (Test-Wsl)) {
        Warn (Msg 'wsl_missing')
        Confirm-OrStop (Msg 'wsl_install_q')
        if (-not (Run wsl.exe --install --no-distribution)) { Stop-WithError (Msg 'wsl_missing') }
        $needsRestart = $true
    }
    Confirm-OrStop (Msg 'docker_install_q')
    if (-not (Run winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements)) {
        Stop-WithError (Msg 'docker_required')
    }
    if ($needsRestart -or -not (Test-Command docker)) {
        $Script:Conf.Pending = 'restart'
        Save-Conf
        Warn (Msg 'reboot_needed')
        exit 0
    }
    Wait-DockerDesktop
}

function Install-GpuSupport {
    if ($Script:Conf.UseGpu -ne 'yes') { Info (Msg 'gpu_skip'); return }
    # Docker Desktop brings GPU support through WSL 2; the NVIDIA Windows driver provides it.
    Info (Msg 'gpu_test')
    if (Run docker run --rm --gpus all $GpuTestImage nvidia-smi -L) { Ok (Msg 'gpu_test_ok') } else { Stop-WithError (Msg 'gpu_test_fail') }
}

# Start-AppContainer -LocalOnly: published on 127.0.0.1 while the admin is created.
function Start-AppContainer([switch]$LocalOnly) {
    $publish = "$($Script:Conf.Port):8080"
    if ($LocalOnly) { $publish = "127.0.0.1:$publish" }
    $arguments = @('run', '-d', '--name', $Container, '--restart', 'unless-stopped', '-p', $publish,
        '--add-host', 'host.docker.internal:host-gateway', '-v', "${Volume}:/app/backend/data",
        '--env-file', $EnvFile, '--label', 'app=my-local-ia')
    if ($Script:Conf.UseGpu -eq 'yes') { $arguments += @('--gpus', 'all') }
    if ($Script:Conf.ModelsDir -and (Test-Path $Script:Conf.ModelsDir)) { $arguments += @('-v', "$($Script:Conf.ModelsDir):/ollama-models:ro") }
    $arguments += $Script:Conf.Image
    return (Run docker @arguments)
}

function Show-ContainerLog {
    $ErrorActionPreference = 'Continue'
    & docker logs --tail 40 $Container 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray; Write-Log "$_" }
}

function Wait-Health {
    Info (Msg 'waiting' ([int]($HealthTimeout / 60)))
    if ($Script:IsDryRun) { return $true }
    for ($waited = 0; $waited -lt $HealthTimeout; $waited += 5) {
        if ((Get-HttpStatus "http://127.0.0.1:$($Script:Conf.Port)/health" 5) -eq 200) {
            Ok (Msg 'health_ok')
            return $true
        }
        if (-not (Test-ContainerRunning $Container)) {
            Fail (Msg 'container_died')
            Show-ContainerLog
            return $false
        }
        Start-Sleep -Seconds 5
        if ($waited -gt 0 -and $waited % 30 -eq 0) { Info (Msg 'waiting_progress' $waited) }
    }
    Fail (Msg 'health_timeout')
    Show-ContainerLog
    return $false
}

function Test-Onboarding {
    if ($Script:IsDryRun) { return $true }
    try { return [bool](Invoke-RestMethod -Uri "http://127.0.0.1:$($Script:Conf.Port)/api/config" -TimeoutSec 10).onboarding } catch { return $false }
}

function New-Admin {
    if ($Script:IsDryRun) {
        Say "    > POST http://127.0.0.1:$($Script:Conf.Port)/api/v1/auths/signup" 'DarkGray'
        Ok (Msg 'admin_created' $Script:AdminEmail)
        return
    }
    $body = @{ name = $Script:AdminName; email = $Script:AdminEmail; password = $Script:AdminPassword } | ConvertTo-Json
    try {
        $response = Invoke-RestMethod -Method Post -Uri "http://127.0.0.1:$($Script:Conf.Port)/api/v1/auths/signup" `
            -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($body)) -TimeoutSec 30
    } catch {
        Stop-WithError (Msg 'admin_failed' $_.Exception.Message)
    } finally {
        $body = $null
    }
    if ($response.role -ne 'admin') { Stop-WithError (Msg 'admin_failed' ($response | ConvertTo-Json -Compress)) }
    $Script:AdminToken = $response.token
    Ok (Msg 'admin_created' $Script:AdminEmail)
}

function Test-OllamaFromContainer {
    $out = Capture docker exec $Container curl -s --max-time 5 "$($Script:Conf.OllamaUrl)/api/version"
    return ($out -match 'version')
}

# Ollama on Windows only listens on 127.0.0.1 by default; the container needs it on all interfaces.
function Fix-OllamaHost {
    if ($Script:IsDryRun -or (Test-OllamaFromContainer)) { return }
    Warn (Msg 'ollama_container_fail')
    if (-not (Confirm (Msg 'ollama_host_q'))) { return }
    [Environment]::SetEnvironmentVariable('OLLAMA_HOST', '0.0.0.0:11434', 'User')
    Get-Process -Name 'ollama*' -ErrorAction SilentlyContinue | Stop-Process -Force
    if (Test-Path $OllamaAppExe) { Start-Process -FilePath $OllamaAppExe }
    Start-Sleep -Seconds 8
    if (Test-OllamaFromContainer) { Ok (Msg 'ollama_host_done') } else { Warn (Msg 'test_ollama_fail' $Script:Conf.OllamaUrl) }
}

function Open-Firewall {
    if ($Script:AccessMode -eq 'public') { Warn (Msg 'fw_public_skip'); return }
    if ($Script:AccessMode -ne 'lan') { Warn (Msg 'net_unknown'); return }
    if (-not (Confirm (Msg 'fw_windows_q' $Script:Conf.Port))) { return }
    Say "    > New-NetFirewallRule -DisplayName 'my-local-ia (TCP $($Script:Conf.Port))' -LocalPort $($Script:Conf.Port) -RemoteAddress LocalSubnet -Profile Private,Domain" 'DarkGray'
    if (-not $Script:IsDryRun) {
        Remove-NetFirewallRule -Group 'my-local-ia' -ErrorAction SilentlyContinue
        New-NetFirewallRule -DisplayName "my-local-ia (TCP $($Script:Conf.Port))" -Group 'my-local-ia' -Direction Inbound `
            -Protocol TCP -LocalPort $Script:Conf.Port -Action Allow -Profile Private, Domain -RemoteAddress LocalSubnet | Out-Null
    }
    Ok (Msg 'fw_done')
    if ($Script:NetCategory -eq 'Public') { Warn (Msg 'fw_public_profile') }
}

############################################
# Tests
############################################

function Add-Problem([string]$Text) {
    Fail $Text
    $Script:Problems++
}

function Run-Tests {
    if ($Script:IsDryRun) { Info '(dry-run)'; return }
    if (-not (Test-ContainerRunning $Container)) { Add-Problem (Msg 'test_container_fail'); return }
    Ok (Msg 'test_container' $Container (Capture docker inspect -f '{{.Config.Image}}' $Container))
    $port = [int]$Script:Conf.Port
    if ((Get-HttpStatus "http://127.0.0.1:$port/health") -eq 200) { Ok (Msg 'test_health' $port) } else { Add-Problem (Msg 'test_health_fail' $port) }
    $listen = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($listen | Where-Object { $_.LocalAddress -in @('0.0.0.0', '::') }) { Ok (Msg 'test_listen' $port) } else { Info (Msg 'test_listen_local' $port) }
    if ($Script:Conf.UseGpu -eq 'yes') {
        $gpu = Capture docker exec $Container nvidia-smi --query-gpu=name --format=csv,noheader
        if ($Script:LastExit -eq 0 -and $gpu) { Ok (Msg 'test_gpu' (($gpu -split "`n")[0])) } else { Add-Problem (Msg 'test_gpu_fail') }
    }
    if (Test-OllamaFromContainer) {
        Ok (Msg 'test_ollama')
        $models = Capture docker exec $Container curl -s --max-time 10 "$($Script:Conf.OllamaUrl)/api/tags"
        Info (Msg 'test_models' ([regex]::Matches($models, '"model":')).Count)
    } else {
        Add-Problem (Msg 'test_ollama_fail' $Script:Conf.OllamaUrl)
    }
    if ($Script:Conf.ImageKind -eq 'custom' -and $Script:AdminToken) {
        try {
            $hw = Invoke-RestMethod -Uri "http://127.0.0.1:$port/api/v1/my-local-ia/hardware" -Headers @{ Authorization = "Bearer $($Script:AdminToken)" } -TimeoutSec 15
            Info (Msg 'test_hw' "VRAM $($hw.vram_gb) GB, RAM $($hw.ram_total_gb) GB")
        } catch { }
    }
}

############################################
# Backups
############################################

function Get-HelperImage {
    $null = Capture docker image inspect $Script:Conf.Image
    if ($Script:Conf.Image -and $Script:LastExit -eq 0) { return $Script:Conf.Image }
    return $HelperImage
}

function Backup-Data {
    $name = "my-local-ia-data-$(Get-Date -Format 'yyyyMMdd-HHmmss').tar.gz"
    if (-not $Script:IsDryRun) { New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null }
    $wasRunning = Test-ContainerRunning $Container
    if ($wasRunning) {
        Info (Msg 'backup_stop_note')
        $null = Run docker stop $Container
    }
    $null = Run docker run --rm --entrypoint tar -v "${Volume}:/data:ro" -v "${BackupDir}:/backup" (Get-HelperImage) czf "/backup/$name" -C /data .
    if ($wasRunning) { $null = Run docker start $Container }
    $file = Join-Path $BackupDir $name
    $size = '?'
    if (Test-Path $file) { $size = '{0:N1} MB' -f ((Get-Item $file).Length / 1MB) }
    Ok (Msg 'backup_done' $file $size)
    $old = Get-ChildItem $BackupDir -Filter 'my-local-ia-data-*.tar.gz' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -Skip $KeepBackups
    if ($old) {
        $old | ForEach-Object { Say "    > Remove-Item $($_.FullName)" 'DarkGray'; if (-not $Script:IsDryRun) { Remove-Item $_.FullName } }
        Info (Msg 'backup_cleanup' $KeepBackups)
    }
}

function Restore-Data {
    $files = @(Get-ChildItem $BackupDir -Filter 'my-local-ia-data-*.tar.gz' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($files.Count -eq 0) { Warn (Msg 'backup_none' $BackupDir); return }
    Info (Msg 'backup_list')
    for ($i = 0; $i -lt $files.Count; $i++) { Info ("  {0}) {1}  {2:N1} MB" -f ($i + 1), $files[$i].Name, ($files[$i].Length / 1MB)) }
    while ($true) {
        $n = 0
        if ([int]::TryParse((Ask (Msg 'q_backup_pick') '1'), [ref]$n) -and $n -ge 1 -and $n -le $files.Count) { break }
        Warn (Msg 'invalid_option')
    }
    $file = $files[$n - 1].Name
    Warn (Msg 'restore_warn')
    Confirm-OrStop (Msg 'continue_q') 'N'
    if (Test-ContainerRunning $Container) { $null = Run docker stop $Container }
    $null = Run docker run --rm --entrypoint sh -v "${Volume}:/data" -v "${BackupDir}:/backup:ro" (Get-HelperImage) -c "find /data -mindepth 1 -delete && tar xzf '/backup/$file' -C /data"
    if (Test-ContainerExists $Container) {
        $null = Run docker start $Container
        $null = Wait-Health
    }
    Ok (Msg 'restore_done')
}

############################################
# Menu actions
############################################

function Require-Installed {
    if (-not (Test-ContainerExists $Container) -and -not $Script:IsDryRun) {
        Warn (Msg 'not_installed')
        exit 1
    }
}

# Builds the image from the GitHub repository with the same Dockerfile the GitHub workflow uses.
# The source comes as a zip (not git clone) so its scripts keep LF line endings inside the image.
function Build-LocalImage {
    $free = [math]::Floor((Get-PSDrive -Name C).Free / 1GB)
    if ($free -lt $MinBuildFreeGb) {
        Warn (Msg 'build_disk_low' $free $MinBuildFreeGb)
        Confirm-OrStop (Msg 'continue_q') 'N'
    }
    Confirm-OrStop (Msg 'build_q' $Script:Conf.Image $MinBuildFreeGb)

    $repo = $Script:Conf.RepoUrl
    $branch = $Script:Conf.RepoBranch
    $zip = Join-Path $ConfDir 'source.zip'
    if (-not (Run curl.exe -fL --retry 3 -o $zip "$repo/archive/refs/heads/$branch.zip")) { Stop-WithError (Msg 'build_fail') }
    Say "    > $SourceDir" 'DarkGray'
    if (-not $Script:IsDryRun) {
        if (Test-Path $SourceDir) { Remove-Item -Recurse -Force $SourceDir }
        New-Item -ItemType Directory -Force -Path $SourceDir | Out-Null
    }
    if (-not (Run tar.exe -xf $zip -C $SourceDir)) { Stop-WithError (Msg 'build_fail') }
    $context = $SourceDir
    if (-not $Script:IsDryRun) {
        Remove-Item -Force $zip
        $context = (Get-ChildItem -Directory $SourceDir | Select-Object -First 1).FullName
    }

    $sha = 'local'
    $api = $repo -replace '^https://github\.com/', 'https://api.github.com/repos/'
    try {
        $commit = (Capture curl.exe -s --max-time 15 "$api/commits/$branch") | ConvertFrom-Json
        if ($commit.sha) { $sha = $commit.sha.Substring(0, 7) }
    } catch { }
    Info (Msg 'build_source' $repo $branch $sha)

    # The frontend build needs a bigger Node heap than the default: half of Docker's memory, 4-12 GB.
    $heap = 4096
    $memory = Capture docker info --format '{{.MemTotal}}'
    if ($memory -match '^\d+$') { $heap = [math]::Min(12288, [math]::Max(4096, [math]::Floor([double]$memory / 1MB / 2))) }
    $cuda = 'false'
    $variant = 'main'
    if ($Script:Conf.UseGpu -eq 'yes') { $cuda = 'true'; $variant = 'cuda' }
    $dockerfile = Join-Path $ConfDir 'Dockerfile.build'
    Say "    > $dockerfile (NODE_OPTIONS=--max-old-space-size=$heap)" 'DarkGray'
    if (-not $Script:IsDryRun) {
        $lines = foreach ($line in [IO.File]::ReadAllLines((Join-Path $context 'Dockerfile'))) {
            $line
            if ($line -match '^FROM --platform=\$BUILDPLATFORM node:') { "ENV NODE_OPTIONS=`"--max-old-space-size=$heap`"" }
        }
        [IO.File]::WriteAllText($dockerfile, (($lines -join "`n") + "`n"))
    }

    if (-not (Run docker build --progress=plain -f $dockerfile --build-arg "USE_CUDA=$cuda" --build-arg "BUILD_HASH=$sha" `
                --build-arg 'BUILD_CHANNEL=local' -t $Script:Conf.Image -t "${LocalImageName}:git-$sha-$variant" $context)) {
        Stop-WithError (Msg 'build_fail')
    }
    Ok (Msg 'build_ok' $Script:Conf.Image)
}

# Frees the build cache and my-local-ia images that no container uses.
function Clear-LocalBuilds {
    $keep = Capture docker image inspect -f '{{.Id}}' $Script:Conf.Image
    $null = Run docker builder prune -f
    foreach ($row in ((Capture docker images --format '{{.Repository}}:{{.Tag}} {{.ID}}' $LocalImageName) -split "`n")) {
        $ref, $id = $row -split ' '
        if (-not $id -or ($keep -and $keep.Contains($id))) { continue }
        $null = Run docker rmi $ref
    }
}

# Get-Image: downloads or builds the chosen image.
function Get-Image {
    if ($Script:Conf.ImageKind -eq 'local') { Build-LocalImage; return }
    Pull-Image
}

function Pull-Image {
    if (-not (Run docker pull $Script:Conf.Image)) {
        if ($Script:Conf.ImageKind -eq 'custom') { Stop-WithError (Msg 'pull_fail_custom' $Script:Conf.Image) }
        Stop-WithError (Msg 'pull_fail')
    }
    Ok (Msg 'pull_ok')
}

function Action-Install {
    $Script:StepTotal = 11
    Step (Msg 'step_checks')
    Check-Os
    Check-Resources
    $null = Check-Internet
    $null = Check-Gpu
    Check-Ollama
    $null = Check-Docker
    Check-Network

    if (Test-ContainerExists $Container) {
        Warn (Msg 'existing_install')
        Info (Msg 'existing_what')
        Confirm-OrStop (Msg 'reinstall_q') 'N'
    }

    Step (Msg 'step_questions')
    if ($Script:Conf.Pending -eq 'restart' -and $Script:Conf.Image) {
        # Back after the restart: the answers were saved before it.
        $Script:Conf.Pending = ''
        Info (Msg 'resuming')
    } else {
        Ask-Questions
    }
    Write-Host ''
    Info (Msg 'summary_title')
    Info ('  ' + (Msg 'summary_image' $Script:Conf.Image))
    $shownIp = $Script:LanIp
    if (-not $shownIp) { $shownIp = '127.0.0.1' }
    Info ('  ' + (Msg 'summary_port' $shownIp $Script:Conf.Port))
    if ($Script:Conf.UseGpu -eq 'yes') { Info ('  ' + (Msg 'summary_gpu' $Script:GpuList[0].Trim())) } else { Info ('  ' + (Msg 'summary_gpu' (Msg 'gpu_off'))) }
    Info ('  ' + (Msg 'summary_ollama' $Script:Conf.OllamaUrl))
    Confirm-OrStop (Msg 'continue_q')
    Save-Conf

    Step (Msg 'step_docker')
    Install-Docker

    Step (Msg 'step_gpu')
    Install-GpuSupport

    Step (Msg 'step_config')
    Write-EnvFile

    if ($Script:Conf.ImageKind -eq 'local') {
        Step (Msg 'step_build')
    } else {
        Step (Msg 'step_pull')
        Confirm-OrStop (Msg 'pull_q' $Script:Conf.Image)
    }
    Get-Image

    Step (Msg 'step_start')
    Confirm-OrStop (Msg 'start_q')
    if (Test-ContainerExists $Container) { $null = Run docker rm -f $Container }
    $null = Start-AppContainer -LocalOnly
    if (-not (Wait-Health)) { Stop-WithError (Msg 'health_timeout') }
    Fix-OllamaHost

    Step (Msg 'step_admin')
    if (Test-Onboarding) {
        Ask-Admin
        New-Admin
        $Script:AdminPassword = $null
    } else {
        Ok (Msg 'admin_exists')
    }

    Step (Msg 'step_open')
    Confirm-OrStop (Msg 'open_q')
    $null = Run docker rm -f $Container
    $null = Start-AppContainer
    if (-not (Wait-Health)) { Stop-WithError (Msg 'health_timeout') }
    Ok (Msg 'opened' $Script:Conf.Port)

    Step (Msg 'step_firewall')
    Open-Firewall

    Step (Msg 'step_tests')
    $Script:Problems = 0
    Run-Tests

    Write-Host ''
    Say (Msg 'done_title') 'Green'
    Info (Msg 'done_url' $shownIp $Script:Conf.Port)
    if ($Script:AdminEmail) { Info (Msg 'done_login' $Script:AdminEmail) }
    Info (Msg 'done_users')
    Info (Msg 'done_update')
    Info (Msg 'log_at' $LogFile)
}

function Action-Update {
    Require-Installed
    $Script:StepTotal = 4
    Step (Msg 'step_checks')
    $Script:ReadOnly = $true
    if (Check-Gpu) { $Script:Conf.UseGpu = 'yes' } elseif (-not $Script:Conf.UseGpu) { $Script:Conf.UseGpu = 'no' }
    $Script:ReadOnly = $false
    $current = Capture docker inspect -f '{{.Config.Image}}' $Container
    if (-not $current) { $current = $Script:Conf.Image }
    Info (Msg 'update_current' $current)

    Step (Msg 'step_questions')
    $choice = Choose (Msg 'q_update_version') @((Msg 'q_update_keep'), (Msg 'q_version_official'), (Msg 'q_version_custom'), (Msg 'q_version_local'))
    switch ($choice) {
        1 {
            $Script:Conf.Image = $current
            # A local image has no registry to pull from: "newest" means rebuilding it.
            if ($current -like "${LocalImageName}:*") { $Script:Conf.ImageKind = 'local'; Ask-Repo; $Script:Conf.Image = Local-Image }
        }
        2 { $Script:Conf.ImageKind = 'official'; $Script:Conf.Image = Official-Image }
        3 { $Script:Conf.ImageKind = 'custom'; Ask-GithubUser; $Script:Conf.Image = Custom-Image }
        4 { $Script:Conf.ImageKind = 'local'; Ask-Repo; $Script:Conf.Image = Local-Image }
    }
    Info (Msg 'summary_image' $Script:Conf.Image)
    Confirm-OrStop (Msg 'continue_q')

    if ($Script:Conf.ImageKind -eq 'local') { Step (Msg 'step_build') } else { Step (Msg 'step_pull') }
    Get-Image
    if (Confirm (Msg 'backup_q')) { Backup-Data }
    Save-Conf

    Step (Msg 'step_replace')
    Info (Msg 'update_swap')
    if (Test-ContainerExists $PreviousContainer) { $null = Run docker rm -f $PreviousContainer }
    $null = Run docker rename $Container $PreviousContainer
    $null = Run docker stop $PreviousContainer
    $null = Start-AppContainer
    if (Wait-Health) {
        $null = Run docker rm $PreviousContainer
        Ok (Msg 'update_ok' $Script:Conf.Image)
        $Script:Problems = 0
        Run-Tests
        if ($Script:Conf.ImageKind -eq 'local' -and (Confirm (Msg 'build_clean_q') 'N')) { Clear-LocalBuilds }
    } else {
        Warn (Msg 'update_rollback')
        $null = Run docker rm -f $Container
        $null = Run docker rename $PreviousContainer $Container
        $null = Run docker start $Container
        $null = Wait-Health
        Stop-WithError (Msg 'rollback_done')
    }
}

function Action-Verify {
    $Script:ReadOnly = $true
    $Script:StepTotal = 2
    $Script:Problems = 0
    Step (Msg 'step_checks')
    Check-Os
    Check-Resources
    if (-not (Check-Internet)) { $Script:Problems++ }
    $null = Check-Gpu
    Check-Ollama
    $null = Check-Docker
    Check-Network

    Step (Msg 'verify_title')
    if (Test-ContainerExists $Container) { Run-Tests } else { Add-Problem (Msg 'not_installed') }

    if (-not $Script:IsDryRun) {
        $report = Join-Path $LogDir "report-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
        $lines = @(
            "my-local-ia diagnostics - $(Get-Date -Format o)"
            "System: $((Get-CimInstance Win32_OperatingSystem).Caption)"
            "Settings: $($Script:Conf | ConvertTo-Json -Compress)"
            '--- nvidia-smi'; (Capture nvidia-smi)
            '--- wsl'; (Capture wsl.exe --status)
            '--- docker'; (Capture docker version)
            '--- container'; (Capture docker ps -a --filter "name=$Container")
            '--- container log (last 100 lines)'; (Capture docker logs --tail 100 $Container)
            '--- listening'; ((Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.LocalPort -in @([int]$Script:Conf.Port, 11434) } | Format-Table -AutoSize | Out-String))
        )
        $lines | Set-Content -Path $report -Encoding UTF8
        Info (Msg 'report_saved' $report)
    }
    Write-Host ''
    if ($Script:Problems -eq 0) { Ok (Msg 'verify_ok') } else { Warn (Msg 'verify_problems' $Script:Problems) }
}

function Action-ResetPassword {
    Require-Installed
    $email = Ask (Msg 'q_reset_email')
    while ($true) {
        $password = Ask-Secret (Msg 'q_admin_pw')
        if ($password.Length -lt 8) { Warn (Msg 'pw_short'); continue }
        if ((Ask-Secret (Msg 'q_admin_pw2')) -ceq $password) { break }
        Warn (Msg 'pw_mismatch')
    }
    if ($Script:IsDryRun) { Say "    > docker exec -i $Container python3  (new password sent through stdin)" 'DarkGray'; return }
    # bcrypt hashes are accepted by Open WebUI next to its default argon2 ones.
    # The Python code is passed base64-encoded so Windows PowerShell cannot mangle its quotes.
    $python = @'
import json, os, sqlite3, sys
import bcrypt
db = '/app/backend/data/webui.db'
if not os.path.exists(db):
    print('nodb'); sys.exit()
d = json.load(sys.stdin)
h = bcrypt.hashpw(d['p'].encode(), bcrypt.gensalt()).decode()
c = sqlite3.connect(db)
n = c.execute('UPDATE auth SET password = ? WHERE lower(email) = lower(?)', (h, d['e'])).rowcount
c.commit()
print(n)
'@
    $encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($python))
    $json = @{ e = $email; p = $password } | ConvertTo-Json -Compress
    $ErrorActionPreference = 'Continue'
    $result = ($json | & docker exec -i $Container python3 -c "import base64;exec(base64.b64decode('$encoded'))" 2>&1) -join "`n"
    $json = $null
    $password = $null
    switch ($result.Trim()) {
        'nodb' { Warn (Msg 'reset_unsupported') }
        '0' { Warn (Msg 'reset_notfound' $email) }
        '1' { Ok (Msg 'reset_done' $email) }
        default { Stop-WithError $result }
    }
}

function Action-Uninstall {
    Warn (Msg 'uninstall_warn')
    Confirm-OrStop (Msg 'uninstall_q') 'N'
    if (Test-ContainerExists $Container) { $null = Run docker rm -f $Container }
    if (Test-ContainerExists $PreviousContainer) { $null = Run docker rm -f $PreviousContainer }
    Say "    > Remove-NetFirewallRule -Group my-local-ia" 'DarkGray'
    if (-not $Script:IsDryRun) { Remove-NetFirewallRule -Group 'my-local-ia' -ErrorAction SilentlyContinue }
    if (Confirm (Msg 'uninstall_data_q') 'N') {
        if ((Ask (Msg 'uninstall_data_confirm')) -ceq 'DELETE') {
            if (Confirm (Msg 'uninstall_backup_q')) { Backup-Data }
            $null = Run docker volume rm $Volume
        } else {
            Info (Msg 'data_kept' $Volume)
        }
    } else {
        Info (Msg 'data_kept' $Volume)
    }
    if ((Test-Path $EnvFile) -and (Confirm (Msg 'uninstall_conf_q' $ConfDir) 'N')) {
        # Logs and backups stay; only the settings and the secret key go.
        Say "    > Remove-Item $ConfFile, $EnvFile" 'DarkGray'
        if (-not $Script:IsDryRun) { Remove-Item $ConfFile, $EnvFile -ErrorAction SilentlyContinue }
    }
    Ok (Msg 'uninstall_done')
}

############################################
# Main
############################################

function Detect-Language {
    switch -Wildcard ((Get-Culture).Name) { 'pt*' { 'pt' } 'es*' { 'es' } default { 'en' } }
}

try {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
} catch { }
Load-Conf
if ($Lang) { $Script:LangCode = $Lang } elseif ($Script:Conf.LangCode) { $Script:LangCode = $Script:Conf.LangCode }

if (-not (Test-Admin)) {
    if (-not $Script:LangCode) { $Script:LangCode = Detect-Language }
    Fail (Msg 'need_root' $PSCommandPath)
    exit 1
}
Write-Log ''
Write-Log "===== $(Get-Date -Format o) $PSCommandPath ====="

if (-not $Script:LangCode) {
    $detected = Detect-Language
    $Script:LangCode = $detected
    Write-Host (Msg 'choose_lang')
    Write-Host '  1) English   2) Português   3) Español'
    $default = @{ en = '1'; pt = '2'; es = '3' }[$detected]
    switch (Read-Host "  [$default]") {
        '1' { $Script:LangCode = 'en' }
        '2' { $Script:LangCode = 'pt' }
        '3' { $Script:LangCode = 'es' }
    }
}
$Script:Conf.LangCode = $Script:LangCode

Write-Host ''
Say (Msg 'title') 'White'
if ($Script:IsDryRun) { Warn (Msg 'dry_run_banner') }
Info (Msg 'log_at' $LogFile)
Write-Host ''

try {
    while ($true) {
        Info (Msg 'menu_title')
        Info "  1) $(Msg 'menu_install')"
        Info "  2) $(Msg 'menu_update')"
        Info "  3) $(Msg 'menu_verify')"
        Info "  4) $(Msg 'menu_backup')"
        Info "  5) $(Msg 'menu_restore')"
        Info "  6) $(Msg 'menu_reset_pw')"
        Info "  7) $(Msg 'menu_uninstall')"
        Info "  0) $(Msg 'menu_exit')"
        $option = Read-Host "  $(Msg 'menu_prompt')"
        Write-Log "  menu -> $option"
        $handled = $true
        switch ($option) {
            '1' { Action-Install }
            '2' { Action-Update }
            '3' { Action-Verify }
            '4' { Require-Installed; Backup-Data }
            '5' { Require-Installed; Restore-Data }
            '6' { Action-ResetPassword }
            '7' { Action-Uninstall }
            '0' { exit 0 }
            default { Warn (Msg 'invalid_option'); $handled = $false }
        }
        if ($handled) { break }
    }
} catch {
    Fail (Msg 'error_at' "$($_.InvocationInfo.ScriptLineNumber): $($_.Exception.Message)")
    Info (Msg 'see_log' $LogFile)
    Info (Msg 'see_docs' (Docs-Lang))
    exit 1
}
