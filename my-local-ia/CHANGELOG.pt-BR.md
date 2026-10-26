# Histórico de versões do my-local-ia

Cada versão tem uma tag no GitHub (`v1.0`, `v1.1`…) e, a partir da 2.1, uma imagem fixa no GHCR que nunca muda. Para instalar uma versão antiga, use a imagem dela no lugar de `:cuda` (ou `:main`, sem placa de vídeo).

Também em [English](CHANGELOG.md) e [Español](CHANGELOG.es.md).

| Versão | Data       | Destaque                                                | Imagem fixa (GPU)                                                                   |
| ------ | ---------- | ------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| 3.2    | 25/10/2026 | Catálogo balanceado entre as notas                      | `ghcr.io/jleoandrade/my-local-ia:git-278c83b45ec47bb703c8329d9261e25c04d183b2-cuda` |
| 3.1    | 25/10/2026 | Leitura da biblioteca do Ollama corrigida               | `ghcr.io/jleoandrade/my-local-ia:git-957b2b26c7c5bc3c71fba902cb4c4a84d69f7733-cuda` |
| 3.0    | 25/10/2026 | Biblioteca do Ollama, downloads em segundo plano, Ajuda | `ghcr.io/jleoandrade/my-local-ia:git-153c03666fd4e687524cca1dcd0eab07a7f0a54d-cuda` |
| 2.2    | 25/10/2026 | Modo de ferramentas automático e redetecção de hardware | `ghcr.io/jleoandrade/my-local-ia:git-c61159e117912d25f3ac8d0f710b3aff7a0c561f-cuda` |
| 2.1    | 25/10/2026 | Compilar a imagem no próprio servidor                   | `ghcr.io/jleoandrade/my-local-ia:git-a9d22996ccc7029d428a1e86664729b612dcb5f5-cuda` |
| 2.0    | 25/10/2026 | Todas as telas do my-local-ia                           | — (sem imagem própria)                                                              |
| 1.1    | 25/10/2026 | Imagem gerada pelo GitHub Actions                       | —                                                                                   |
| 1.0    | 24/10/2026 | Instaladores, documentação e base do catálogo           | — (instalava o Open WebUI oficial)                                                  |

## 3.2 — Catálogo balanceado

- O robô divide as vagas por nota neste servidor: 40% Roda liso, 30% Usável, 22% Pesado e 8% Não roda. As vagas que uma nota não preencher vão para Usável, Pesado, Roda liso e Não roda, nessa ordem.
- Antes, numa placa de 12 GB, quase tudo vinha como Roda liso (349 contra 7 Usável).

## 3.1 — Biblioteca do Ollama corrigida

- A página do ollama.com não tinha as marcações que o robô procurava. Agora os nomes vêm dos links `/library/<nome>` e os tamanhos do registro oficial do Ollama, com o tamanho exato de cada download.
- Contagens de downloads ("40M") não são mais confundidas com tamanhos ("40m").
- O status do robô diz claramente quando encontra os nomes mas não consegue ler os tamanhos.

## 3.0 — Catálogo maior, downloads em segundo plano e Ajuda

- **Robô**: lê também a biblioteca oficial do Ollama (todos os tamanhos de cada modelo) e mais perfis do Hugging Face; guarda até 300 modelos, sem duplicar os escolhidos a dedo. Roda logo depois de cada atualização.
- **Filtro "Cabe neste servidor"** ligado por padrão (Roda liso e Usável).
- **Downloads em segundo plano**: fechar a janela ou mudar de página não interrompe; o progresso aparece embaixo do medidor de disco para todos, com opção de cancelar.
- **Página de Ajuda** (botão no topo das páginas do my-local-ia e no menu do usuário) sobre o Open WebUI, o Ollama e o my-local-ia, em três idiomas, com busca e imagens.
- Manual do usuário em Word (português, inglês e espanhol).

## 2.2 — Ferramentas e hardware

- Modelos que não sabem usar ferramentas (qwen2.5-coder, os menores de 4B e os sem suporte) não recebem mais as ferramentas do Open WebUI: antes respondiam com um bloco de JSON.
- O hardware é detectado de novo a cada inicialização e conferido a cada poucos minutos; "Detectar de novo" diz o que mudou.

## 2.1 — Compilar no servidor

- Os instaladores ganharam a opção de compilar a imagem no próprio servidor (sem depender do GitHub Actions), com backup e volta automática.
- Os workflows de publicação do projeto original foram desativados no fork.

## 2.0 — Funcionalidades do my-local-ia

- Catálogo "Roda na minha GPU?" com as notas para este hardware e "Melhores para este servidor".
- Aviso no seletor de modelos, quadro "Antes de enviar", simulador de até 3 modelos.
- Espaço em disco para todos, com alertas (faixa e webhook), previsão e sugestões de remoção.
- Downloads para todos os usuários, com verificação de disco e alternativas.
- Configurações do administrador e robô de modelos novos (Hugging Face).
- Interface em inglês, português e espanhol.

## 1.1 — Imagem no GitHub Actions

- Workflow que gera as imagens `cuda` e `main` em `ghcr.io/<usuário>/my-local-ia`.

## 1.0 — Base

- Instaladores para Linux (bash) e Windows (PowerShell) em três idiomas: instalar, atualizar, verificar, backup, restaurar, redefinir senha e desinstalar. Porta 4000, acesso só pela rede local.
- Documentação de instalação e solução de problemas em português, inglês e espanhol.
- Detecção de hardware, estimativa de velocidade e o catálogo de modelos (primeira fase).
