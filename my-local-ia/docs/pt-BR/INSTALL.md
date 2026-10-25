# my-local-ia — Guia de instalação

[English](../en/INSTALL.md) · [Español](../es/INSTALL.md) · Solução de problemas: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

Este guia instala o **my-local-ia** em um servidor que já roda o **Ollama**. Você não precisa saber Docker nem comandos de Linux além de copiar um arquivo e rodar um comando: o instalador pergunta tudo o que precisa, mostra cada etapa e pede confirmação antes de mudar qualquer coisa.

---

## Sumário

1. [O que é instalado](#1-o-que-é-instalado)
2. [Requisitos](#2-requisitos)
3. [Antes de começar: verificação de 2 minutos](#3-antes-de-começar-verificação-de-2-minutos)
4. [Instalando no Linux](#4-instalando-no-linux)
5. [Instalando no Windows](#5-instalando-no-windows)
6. [O que cada etapa do instalador faz](#6-o-que-cada-etapa-do-instalador-faz)
7. [Primeiro acesso](#7-primeiro-acesso)
8. [O menu do instalador: atualizar, verificar, backup, restaurar, senha, desinstalar](#8-o-menu-do-instalador)
9. [Trocando da versão oficial para o my-local-ia](#9-trocando-da-versão-oficial-para-o-my-local-ia)
10. [Onde tudo fica guardado](#10-onde-tudo-fica-guardado)
11. [Modo simulação](#11-modo-simulação)
12. [Publicar na internet (depois)](#12-publicar-na-internet-depois)
13. [Observações de segurança](#13-observações-de-segurança)
14. [Comandos úteis](#14-comandos-úteis)

---

## 1. O que é instalado

```
 Navegador (qualquer computador da sua rede)
        │  http://IP-DO-SERVIDOR:4000
        ▼
 ┌──────────────────────────────┐
 │ my-local-ia (contêiner Docker)│  interface web, usuários, conversas, documentos
 │ imagem oficial do Open WebUI  │
 │ ou a versão my-local-ia       │
 └──────────────┬───────────────┘
                │  http://127.0.0.1:11434
                ▼
 ┌──────────────────────────────┐
 │ Ollama (já instalado)        │  roda os modelos de IA
 └──────────────┬───────────────┘
                ▼
        Placa de vídeo NVIDIA (VRAM)
```

- O **my-local-ia** é a interface web. Ele roda dentro de um contêiner Docker chamado `my-local-ia` e guarda os dados (usuários, conversas, configurações, arquivos enviados) em um volume Docker chamado `my-local-ia-data`.
- O **Ollama** continua funcionando exatamente como está. O instalador nunca mexe nos seus modelos.
- Existem duas versões:
  - **Open WebUI oficial**: o projeto original, recomendado enquanto a versão my-local-ia não estiver publicada.
  - **my-local-ia**: o Open WebUI com as funções do my-local-ia (catálogo de modelos de acordo com o hardware, simulador, monitoramento de disco…), gerado a partir do seu repositório no GitHub.

  Dá para trocar de uma para a outra a qualquer momento pela opção **Atualizar**, sem perder dados.

> **Sobre a licença.** O my-local-ia é baseado no Open WebUI. A licença exige manter o nome e o logo "Open WebUI" na interface, exceto em instalações com até 50 usuários em um período de 30 dias (ou com autorização por escrito / licença enterprise).

---

## 2. Requisitos

### Servidor Linux (instalador: `install-my-local-ia.sh`)

| Item           | Requisito                                                                                                                                                                  |
| -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sistema        | Ubuntu 20.04 ou mais novo, Debian 11 ou mais novo e derivados (Linux Mint, Pop!\_OS…), Fedora, RHEL / Rocky / AlmaLinux / CentOS Stream 8 ou mais novos. 64 bits (x86_64). |
| Acesso         | Um usuário que possa usar `sudo`.                                                                                                                                          |
| Placa de vídeo | Placa NVIDIA com o driver instalado (`nvidia-smi` precisa funcionar). Sem placa, a instalação funciona, mas em modo CPU.                                                   |
| Ollama         | Instalado e rodando no mesmo servidor.                                                                                                                                     |
| Disco          | Pelo menos **30 GB livres** (a imagem com GPU tem uns 6 GB; os modelos são à parte).                                                                                       |
| RAM            | Mínimo de 8 GB, recomendado 16 GB ou mais.                                                                                                                                 |
| Internet       | Necessária durante a instalação e as atualizações (para baixar o Docker e a imagem).                                                                                       |

O Docker e o NVIDIA Container Toolkit **não precisam estar instalados**: o instalador instala o que faltar (depois de perguntar).

### Computador Windows (instalador: `install-my-local-ia.ps1`)

| Item           | Requisito                                                                                                                                                          |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Sistema        | Windows 10 versão 2004 (build 19041) ou mais novo, ou Windows 11 — Home, Pro ou Enterprise. **O Windows Server não é suportado** (o Docker Desktop não roda nele). |
| Acesso         | Uma conta com permissão de administrador.                                                                                                                          |
| Virtualização  | Ativada na BIOS/UEFI. Se o próprio Windows for uma máquina virtual, a _virtualização aninhada_ precisa estar ativada no hipervisor.                                |
| Placa de vídeo | Placa NVIDIA com o driver do Windows atualizado.                                                                                                                   |
| Ollama         | Ollama para Windows, instalado e rodando.                                                                                                                          |
| Disco          | Pelo menos **30 GB livres** no C:.                                                                                                                                 |
| Internet       | Necessária durante a instalação e as atualizações.                                                                                                                 |

O Docker Desktop e o WSL 2 são instalados pelo instalador se faltarem (nesse caso o Windows precisa reiniciar uma vez).

> **Licença do Docker Desktop:** gratuito para uso pessoal, educação, código aberto e empresas com menos de 250 funcionários **e** menos de US$ 10 milhões de faturamento anual. Empresas maiores precisam de assinatura paga. No Linux, o Docker Engine não tem essa restrição.

---

## 3. Antes de começar: verificação de 2 minutos

No servidor, confirme que a placa de vídeo e o Ollama funcionam. Se algum falhar, resolva antes (veja o [TROUBLESHOOTING.md](TROUBLESHOOTING.md)).

**Linux**

```bash
nvidia-smi                      # precisa mostrar sua placa, ex.: "NVIDIA GeForce RTX 3060 … 12288MiB"
ollama list                     # precisa listar seus modelos (lista vazia também serve)
curl http://127.0.0.1:11434     # precisa responder "Ollama is running"
```

**Windows** (PowerShell)

```powershell
nvidia-smi
ollama list
curl.exe http://127.0.0.1:11434
```

---

## 4. Instalando no Linux

### 4.1 Copie o instalador para o servidor

Coloque o `install-my-local-ia.sh` na pasta `/tmp` do servidor. Algumas formas:

- **Do Windows, macOS ou Linux com `scp`** (troque `usuario` e `192.168.1.50`):

  ```bash
  scp install-my-local-ia.sh usuario@192.168.1.50:/tmp/
  ```

- **Do Windows com WinSCP ou FileZilla**: conecte por SFTP no servidor e arraste o arquivo para `/tmp`.

> O `/tmp` é só o ponto de partida do instalador. Tudo o que importa é guardado fora dele (veja a [seção 10](#10-onde-tudo-fica-guardado)), porque o `/tmp` costuma ser apagado quando o servidor reinicia.

### 4.2 (Recomendado) Use o `tmux` se estiver conectado por SSH

Se a conexão SSH cair no meio da instalação, o instalador para. O `tmux` mantém tudo rodando:

```bash
sudo apt install -y tmux     # Ubuntu/Debian   (Fedora/RHEL: sudo dnf install -y tmux)
tmux new -s instalacao
```

Se a conexão cair, conecte de novo e rode `tmux attach -t instalacao` para ver o instalador outra vez.

### 4.3 Rode o instalador

```bash
sudo bash /tmp/install-my-local-ia.sh
```

1. Escolha o idioma (English, Português ou Español).
2. Escolha **1) Instalar**.
3. Responda às perguntas. Aperte **Enter** para aceitar o valor entre colchetes, por exemplo `Porta de acesso ao my-local-ia [4000]:`.
4. No final, o instalador mostra o endereço para abrir no navegador.

A instalação leva de 5 a 20 minutos, a maior parte para baixar a imagem (vários GB) e na primeira inicialização.

---

## 5. Instalando no Windows

### 5.1 Copie o instalador

Crie a pasta `C:\temp` e coloque o `install-my-local-ia.ps1` nela.

### 5.2 Abra o PowerShell como administrador

Menu Iniciar → digite **PowerShell** → clique com o botão direito em **Windows PowerShell** → **Executar como administrador**.

### 5.3 Rode o instalador

```powershell
powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1
```

O `-ExecutionPolicy Bypass` deixa só este script rodar, sem mudar a política de segurança do computador. Se o Windows disser que o arquivo veio da internet e está bloqueado, desbloqueie antes:

```powershell
Unblock-File C:\temp\install-my-local-ia.ps1
```

Depois escolha o idioma e **1) Instalar**, como no Linux.

### 5.4 O que muda no Windows

- **WSL 2 e Docker Desktop.** Se faltarem, o instalador instala pelo `winget` e pede para **reiniciar o Windows**. Depois de reiniciar, rode o mesmo comando de novo e escolha **Instalar**: ele continua com as respostas já dadas.
- **Termos do Docker Desktop.** Na primeira vez que o Docker Desktop abre, aparece uma janela com os termos dele. Aceite; o instalador espera até 5 minutos o Docker ficar pronto.
- **Ollama e Docker.** Por padrão, o Ollama no Windows só aceita conexões do próprio computador. Se o contêiner não conseguir falar com ele, o instalador oferece definir `OLLAMA_HOST=0.0.0.0:11434` para o seu usuário e reiniciar o Ollama.
- **Firewall e tipo de rede.** O instalador cria uma regra no firewall do Windows para a porta, válida para redes **Privadas** e de **Domínio**. Se o Windows classificar sua rede como **Pública**, a regra não vale: mude em _Configurações → Rede e Internet → (sua conexão) → Rede privada_.
- **Porta dentro do contêiner.** No Windows, o contêiner escuta na 8080 e o Docker publica na porta escolhida (4000 por padrão). No Linux, ele escuta direto na porta escolhida.

---

## 6. O que cada etapa do instalador faz

A instalação tem 11 etapas numeradas. Tudo o que muda o sistema é mostrado (linhas começando com `$` ou `>`) e confirmado com você antes.

| Etapa                        | O que acontece                                                                                                                                                                               | Muda o sistema?      |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| 1. Verificando este servidor | Mostra sistema, processador, RAM, disco livre, acesso à internet, placa de vídeo e driver, Ollama (versão, quantidade de modelos, pasta dos modelos), Docker e a rede (IP local ou público). | Não                  |
| 2. Perguntas                 | Versão (oficial ou my-local-ia), porta (padrão **4000**), endereço do Ollama, pasta de modelos do Ollama. Depois, um resumo e uma confirmação.                                               | Salva suas respostas |
| 3. Docker                    | Instala o Docker pelo repositório oficial do Docker se faltar (Linux) ou o Docker Desktop (Windows).                                                                                         | Sim, se faltar       |
| 4. Suporte à placa de vídeo  | Linux: instala e configura o NVIDIA Container Toolkit se faltar. Nos dois: roda um contêiner de teste que precisa enxergar a placa.                                                          | Sim, se faltar       |
| 5. Arquivos de configuração  | Cria a configuração e uma **chave secreta** aleatória (usada para assinar os logins). Ela é mantida nas atualizações, para ninguém ser deslogado.                                            | Sim                  |
| 6. Baixando a imagem         | Baixa a imagem (oficial: `ghcr.io/open-webui/open-webui:cuda`).                                                                                                                              | Sim                  |
| 7. Iniciando                 | Inicia o contêiner **acessível só pelo próprio servidor** e espera ele responder.                                                                                                            | Sim                  |
| 8. Conta de administrador    | Pergunta nome, e-mail e senha (oculta, digitada duas vezes) e cria o primeiro usuário, que vira administrador. Pulada se já existirem usuários.                                              | Sim                  |
| 9. Liberando para a rede     | Reinicia o contêiner para que outros computadores consigam acessar.                                                                                                                          | Sim                  |
| 10. Firewall                 | Rede local: libera a porta só para a sua rede local (ufw, firewalld ou firewall do Windows). IP público: **não** libera a porta.                                                             | Sim, se confirmar    |
| 11. Testes finais            | Contêiner rodando, interface web respondendo, placa de vídeo visível no contêiner, conexão com o Ollama, quantidade de modelos.                                                              | Não                  |

**Por que as etapas 7 e 9 são separadas:** a primeira pessoa que cria uma conta vira administradora. Entre iniciar o contêiner e criar a sua conta, o instalador deixa o my-local-ia acessível só pelo próprio servidor, para ninguém da rede pegar a conta de administrador antes.

**Como o instalador detecta o tipo de acesso:** ele olha o endereço IP do servidor. Endereços como `192.168.x.x`, `10.x.x.x` e `172.16–31.x.x` são de rede local: a porta é liberada só para essa rede. Qualquer outro endereço é público: a porta não é liberada, e uma mensagem indica a [seção 12](#12-publicar-na-internet-depois).

---

## 7. Primeiro acesso

1. Em qualquer computador da rede, abra `http://IP-DO-SERVIDOR:4000` (o instalador mostra o endereço exato no final).
2. Entre com o e-mail e a senha do administrador.
3. Escolha um modelo no topo da tela e comece a conversar. Os modelos são os instalados no Ollama (`ollama list`).

**Adicionando pessoas**

- **Painel do admin → Usuários → +**: crie a conta você mesmo e passe a senha para a pessoa; ou
- deixe as pessoas se cadastrarem na tela de login. Novas contas ficam **pendentes** até um administrador aprovar em **Painel do admin → Usuários** (mude a função de _pending_ para _user_). A opção de cadastro e a função padrão ficam em **Painel do admin → Configurações → Geral**.

**Conferindo a conexão com o Ollama:** **Painel do admin → Configurações → Conexões**. O endereço do Ollama precisa ser o que o instalador mostrou (`http://127.0.0.1:11434` no Linux, `http://host.docker.internal:11434` no Windows).

---

## 8. O menu do instalador

Rode o instalador de novo sempre que precisar de uma destas opções. Ele lembra das suas respostas anteriores.

| Opção                                  | O que faz                                                                                                                                                                                  |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **1) Instalar**                        | Instala, ou recria o contêiner mantendo todos os dados.                                                                                                                                    |
| **2) Atualizar ou trocar de versão**   | Baixa a imagem mais nova (mesma versão, oficial ou my-local-ia), oferece um **backup**, troca o contêiner e testa. Se a versão nova não iniciar, **volta sozinho para a anterior**.        |
| **3) Verificar**                       | Só diagnóstico: confere tudo e salva um arquivo de **relatório** para mandar ao pedir ajuda. Não muda nada.                                                                                |
| **4) Fazer backup dos dados agora**    | Salva usuários, conversas, configurações e arquivos enviados em um arquivo `.tar.gz`. O my-local-ia para por alguns segundos. Ficam os 5 backups mais recentes.                            |
| **5) Restaurar um backup**             | Lista os backups e restaura o que você escolher (substitui os dados atuais, depois de confirmar).                                                                                          |
| **6) Redefinir a senha de um usuário** | Define uma senha nova para qualquer usuário, inclusive o administrador.                                                                                                                    |
| **7) Desinstalar**                     | Remove o contêiner e a regra de firewall. Os dados só são apagados se você confirmar e digitar `DELETE`, e um backup é oferecido antes. Docker, Ollama e seus modelos nunca são removidos. |

---

## 9. Trocando da versão oficial para o my-local-ia

Quando o repositório my-local-ia estiver publicado no GitHub e a imagem dele estiver pronta:

1. Rode o instalador e escolha **2) Atualizar ou trocar de versão**.
2. Escolha **my-local-ia** e digite o usuário do GitHub dono do repositório.
3. Aceite o backup.

O instalador baixa `ghcr.io/<usuario-github>/my-local-ia:cuda`, mantém todos os seus dados e volta para a versão anterior se algo falhar. Se ele disser que não conseguiu baixar a imagem, ela ainda não foi publicada, ou o pacote dela está privado (veja o guia de solução de problemas).

### Opção sem GitHub Actions: compilar a imagem no próprio servidor

Se você não quer depender do GitHub Actions (ou quer testar uma mudança antes de publicar), o instalador compila a imagem aqui mesmo:

1. Rode o instalador e escolha **2) Atualizar ou trocar de versão** (ou **1) Instalar**, numa instalação nova).
2. Escolha **my-local-ia compilado aqui no servidor a partir do código-fonte**.
3. Confirme o usuário do GitHub, o endereço do repositório (padrão: `https://github.com/<usuario>/my-local-ia`) e a branch (padrão: `main`).
4. Confirme a compilação. Ela leva de **20 a 60 minutos** e precisa de uns **25 GB livres**.

O que acontece:

- **Linux:** o código é baixado com `git` em `/opt/my-local-ia/src` (o `git` é instalado se faltar). Nas próximas vezes só as mudanças são baixadas.
- **Windows:** o código é baixado como ZIP em `C:\ProgramData\my-local-ia\src` (sem `git`, para os scripts manterem o formato de linha do Linux dentro da imagem). O repositório precisa estar no GitHub.
- A imagem é gerada com o mesmo `Dockerfile` do GitHub Actions, com memória extra para a compilação da interface (metade da RAM, entre 4 e 12 GB), e recebe os nomes `my-local-ia:local-cuda` (com GPU) ou `my-local-ia:local-main` (sem GPU).
- A troca do contêiner é igual à da atualização normal: backup opcional, o contêiner antigo fica guardado até o novo responder e, se o novo falhar, o instalador volta para o antigo.
- No fim, o instalador oferece apagar o cache da compilação e as imagens antigas para liberar disco.

Para atualizar depois: rode **Atualizar** e escolha **A mesma versão, na atualização mais recente**. Com uma imagem compilada aqui, isso baixa o código novo e compila de novo.

---

## 10. Onde tudo fica guardado

| O quê                                                | Linux                                          | Windows                                                           |
| ---------------------------------------------------- | ---------------------------------------------- | ----------------------------------------------------------------- |
| Dados (usuários, conversas, configurações, arquivos) | Volume Docker `my-local-ia-data`               | Volume Docker `my-local-ia-data`                                  |
| Respostas do instalador                              | `/etc/my-local-ia/installer.conf`              | `C:\ProgramData\my-local-ia\installer.json`                       |
| Configuração do contêiner e chave secreta            | `/etc/my-local-ia/my-local-ia.env` (só root)   | `C:\ProgramData\my-local-ia\my-local-ia.env` (só administradores) |
| Log do instalador                                    | `/var/log/my-local-ia-install.log`             | `C:\ProgramData\my-local-ia\logs\install.log`                     |
| Relatórios de diagnóstico                            | `/var/log/my-local-ia-report-*.txt`            | `C:\ProgramData\my-local-ia\logs\report-*.txt`                    |
| Backups                                              | `/var/backups/my-local-ia/`                    | `C:\ProgramData\my-local-ia\backups\`                             |
| Modelos do Ollama (só leitura para o my-local-ia)    | normalmente `/usr/share/ollama/.ollama/models` | normalmente `C:\Users\<você>\.ollama\models`                      |

As senhas **nunca** são gravadas no log, na tela ou nos arquivos de configuração.

---

## 11. Modo simulação

Para ver tudo o que o instalador faria, sem mudar nada:

```bash
sudo bash /tmp/install-my-local-ia.sh --dry-run
```

```powershell
powershell -ExecutionPolicy Bypass -File C:\temp\install-my-local-ia.ps1 -DryRun
```

Outras opções: `--lang en|pt|es` (Linux) e `-Lang en|pt|es` (Windows) escolhem o idioma sem perguntar.

---

## 12. Publicar na internet (depois)

O instalador só prepara o acesso pela **rede local**. Se você decidir deixar o my-local-ia acessível pela internet:

- **Preferível: Cloudflare Tunnel.** O programa `cloudflared` roda no servidor e abre uma conexão de saída até a Cloudflare, então **nenhuma porta precisa ser aberta no roteador**. A Cloudflare cuida do HTTPS, e você pode adicionar o **Cloudflare Access** para exigir um login extra (código por e-mail, Google…) antes de alguém sequer ver o my-local-ia. Guia: <https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/>
- **Se usar redirecionamento de portas no roteador:** nunca redirecione a porta 4000 direto. Coloque na frente um proxy reverso com HTTPS (por exemplo Caddy ou Nginx), redirecione só a porta 443 para ele, ative o proxy da Cloudflare (nuvem laranja) com o modo SSL **Full (strict)** e restrinja a regra do roteador às faixas de IP da Cloudflare.

Nos dois casos, antes de publicar:

1. Desative o cadastro aberto (**Painel do admin → Configurações → Geral**) ou mantenha novos usuários como _pendentes_.
2. Use senhas fortes em todas as contas, principalmente nas de administrador.
3. Mantenha o my-local-ia atualizado (opção **Atualizar**).
4. Nunca exponha a porta do Ollama (11434) na internet: o Ollama não tem login.

---

## 13. Observações de segurança

- O instalador só muda o que ele mostra e você confirma. Ele nunca remove Docker, Ollama ou modelos.
- A chave secreta e a configuração só podem ser lidas pelo root (Linux) ou por administradores (Windows).
- A senha do administrador é enviada direto ao my-local-ia, nunca em uma linha de comando, então ela não aparece na lista de processos nem no log.
- No Linux, o contêiner usa a rede do próprio servidor (`--network host`) para alcançar o Ollama em `127.0.0.1` sem expor o Ollama na rede.
- No Windows, se você permitir `OLLAMA_HOST=0.0.0.0`, o Ollama também aceita conexões de outros computadores, se o firewall do Windows permitir. O Ollama não tem login: mantenha a porta 11434 fechada para a rede no firewall.

---

## 14. Comandos úteis

Linux (use `sudo` se o seu usuário não estiver no grupo `docker`). No Windows, os mesmos comandos `docker` funcionam no PowerShell.

```bash
docker ps                                  # o contêiner my-local-ia está rodando?
docker logs --tail 100 my-local-ia         # últimas 100 linhas do log dele
docker logs -f my-local-ia                 # acompanhar o log ao vivo (Ctrl+C para sair)
docker restart my-local-ia                 # reiniciar
docker stop my-local-ia                    # parar
docker start my-local-ia                   # iniciar
docker exec my-local-ia nvidia-smi         # placa de vídeo vista de dentro do contêiner
docker system df                           # espaço em disco usado pelo Docker
ollama ps                                  # modelos carregados e se estão na GPU ou na CPU
```

Documentação do Open WebUI (a base do my-local-ia): <https://docs.openwebui.com>
