# my-local-ia — Guia de solução de problemas

[English](../en/TROUBLESHOOTING.md) · [Español](../es/TROUBLESHOOTING.md) · Instalação: [INSTALL.md](INSTALL.md)

Cada problema abaixo traz o **sintoma** (o que você vê), a **causa** e a **solução**. Os comandos marcados como _Linux_ rodam no terminal do servidor (com `sudo` quando necessário); os marcados como _Windows_ rodam no PowerShell aberto como administrador.

---

## Sumário

- [0. Comece aqui: junte as informações](#0-comece-aqui-junte-as-informações)
- [1. Instalador](#1-instalador)
- [2. Placa de vídeo (NVIDIA)](#2-placa-de-vídeo-nvidia)
- [3. Docker](#3-docker)
- [4. Inicialização do my-local-ia](#4-inicialização-do-my-local-ia)
- [5. Ollama e modelos](#5-ollama-e-modelos)
- [6. Acesso de outros computadores](#6-acesso-de-outros-computadores)
- [7. Contas e senhas](#7-contas-e-senhas)
- [8. Atualizações, backups e mudança de servidor](#8-atualizações-backups-e-mudança-de-servidor)
- [9. A imagem do my-local-ia](#9-a-imagem-do-my-local-ia)
- [10. Espaço em disco](#10-espaço-em-disco)
- [11. Pedindo ajuda](#11-pedindo-ajuda)

---

## 0. Comece aqui: junte as informações

1. **Rode o instalador e escolha 3) Verificar.** Ele confere tudo sem mudar nada, mostra ✔ / ! / ✖ para cada item e salva um relatório:
   - Linux: `/var/log/my-local-ia-report-<data>.txt`
   - Windows: `C:\ProgramData\my-local-ia\logs\report-<data>.txt`
2. **Leia o log do instalador**, que tem cada comando e a saída dele:
   - Linux: `/var/log/my-local-ia-install.log`
   - Windows: `C:\ProgramData\my-local-ia\logs\install.log`
3. **Leia o log do my-local-ia:**

   ```bash
   docker logs --tail 100 my-local-ia
   ```

A maioria dos problemas aparece na primeira linha marcada com ✖ no resultado do Verificar. Procure essa mensagem abaixo.

---

## 1. Instalador

### "Rode este script como root" (Linux) / "Rode este script no PowerShell aberto como Administrador" (Windows)

- **Causa:** o instalador muda configurações do sistema e precisa de permissão de administrador.
- **Solução:**
  - Linux: `sudo bash /tmp/install-my-local-ia.sh`
  - Windows: menu Iniciar → **PowerShell** → botão direito → **Executar como administrador**, e rode o comando de novo.

### Linux: `$'\r': command not found` ou `set: pipefail: invalid option name`

- **Causa:** o arquivo foi convertido para quebras de linha do Windows (CRLF) no caminho até o servidor, por exemplo ao ser aberto e salvo num editor do Windows ou copiado em modo "texto".
- **Solução:** as versões atuais do instalador corrigem isso sozinhas e reiniciam. Com uma cópia antiga, corrija o arquivo e rode de novo:

  ```bash
  sudo sed -i 's/\r$//' /tmp/install-my-local-ia.sh
  sudo bash /tmp/install-my-local-ia.sh
  ```

  Para evitar, copie o arquivo com `scp`, ou configure o WinSCP para transferir em modo **binário**.

### Windows: "a execução de scripts foi desabilitada neste sistema"

- **Causa:** a política de execução do Windows bloqueia scripts.
- **Solução:** rode com a política liberada só para este script (nada muda de forma permanente):

  ```powershell
  powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1
  ```

  Se ainda recusar porque o arquivo veio da internet: `Unblock-File C:\temp\install-my-local-ia.ps1`.

### Windows: os acentos aparecem quebrados (Ã©, Ã§…)

- **Causa:** o arquivo foi salvo de novo por um editor em outra codificação. O script é salvo como UTF-8 com BOM, que o Windows PowerShell exige.
- **Solução:** copie o arquivo original de novo. Se for editar, salve como **UTF-8 com BOM** (no Bloco de Notas: _Salvar como → Codificação: UTF-8 com BOM_).

### "Esta distribuição não é suportada pela instalação automática do Docker"

- **Causa:** o instalador só sabe instalar o Docker no Ubuntu/Debian (e derivados) e no Fedora/RHEL/Rocky/Alma/CentOS Stream.
- **Solução:** instale o Docker manualmente seguindo <https://docs.docker.com/engine/install/>, confira se `docker info` funciona e rode o instalador de novo: ele pula a etapa do Docker.

### "Não foi possível acessar o ghcr.io (repositório de imagens)"

- **Causa:** sem internet, falha de DNS, ou um proxy/firewall bloqueando o `ghcr.io`.
- **Solução:**
  1. Teste: `curl -I https://ghcr.io/v2/` (a resposta `401` é normal e significa que funciona).
  2. Se a rede usa **proxy**, o Docker também precisa dele. _Linux:_ crie `/etc/systemd/system/docker.service.d/http-proxy.conf`:

     ```ini
     [Service]
     Environment="HTTP_PROXY=http://proxy.exemplo:3128"
     Environment="HTTPS_PROXY=http://proxy.exemplo:3128"
     Environment="NO_PROXY=localhost,127.0.0.1"
     ```

     e depois `sudo systemctl daemon-reload && sudo systemctl restart docker`. _Windows:_ Docker Desktop → Settings → Resources → Proxies.

### A instalação parou quando a conexão SSH caiu

- **Causa:** fechar a sessão SSH encerra os programas iniciados nela.
- **Solução:** conecte de novo e rode o instalador outra vez; ele reaproveita as respostas já dadas e pula o que já foi feito. Na próxima vez, use o `tmux` (veja o guia de instalação, seção 4.2).

### "A porta 4000 já está em uso neste servidor"

- **Causa:** outro programa usa a porta.
- **Solução:** veja qual é e escolha outra porta, ou pare esse programa:
  - Linux: `sudo ss -ltnp | grep ':4000'`
  - Windows: `Get-NetTCPConnection -LocalPort 4000 -State Listen | Select-Object OwningProcess; Get-Process -Id <número>`

---

## 2. Placa de vídeo (NVIDIA)

### "Foi encontrada uma placa NVIDIA, mas o driver não está instalado (falta o nvidia-smi)"

- **Causa:** falta o driver NVIDIA. Sem ele, nem o Ollama nem o my-local-ia conseguem usar a placa.
- **Solução (Linux):**
  - Ubuntu: `sudo ubuntu-drivers install` e reinicie o servidor.
  - Debian, Fedora, RHEL e outras: instale o driver pelos repositórios da distribuição ou pela NVIDIA (<https://www.nvidia.com/Download/index.aspx>) e reinicie.
  - Confira com `nvidia-smi`.
- **Solução (Windows):** instale o driver mais recente em <https://www.nvidia.com/Download/index.aspx> e reinicie.
- **Máquina virtual:** a placa precisa ser repassada para a VM (_GPU passthrough_) no hipervisor (Proxmox, VMware ESXi, Hyper-V DDA…). Se `lspci | grep -i nvidia` (Linux) não mostra nada, a VM ainda não enxerga a placa.

### "A placa de vídeo NÃO aparece dentro dos contêineres"

- **Sintoma:** o contêiner de teste da etapa 4 falha, ou o Verificar mostra "A placa de vídeo não aparece dentro do contêiner".
- **Causa (Linux):** o NVIDIA Container Toolkit não está instalado ou não está configurado no Docker.
- **Solução (Linux):**

  ```bash
  nvidia-ctk --version                              # está instalado?
  sudo nvidia-ctk runtime configure --runtime=docker
  sudo systemctl restart docker
  docker run --rm --gpus all ubuntu:24.04 nvidia-smi -L   # precisa listar a placa
  ```

  Se o `nvidia-ctk` não existir, rode o instalador de novo (a etapa 4 instala) ou siga <https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html>.

- **Causa (Windows):** driver NVIDIA antigo, WSL antigo, ou o Docker Desktop sem usar o motor WSL 2.
- **Solução (Windows):** atualize o driver NVIDIA; rode `wsl --update`; no Docker Desktop → Settings → General, ative **Use the WSL 2 based engine**; reinicie o Docker Desktop.

### Erro `could not select device driver "" with capabilities: [[gpu]]`

- **Causa:** o Docker não conhece o runtime NVIDIA (o mesmo caso acima).
- **Solução:** os comandos `nvidia-ctk runtime configure` do item anterior.

### As respostas estão muito lentas

- **Causa:** o modelo não cabe na memória da placa (VRAM), então parte dele roda na RAM do sistema, que é bem mais lenta; ou o Ollama não está usando a placa.
- **Solução:**
  1. Enquanto uma conversa está respondendo, rode `ollama ps`. A coluna **PROCESSOR** mostra `100% GPU` quando tudo está na placa. Algo como `40%/60% CPU/GPU` significa que o modelo é maior que a VRAM: escolha um modelo menor ou uma versão mais comprimida (Q4).
  2. Rode `nvidia-smi` durante uma resposta: o uso da GPU precisa subir.
  3. Se o `ollama ps` mostra `100% CPU` para um modelo pequeno, o próprio Ollama não está enxergando a placa: reinicie-o (`sudo systemctl restart ollama`) e veja o log dele (`journalctl -u ollama --since "10 min ago"`).

---

## 3. Docker

### A instalação do Docker falha (Linux)

- **Causa:** pacotes da distribuição em conflito (`docker.io`, `containerd`, `podman-docker`) ou repositórios inacessíveis.
- **Solução:**
  - Ubuntu/Debian: `sudo apt remove -y docker.io docker-doc docker-compose podman-docker containerd runc` e rode o instalador de novo.
  - Fedora/RHEL: `sudo dnf remove -y podman-docker` e rode o instalador de novo.
  - O erro exato está em `/var/log/my-local-ia-install.log`.

### "O Docker está instalado, mas parado" (Linux)

- **Solução:**

  ```bash
  sudo systemctl enable --now docker
  sudo systemctl status docker            # precisa mostrar "active (running)"
  sudo journalctl -u docker --since "10 min ago"   # o motivo, se falhar
  ```

### Windows: o Docker Desktop não inicia

- **Causas e soluções:**
  - **Virtualização desativada:** ative _Intel VT-x_ / _AMD-V (SVM)_ na BIOS/UEFI. Gerenciador de Tarefas → Desempenho → CPU precisa mostrar _Virtualização: Habilitado_.
  - **O Windows é uma máquina virtual:** ative a virtualização aninhada no hipervisor. Hyper-V (no host, com a VM desligada): `Set-VMProcessor -VMName <nome> -ExposeVirtualizationExtensions $true`. VMware: _Expose hardware assisted virtualization to the guest OS_.
  - **WSL antigo:** `wsl --update` e reinicie.
  - **Windows Server:** não é suportado pelo Docker Desktop. Use Windows 10/11 ou um servidor Linux.

### Windows: "O winget não está disponível"

- **Solução:** instale o **Instalador de Aplicativo** pela Microsoft Store, ou instale o Docker Desktop manualmente em <https://www.docker.com/products/docker-desktop/>, e rode o instalador de novo.

---

## 4. Inicialização do my-local-ia

### "O my-local-ia não respondeu a tempo"

- **Causas:**
  - A primeira inicialização baixa arquivos extras (para a busca em documentos) e pode levar vários minutos numa conexão lenta.
  - Falta de RAM.
  - Um erro no contêiner.
- **Solução:**
  1. Veja o log: `docker logs --tail 100 my-local-ia`. Enquanto aparecerem mensagens de download ou inicialização, espere e confira de novo com o Verificar.
  2. Confira a RAM: `free -h` (Linux). Com menos de 2 GB disponíveis, feche outros programas ou aumente a RAM.
  3. Se o log mostrar um erro (`Error`, `Traceback`), mande o log (veja a [seção 11](#11-pedindo-ajuda)).

### "O contêiner parou durante a inicialização" / o contêiner fica reiniciando

- **Solução:**
  1. `docker logs --tail 100 my-local-ia` mostra o motivo.
  2. Motivos comuns:
     - **Falta o arquivo de configuração:** o instalador foi interrompido antes da etapa 5. Rode **Instalar** de novo.
     - **Erro no banco de dados depois de uma atualização:** use **Restaurar** com o backup feito antes da atualização.
     - **Permissão negada na pasta de modelos do Ollama (Linux com SELinux):** o instalador já inicia o contêiner com `--security-opt label=disable` quando o SELinux está em modo enforcing. Se você criou o contêiner à mão, acrescente essa opção.

---

## 5. Ollama e modelos

### "O Ollama não está respondendo"

- **Linux:**

  ```bash
  sudo systemctl status ollama
  sudo systemctl restart ollama
  curl http://127.0.0.1:11434        # "Ollama is running"
  ```

- **Windows:** abra o **Ollama** pelo menu Iniciar (ele aparece ao lado do relógio) e teste `curl.exe http://127.0.0.1:11434`.

### "O my-local-ia não consegue falar com o Ollama"

- **Linux:** o contêiner usa a rede do servidor, então `http://127.0.0.1:11434` funciona sempre que o Ollama responde no servidor (item anterior). Se o Ollama está em **outro** computador:
  1. Nesse computador, faça o Ollama escutar na rede: `sudo systemctl edit ollama`, acrescente

     ```ini
     [Service]
     Environment="OLLAMA_HOST=0.0.0.0:11434"
     ```

     e `sudo systemctl restart ollama`.

  2. No my-local-ia, defina o endereço como `http://IP-DESSE-COMPUTADOR:11434` (pergunta do instalador, ou **Painel do admin → Configurações → Conexões**).
  3. Libere a porta 11434 no firewall desse computador **só** para o servidor do my-local-ia.

- **Windows:** aceite a oferta do instalador para definir o `OLLAMA_HOST`, ou faça à mão: _Configurações → Sistema → Sobre → Configurações avançadas do sistema → Variáveis de Ambiente_ → nova variável de usuário `OLLAMA_HOST` = `0.0.0.0:11434`; feche o Ollama (ícone ao lado do relógio → Quit) e abra de novo.
- Mais detalhes sobre as configurações do Ollama: <https://github.com/ollama/ollama/blob/main/docs/faq.md>

### A lista de modelos no my-local-ia está vazia

- **Solução:**
  1. `ollama list` no servidor precisa mostrar modelos. Se estiver vazio, baixe um, por exemplo `ollama pull llama3.2`.
  2. **Painel do admin → Configurações → Conexões:** a conexão do Ollama precisa estar ativada e com o endereço certo. Clique no ícone de verificar/atualizar ao lado dela.
  3. Recarregue a página (F5).

---

## 6. Acesso de outros computadores

### Funciona no servidor, mas não nos outros computadores

1. **No servidor**, teste: `curl http://127.0.0.1:4000/health` → precisa responder `{"status":true}`. Se não responder, o problema é o próprio my-local-ia (seção 4).
2. **Endereço:** use o IP do servidor mostrado no fim da instalação (`hostname -I` no Linux, `ipconfig` no Windows). Os dois computadores precisam estar na mesma rede.
3. **Firewall:**
   - Linux com ufw: `sudo ufw status` precisa mostrar `4000/tcp ALLOW <sua rede>`. Para acrescentar: `sudo ufw allow from 192.168.1.0/24 to any port 4000 proto tcp`.
   - Linux com firewalld: `sudo firewall-cmd --list-all`. Para acrescentar: `sudo firewall-cmd --permanent --add-rich-rule='rule family=ipv4 source address=192.168.1.0/24 port port=4000 protocol=tcp accept' && sudo firewall-cmd --reload`.
   - Windows: a regra "my-local-ia (TCP 4000)" precisa existir em _Firewall do Windows Defender → Configurações avançadas → Regras de Entrada_, e a rede precisa ser **Privada** (_Configurações → Rede e Internet_).
4. **Isolamento de rede:** redes Wi-Fi de visitantes e alguns roteadores ("isolamento de AP", "isolamento de clientes") bloqueiam o acesso entre dispositivos. Teste de um computador ligado por cabo no mesmo roteador.
5. **Servidor com IP público:** nesse caso o instalador não libera a porta. Veja _Publicar na internet_ no guia de instalação.

---

## 7. Contas e senhas

### Esqueci a senha do administrador

- Rode o instalador e escolha **6) Redefinir a senha de um usuário**: digite o e-mail e a senha nova. Funciona com o banco de dados padrão.

### Novos usuários não conseguem entrar

- **Causa:** novos cadastros ficam **pendentes**.
- **Solução:** **Painel do admin → Usuários** → mude a função da pessoa de _pending_ para _user_. Para mudar o padrão: **Painel do admin → Configurações → Geral → Função padrão do usuário**.

### O link de cadastro não aparece na tela de login

- **Causa:** depois que o primeiro administrador é criado, o cadastro pode ficar desativado.
- **Solução:** **Painel do admin → Configurações → Geral → Ativar novos cadastros**, ou crie as contas você mesmo em **Painel do admin → Usuários**.

### Todo mundo foi deslogado depois de reinstalar

- **Causa:** a chave secreta mudou (por exemplo, depois de apagar `/etc/my-local-ia` ou `C:\ProgramData\my-local-ia`).
- **Solução:** nada se perdeu; é só cada pessoa entrar de novo.

---

## 8. Atualizações, backups e mudança de servidor

### "A versão nova não iniciou. Voltando para a anterior…"

- **Causa:** a imagem nova não conseguiu iniciar. O instalador recolocou a versão anterior automaticamente.
- **Solução:**
  1. Confira se o my-local-ia funciona (Verificar).
  2. Se a versão anterior também falhar, a versão nova pode já ter convertido o banco de dados: escolha **5) Restaurar** e pegue o backup feito logo antes da atualização.
  3. Mande os logs (seção 11) antes de tentar a atualização de novo.

### Restaurando um backup à mão

Se não der para usar o instalador (Linux; ajuste o nome do arquivo):

```bash
docker stop my-local-ia
docker run --rm -v my-local-ia-data:/data -v /var/backups/my-local-ia:/backup alpine:3.20 \
  sh -c "find /data -mindepth 1 -delete && tar xzf /backup/my-local-ia-data-AAAAMMDD-HHMMSS.tar.gz -C /data"
docker start my-local-ia
```

### Mudando o my-local-ia para outro servidor

1. Servidor antigo: instalador → **4) Fazer backup dos dados agora**.
2. Copie o arquivo `.tar.gz` para o servidor novo, na pasta `/var/backups/my-local-ia/` (Windows: `C:\ProgramData\my-local-ia\backups\`).
3. Servidor novo: instalador → **1) Instalar**.
4. Servidor novo: instalador → **5) Restaurar**, escolha o arquivo copiado.

---

## 9. A imagem do my-local-ia

### "Não foi possível baixar ghcr.io/<usuario>/my-local-ia…"

- **Causas:**
  - O repositório no GitHub ainda não gerou a imagem (a geração roda no GitHub Actions e leva de 20 a 40 minutos).
  - O pacote da imagem está **privado**.
  - O usuário do GitHub foi digitado errado.
- **Solução:**
  1. No GitHub, abra o repositório → **Actions**: o "build" mais recente precisa estar verde.
  2. Abra seu perfil → **Packages** → `my-local-ia` → **Package settings** → **Change visibility** → **Public**.
  3. Rode **Atualizar** de novo e escolha my-local-ia. Enquanto isso, a versão oficial continua funcionando.

---

## 10. Espaço em disco

### "no space left on device" / "Menos de 30 GB livres"

- **Veja o que ocupa espaço:**

  ```bash
  df -h /                      # espaço livre
  docker system df             # imagens, contêineres e volumes
  ollama list                  # modelos e seus tamanhos
  ```

- **Libere espaço com segurança:**
  - Remova modelos que você não usa: `ollama rm <modelo>`.
  - Remova imagens Docker que não são mais usadas (versões antigas depois de atualizações): `docker image prune -a`. Isso **não** apaga os seus dados (volumes).
  - Remova backups antigos em `/var/backups/my-local-ia/` (o instalador já mantém só os 5 mais recentes).
- **Nunca** rode `docker volume prune` ou `docker system prune --volumes` sem backup: eles podem apagar o volume `my-local-ia-data`.

---

## 11. Pedindo ajuda

Mande:

1. O **relatório** criado pelo **3) Verificar** (o caminho aparece no fim do Verificar).
2. O **log do instalador** (`/var/log/my-local-ia-install.log` ou `C:\ProgramData\my-local-ia\logs\install.log`).
3. O que você estava fazendo e a mensagem exata na tela (uma captura de tela ajuda).

O relatório e o log nunca têm senhas nem a chave secreta. Eles têm endereços IP e nomes de modelos e pastas: remova o que você não quiser compartilhar.
