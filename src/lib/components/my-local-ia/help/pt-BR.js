// Ajuda do my-local-ia em português. O mesmo conteúdo gera a página de ajuda e o manual em Word.
// Blocos: ['p', texto], ['steps', [...]], ['bullets', [...]], ['tip'|'note'|'warn', texto],
// ['img', nome, legenda], ['code', [linhas]], ['table', cabeçalho, linhas].
// Nos textos, **negrito** e `código`.
export default {
	title: 'Ajuda do my-local-ia',
	subtitle: 'Como usar o Open WebUI, o Ollama e as funções do my-local-ia',
	intro:
		'O my-local-ia junta três coisas: o **Ollama**, que roda os modelos de IA no servidor; o **Open WebUI**, a interface de chat que você usa no navegador; e as funções do **my-local-ia**, que mostram o que roda bem no seu hardware, cuidam do disco e facilitam os downloads. Escolha um assunto abaixo.',
	open: 'Abrir',
	adminOnly: 'Só administradores',
	search: 'Buscar na ajuda…',
	noResults: 'Nada encontrado. Tente outra palavra.',
	sections: [
		{
			id: 'start',
			title: 'Primeiros passos',
			summary: 'Entrar, conhecer a tela e escolher o idioma.',
			link: '/',
			blocks: [
				[
					'steps',
					[
						'Abra **http://IP-DO-SERVIDOR:4000** no navegador de qualquer computador ou celular da rede.',
						'Entre com seu e-mail e senha. Se você se cadastrou agora, espere um administrador aprovar a conta.',
						'Escolha um modelo no topo da conversa (ou no botão ao lado do campo de mensagem) e escreva sua pergunta.'
					]
				],
				[
					'img',
					'chat',
					'Tela inicial: menu lateral à esquerda, campo de mensagem e seletor de modelo.'
				],
				[
					'table',
					['Parte da tela', 'Para que serve'],
					[
						[
							'Menu lateral',
							'Novo chat, pesquisa, my-local-ia, notas, espaço de trabalho, pastas e o histórico de conversas.'
						],
						[
							'Disco do servidor',
							'No pé do menu: quanto do disco está ocupado e os downloads em andamento.'
						],
						[
							'Seletor de modelo',
							'Escolhe qual IA responde. A etiqueta colorida mostra como ela roda neste servidor.'
						],
						[
							'Campo de mensagem',
							'Onde você escreve, anexa arquivos, liga ferramentas e usa a voz.'
						],
						[
							'Sua foto (embaixo)',
							'Configurações, chats arquivados, Painel do Admin (administradores) e sair.'
						]
					]
				],
				[
					'tip',
					'Para trocar o idioma: foto de perfil → **Configurações** → **Geral** → **Idioma**. A interface tem português, inglês e espanhol completos.'
				],
				[
					'p',
					'Para abrir esta ajuda de qualquer lugar, clique em **Ajuda** no topo das páginas do my-local-ia.'
				]
			]
		},
		{
			id: 'chat',
			title: 'Conversar com a IA',
			summary: 'Enviar mensagens, anexar arquivos, usar a voz e comparar modelos.',
			link: '/',
			blocks: [
				['h', 'Enviar uma mensagem'],
				[
					'steps',
					[
						'Clique em **Novo Chat** no menu lateral.',
						'Escolha o modelo. Se ele for pesado para este servidor, o my-local-ia avisa e sugere um mais leve.',
						'Escreva e aperte **Enter** (para pular linha sem enviar: **Shift + Enter**).',
						'A resposta aparece aos poucos. Para parar, clique no botão de parar.'
					]
				],
				['h', 'O botão + (anexos)'],
				[
					'bullets',
					[
						'**Carregar Arquivos**: PDF, Word, planilhas, textos, imagens e áudios. O conteúdo vai junto com a pergunta.',
						'**Capturar**: tira um print da tela e anexa.',
						'**Anexar página da web**: cola um endereço e o texto da página entra na conversa.',
						'**Anexar notas, conhecimento e chats**: usa suas notas, bases de conhecimento ou conversas antigas como contexto.'
					]
				],
				[
					'note',
					'Antes de enviar um anexo, o quadro **Antes de enviar** diz se o modelo escolhido lê aquele tipo de arquivo e quanto tempo vai levar lendo.'
				],
				['h', 'Ferramentas (botão de integrações)'],
				[
					'bullets',
					[
						'**Pesquisa na Web**: a IA busca na internet antes de responder (precisa estar ativada pelo administrador).',
						'**Imagem**: gera imagens a partir do texto (precisa de um gerador de imagens configurado).',
						'**Intérprete de código**: a IA escreve e executa código Python para fazer contas, gráficos e análises de planilhas.',
						'**Ferramentas e Skills**: ferramentas extras instaladas no Espaço de Trabalho.'
					]
				],
				['h', 'Atalhos no campo de mensagem'],
				[
					'table',
					['Digite', 'O que acontece'],
					[
						['`@`', 'Chama outro modelo só para a próxima mensagem.'],
						['`/`', 'Usa um prompt salvo (veja Espaço de Trabalho → Prompts).'],
						['`#`', 'Anexa uma base de conhecimento ou um arquivo.'],
						['`$`', 'Usa uma skill.'],
						['`:`', 'Insere um emoji.']
					]
				],
				['h', 'Voz'],
				[
					'bullets',
					[
						'**Ditar** (microfone): fale e o texto aparece no campo; a transcrição é feita aqui no servidor.',
						'**Chamada / modo de voz**: uma conversa falada, com a resposta lida em voz alta.'
					]
				],
				['h', 'Ações em cada resposta'],
				[
					'bullets',
					[
						'**Copiar**, **Editar** a sua pergunta ou a resposta, **Ler em voz alta**.',
						'**Gerar novamente**: outra resposta para a mesma pergunta (as versões ficam salvas e dá para alternar).',
						'**Continuar resposta**: quando a resposta foi cortada.',
						'**Boa resposta / Resposta ruim**: avaliações que o administrador vê em Avaliações.'
					]
				],
				['h', 'Comparar modelos e outras opções'],
				[
					'bullets',
					[
						'**Vários modelos**: no seletor, clique em **+** para adicionar outro modelo; cada um responde lado a lado.',
						'**Chat temporário**: não fica salvo no histórico.',
						'**Controles** (ícone no topo direito): prompt do sistema e parâmetros como temperatura e tamanho do contexto só para esta conversa.'
					]
				]
			]
		},
		{
			id: 'organize',
			title: 'Organizar as conversas',
			summary: 'Pesquisar, pastas, fixar, arquivar, compartilhar e exportar.',
			link: '/',
			blocks: [
				[
					'bullets',
					[
						'**Pesquisar** (menu lateral): procura em todas as suas conversas.',
						'**Pastas**: clique no **+** ao lado de Pastas e arraste conversas para dentro. Uma pasta pode ter instruções e arquivos próprios.',
						'**Menu de cada conversa** (três pontos): renomear, fixar no topo, arquivar, compartilhar, baixar (texto, PDF ou JSON), mover e excluir.',
						'**Tags**: etiquetas que a IA sugere e que você pode usar na pesquisa.',
						'**Chats arquivados**: Configurações → **Chats Arquivados**, para recuperar ou excluir de vez.',
						'**Exportar ou importar tudo**: Configurações → **Controle de Dados**.'
					]
				],
				[
					'warn',
					'Um link de compartilhamento dá acesso à conversa para quem tiver conta no my-local-ia. Não compartilhe conversas com dados sensíveis.'
				]
			]
		},
		{
			id: 'knowledge',
			title: 'Documentos e bases de conhecimento',
			summary: 'Fazer a IA responder com base nos seus arquivos.',
			link: '/workspace/knowledge',
			blocks: [
				[
					'p',
					'Uma **base de conhecimento** é uma pasta de documentos que a IA consulta para responder. O texto é dividido em trechos e indexado por um modelo de **embeddings**; a cada pergunta, só os trechos mais parecidos vão para o modelo.'
				],
				[
					'steps',
					[
						'Abra **Espaço de Trabalho** → **Conhecimento** → **+**.',
						'Dê um nome e uma descrição e escolha quem pode ver.',
						'Envie os arquivos (PDF, Word, textos, planilhas…) ou uma pasta inteira.',
						'No chat, digite `#` e escolha a base, ou ligue a base a um modelo personalizado para ela ser usada sempre.'
					]
				],
				[
					'tip',
					'Para documentos em português e espanhol, um modelo de embeddings multilíngue (como o **BGE-M3**, recomendado no catálogo) dá resultados bem melhores.'
				],
				[
					'note',
					'Arquivo anexado direto na conversa também é lido, mas só naquela conversa. Use bases de conhecimento para documentos que serão consultados muitas vezes.'
				]
			]
		},
		{
			id: 'workspace',
			title: 'Espaço de Trabalho',
			summary: 'Assistentes personalizados, prompts, ferramentas, skills e funções.',
			link: '/workspace/models',
			blocks: [
				['h', 'Modelos (assistentes personalizados)'],
				[
					'steps',
					[
						'**Espaço de Trabalho** → **Modelos** → **+**.',
						'Escolha o **modelo base** (um dos modelos do Ollama).',
						'Escreva o **prompt do sistema**: quem o assistente é e como deve responder.',
						'Ligue bases de **conhecimento**, **ferramentas** e **capacidades** (visão, pesquisa na web, imagem…).',
						'Em **Parâmetros Avançados**, ajuste temperatura, tamanho do contexto e o modo de chamada de ferramentas.',
						'Salve. O assistente aparece no seletor de modelos para quem tiver acesso.'
					]
				],
				['h', 'Prompts'],
				[
					'p',
					'Textos prontos que você chama com `/` no chat. Podem ter variáveis, como `{{nome}}`, que o my-local-ia pergunta antes de enviar.'
				],
				['h', 'Ferramentas, skills e funções'],
				[
					'bullets',
					[
						'**Ferramentas**: código Python que a IA pode chamar (consultar uma API, ler uma planilha…).',
						'**Skills**: instruções e arquivos que ensinam a IA a fazer uma tarefa específica.',
						'**Funções** (Painel do Admin): filtros e ações que mudam o comportamento do chat para todos.'
					]
				],
				[
					'warn',
					'Ferramentas e funções executam código no servidor. Instale só código de fontes em que você confia e revise antes de ativar.'
				]
			]
		},
		{
			id: 'more',
			title: 'Notas, canais, calendário e automações',
			summary: 'Outros espaços do Open WebUI além do chat.',
			link: '/notes',
			blocks: [
				[
					'bullets',
					[
						'**Notas**: um editor de textos com a IA do lado para resumir, reescrever e continuar. Dá para anexar notas nas conversas.',
						'**Canais**: salas de conversa da equipe, onde dá para chamar um modelo com `@`. Aparecem quando o administrador ativa.',
						'**Calendário**: eventos que a IA pode consultar e criar (quando ativado).',
						'**Automações**: prompts que rodam sozinhos num horário, como um resumo diário (quando ativado).',
						'**Playground**: área de testes para administradores, com completions e geração de imagens.'
					]
				],
				[
					'note',
					'Canais, calendário e automações ficam escondidos até um administrador ativar em **Painel do Admin → Configurações → Geral**.'
				]
			]
		},
		{
			id: 'settings',
			title: 'Suas configurações',
			summary: 'Idioma, tema, memória, voz, notificações e conta.',
			link: '/?settings=general',
			blocks: [
				[
					'table',
					['Aba', 'O que tem'],
					[
						[
							'Geral',
							'Idioma, tema (claro, escuro, sistema), prompt do sistema e parâmetros padrão.'
						],
						[
							'Interface',
							'Aparência do chat, comportamento do Enter, sugestões, títulos automáticos.'
						],
						['Notificações', 'Avisos quando uma resposta termina com a aba em segundo plano.'],
						['Teclado', 'Lista de atalhos.'],
						['Integrações', 'Ferramentas e servidores externos ligados à sua conta.'],
						['Personalização', 'Memória: fatos sobre você que a IA lembra em todas as conversas.'],
						['Áudio', 'Voz para ler respostas e o reconhecimento de fala.'],
						['Controle de Dados', 'Exportar, importar e apagar conversas.'],
						['Uso', 'Quanto você usou de cada modelo.'],
						['Conta', 'Nome, foto, senha e chaves de API.']
					]
				],
				[
					'tip',
					'A memória ajuda a IA a lembrar preferências ("responda sempre em português", "sou contador"). Você vê e apaga cada lembrança em **Personalização**.'
				]
			]
		},
		{
			id: 'admin',
			title: 'Administração',
			summary: 'Usuários, grupos, permissões e as configurações do servidor.',
			link: '/admin/users',
			admin: true,
			blocks: [
				['h', 'Usuários e grupos'],
				[
					'bullets',
					[
						'**Painel do Admin → Usuários**: criar contas (+), mudar a função (**pending**, **user**, **admin**), redefinir senha e excluir.',
						'Novos cadastros ficam **pendentes** até você aprovar.',
						'**Grupos**: reúna pessoas e dê permissões e acesso a modelos, bases de conhecimento e ferramentas por grupo.'
					]
				],
				['h', 'Configurações do servidor (Painel do Admin → Configurações)'],
				[
					'table',
					['Aba', 'Para que serve'],
					[
						[
							'Geral',
							'Cadastro aberto ou fechado, função padrão de novos usuários, recursos como canais, notas e calendário.'
						],
						['Autenticação', 'Login com Google, Microsoft, LDAP e outros.'],
						['Interface', 'Banners, sugestões de prompt e modelos de tarefa (títulos, tags).'],
						['Conexões', 'Endereço do Ollama e conexões com APIs compatíveis com OpenAI.'],
						['Modelos', 'Quem vê cada modelo, nomes, ícones e parâmetros padrão.'],
						[
							'Documentos',
							'Modelo de embeddings, tamanho dos trechos e como os arquivos são lidos.'
						],
						['Pesquisa na Web', 'Mecanismo de busca usado pela ferramenta de pesquisa.'],
						['Áudio', 'Reconhecimento de fala (Whisper) e voz.'],
						['Imagens', 'Gerador de imagens (ComfyUI, Automatic1111, OpenAI…).'],
						['Execução de Código', 'Onde o intérprete de código roda.'],
						['Análises e Avaliações', 'Uso por modelo e as avaliações (boa/ruim) das respostas.'],
						['Banco de Dados', 'Exportar o banco e importar configurações.']
					]
				],
				[
					'warn',
					'Para atualizar o my-local-ia, use o instalador (**Atualizar**), não o aviso de "nova versão" do Open WebUI: ele leva para o projeto original, sem as funções do my-local-ia.'
				]
			]
		},
		{
			id: 'ollama',
			title: 'Ollama',
			summary: 'O motor que roda os modelos: comandos e ajustes úteis.',
			blocks: [
				[
					'p',
					'O **Ollama** baixa e executa os modelos. Ele carrega cada modelo na memória da placa de vídeo (VRAM) e, se não couber, usa também a RAM, que é bem mais lenta. Os comandos abaixo rodam no terminal do servidor.'
				],
				[
					'table',
					['Comando', 'O que faz'],
					[
						['`ollama list`', 'Lista os modelos instalados e o tamanho de cada um.'],
						[
							'`ollama ps`',
							'Mostra os modelos carregados agora e quanto está na GPU e na CPU (ex.: 100% GPU).'
						],
						['`ollama pull qwen3:8b`', 'Baixa um modelo (o my-local-ia faz isso pelo catálogo).'],
						['`ollama run qwen3:8b`', 'Conversa com o modelo direto no terminal.'],
						[
							'`ollama show qwen3:8b`',
							'Detalhes: parâmetros, contexto, capacidades (visão, ferramentas, raciocínio).'
						],
						['`ollama stop qwen3:8b`', 'Descarrega o modelo da memória.'],
						['`ollama rm qwen3:8b`', 'Apaga o modelo do disco.']
					]
				],
				['h', 'Como ler o ollama ps'],
				[
					'bullets',
					[
						'**100% GPU**: o modelo inteiro está na placa de vídeo. É o mais rápido.',
						'**10%/90% CPU/GPU**: uma parte ficou na RAM e a velocidade cai bastante. Prefira um modelo menor ou com menos contexto.',
						'**CONTEXT**: quantos tokens de conversa o modelo aceita. Contexto maior ocupa mais memória.',
						'**UNTIL**: quando o modelo sai da memória se ninguém usar.'
					]
				],
				['h', 'Ajustes do serviço'],
				[
					'p',
					'No Linux, os ajustes vão no serviço do Ollama: rode `sudo systemctl edit ollama`, adicione as linhas abaixo e reinicie com `sudo systemctl restart ollama`.'
				],
				[
					'code',
					[
						'[Service]',
						'Environment="OLLAMA_KEEP_ALIVE=30m"        # tempo que o modelo fica carregado',
						'Environment="OLLAMA_CONTEXT_LENGTH=8192"   # contexto padrão',
						'Environment="OLLAMA_MAX_LOADED_MODELS=2"   # modelos na memória ao mesmo tempo',
						'Environment="OLLAMA_NUM_PARALLEL=2"        # respostas simultâneas por modelo',
						'Environment="OLLAMA_FLASH_ATTENTION=1"     # menos memória para o contexto',
						'Environment="OLLAMA_KV_CACHE_TYPE=q8_0"    # contexto comprimido (precisa do anterior)'
					]
				],
				[
					'tip',
					'O instalador faz os dois ajustes que mais economizam memória por você: rode `sudo bash install-my-local-ia.sh` e escolha **8) Otimizar o Ollama** (flash attention e contexto comprimido `q8_0`). Rodando de novo, dá para desfazer.'
				],
				[
					'tip',
					'Na placa de 12 GB, um modelo de 7–8B com contexto de 8 mil tokens cabe inteiro na GPU. Modelos de 14B cabem com contexto menor; de 20B para cima, parte vai para a RAM.'
				],
				[
					'note',
					'A primeira resposta depois de um tempo parado demora mais: o Ollama está carregando o modelo do disco para a memória.'
				],
				['h', 'Desbloqueio da placa (gpu-unlock)'],
				[
					'p',
					'As GeForce RTX 20, 30 e 40 fazem as contas FP16/BF16/TF32 dos tensor cores na metade da velocidade. O instalador, na opção **9) Desbloquear os tensor cores da placa**, instala o gpu-unlock, que devolve a velocidade cheia a cada inicialização, sem mudar o driver.'
				],
				[
					'table',
					['Uso', 'Ganho'],
					[
						['Geração de imagens, fine-tuning, PyTorch FP16/BF16', '25 a 55%'],
						['Ollama lendo prompts longos', '0 a 15%'],
						['Ollama gerando tokens', 'nenhum']
					]
				],
				[
					'warn',
					'Numa VM do Proxmox, a placa precisa chegar como PCIe: no host, `qm set <VMID> --hostpci0 <endereço>,pcie=1`. Para o chat, o ganho é pequeno; vale mais para imagens e PyTorch. Detalhes no guia de instalação.'
				]
			]
		},
		{
			id: 'catalog',
			title: 'my-local-ia: catálogo e downloads',
			summary: 'Descobrir o que roda bem aqui e baixar sem sair da página.',
			link: '/my-local-ia',
			blocks: [
				[
					'img',
					'catalog',
					'Catálogo: hardware detectado, notas e as melhores escolhas para este servidor.'
				],
				[
					'table',
					['Nota', 'Significado'],
					[
						['Roda liso', 'Cabe na placa de vídeo e responde rápido.'],
						['Usável', 'Funciona, mas mais devagar ou no limite da memória da placa.'],
						['Pesado', 'Não cabe inteiro na placa: parte vai para a RAM, que é bem mais lenta.'],
						['Não roda', 'Precisa de mais memória do que o servidor tem.']
					]
				],
				[
					'bullets',
					[
						'**Melhores para este servidor**: uma escolha por tarefa, recalculada para o seu hardware.',
						'**Cabe neste servidor** (ligado por padrão): mostra só o que roda liso ou é usável. Desligue para ver todos.',
						'**Filtros**: chat, raciocínio, visão, código, imagem, vídeo, fala, embeddings, leves, novos e instalados. A busca aceita nome ou uso.',
						'O **robô** procura modelos novos todo dia na biblioteca oficial do Ollama e no Hugging Face (até 300), com os que rodam bem aqui primeiro.'
					]
				],
				['h', 'Baixar um modelo'],
				[
					'steps',
					[
						'Clique em **Baixar (tamanho)** no cartão do modelo.',
						'O my-local-ia confere o disco e mostra como ele vai ficar depois. Se não couber, oferece um modelo menor parecido ou liberar espaço removendo modelos sem uso.',
						'Clique em **Baixar**. Você pode fechar a janela e mudar de página: o download continua no servidor.',
						'O progresso aparece embaixo de **Disco do servidor**, no menu lateral, para todos. Quando termina, o modelo já está no seletor.'
					]
				],
				[
					'img',
					'downloads',
					'Download em segundo plano: o progresso fica embaixo do medidor de disco.'
				],
				[
					'note',
					'Administradores baixam qualquer modelo. Usuários baixam modelos do catálogo se o administrador permitir. Ninguém consegue baixar algo que passe do limite do disco.'
				]
			]
		},
		{
			id: 'warnings',
			title: 'my-local-ia: avisos no chat',
			summary: 'Aviso de modelo pesado, "Antes de enviar" e o modo de ferramentas automático.',
			link: '/',
			blocks: [
				[
					'img',
					'heavy-warning',
					'Aviso ao escolher um modelo pesado, com uma alternativa que roda bem.'
				],
				[
					'bullets',
					[
						'**Seletor de modelos**: cada modelo instalado mostra a nota dele neste servidor.',
						'**Aviso de modelo pesado**: ao escolher um modelo pesado ou que não roda, aparece o motivo e um modelo do mesmo tipo que roda bem. Escolha **Trocar**, **Usar mesmo assim** ou **Cancelar**.',
						'**Antes de enviar**: ao anexar imagem, PDF ou áudio, diz se o modelo lê aquele arquivo e quanto tempo vai levar lendo.'
					]
				],
				['img', 'before-send', 'Antes de enviar: o modelo escolhido não lê imagens.'],
				['h', 'Modo de ferramentas automático'],
				[
					'p',
					'O Open WebUI manda ferramentas (calendário, notas, memória…) junto com cada mensagem. Modelos que não sabem usar ferramentas respondiam com um bloco de JSON em vez do texto. O my-local-ia desliga as ferramentas sozinho para esses modelos (qwen2.5-coder, os menores de 4B e os sem suporte) e as mantém nos que usam bem, como gpt-oss, qwen3 e llama3.1.'
				],
				[
					'tip',
					'Para forçar um modo: **Espaço de Trabalho → Modelos → editar → Parâmetros Avançados → Function Calling** (Native = com ferramentas; Legacy = sem).'
				]
			]
		},
		{
			id: 'simulator',
			title: 'my-local-ia: simulador',
			summary: 'Comparar até 3 modelos antes de baixar.',
			link: '/my-local-ia/simulator',
			blocks: [
				['img', 'simulator', 'Simulador comparando 3 modelos com a mesma pergunta.'],
				[
					'steps',
					[
						'Escolha o que você vai mandar: **pergunta de texto**, **imagem**, **PDF** ou **áudio**.',
						'Escolha 1, 2 ou 3 modelos, instalados ou do catálogo.',
						'Escolha **Tempo real** ou **5× mais rápido** e clique em **Começar simulação**.'
					]
				],
				[
					'p',
					'Cada coluna mostra quando o modelo começa a responder, em que velocidade escreve e quando termina. O texto é sempre o mesmo exemplo: o simulador mede tempo, não a qualidade da resposta.'
				]
			]
		},
		{
			id: 'disk',
			title: 'my-local-ia: espaço em disco',
			summary: 'O que ocupa o disco, alertas e como liberar espaço.',
			link: '/my-local-ia/disk',
			blocks: [
				['img', 'disk', 'Espaço em disco: uso total, divisão por tipo e modelos instalados.'],
				[
					'bullets',
					[
						'A barra separa **modelos de IA**, **Open WebUI** (conversas, arquivos, documentos), **sistema** e **livre**. As linhas tracejadas são os limites de atenção, crítico e bloqueio.',
						'Quando o uso cresce, a página prevê em quantos dias o disco chega ao limite.',
						'A tabela mostra cada modelo com tamanho, nota, último uso, respostas em 30 dias, quem baixou e uma sugestão (sem uso, pesado, pouco usado).',
						'Marque modelos e clique em **Remover marcados**. A barra mostra antes como o disco vai ficar.'
					]
				],
				[
					'note',
					'Administradores removem qualquer modelo; usuários só os que eles mesmos baixaram e ninguém usou recentemente. O modelo da busca em documentos fica protegido.'
				]
			]
		},
		{
			id: 'mli-settings',
			title: 'my-local-ia: configurações',
			summary: 'Hardware, downloads, alertas de disco e o robô de modelos.',
			link: '/my-local-ia/settings',
			admin: true,
			blocks: [
				[
					'img',
					'settings',
					'Configurações do my-local-ia: hardware detectado, downloads e alertas.'
				],
				[
					'bullets',
					[
						'**Hardware**: detectado ao iniciar e conferido a cada poucos minutos. **Detectar de novo** mostra o que mudou; **Ajustar manualmente** corrige a VRAM, a RAM ou as velocidades.',
						'**Downloads**: liga ou desliga o download pelos usuários.',
						'**Alertas de disco**: limites de atenção, crítico e bloqueio, faixa no topo para todos e webhook (Discord, Slack, Teams, Google Chat).',
						'**Robô de modelos novos**: frequência, horário, mínimo de downloads, máximo de modelos (300), biblioteca do Ollama e perfis do Hugging Face. **Procurar agora** roda na hora.'
					]
				]
			]
		},
		{
			id: 'faq',
			title: 'Dúvidas frequentes',
			summary: 'Respostas lentas, JSON no lugar do texto, memória e mais.',
			blocks: [
				[
					'table',
					['Pergunta', 'Resposta'],
					[
						[
							'A resposta está muito lenta.',
							'O modelo provavelmente não cabe na placa de vídeo. Veja a nota dele no catálogo e rode `ollama ps`: se não estiver 100% GPU, use um modelo menor.'
						],
						[
							'A primeira resposta demora e as seguintes são rápidas.',
							'É o tempo de carregar o modelo na memória. Aumente `OLLAMA_KEEP_ALIVE` para ele ficar carregado mais tempo.'
						],
						[
							'O modelo respondeu com um bloco de JSON.',
							'Ele tentou usar uma ferramenta que não sabe usar. O my-local-ia já desliga as ferramentas desses modelos; se acontecer com outro, mude **Function Calling** para **Legacy** nos parâmetros do modelo.'
						],
						[
							'A IA "esqueceu" o começo de uma conversa longa.',
							'O contexto acabou. Aumente o contexto nos Controles do chat ou comece uma conversa nova com um resumo.'
						],
						[
							'O modelo não lê minha imagem.',
							'Ele não é um modelo de visão. Escolha um com a etiqueta Visão no catálogo (como Qwen3-VL ou Gemma 3).'
						],
						[
							'O download parou.',
							'Veja o painel de downloads no menu lateral. Se falhou, baixe de novo: o Ollama continua de onde parou.'
						],
						[
							'Esqueci minha senha.',
							'Peça a um administrador: Painel do Admin → Usuários, ou o instalador (opção Redefinir a senha).'
						]
					]
				]
			]
		}
	]
};
