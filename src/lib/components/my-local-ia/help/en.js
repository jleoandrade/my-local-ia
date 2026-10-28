// my-local-ia help in English. The same content builds the help page and the Word manual.
// Blocks: ['p', text], ['h', heading], ['steps', [...]], ['bullets', [...]], ['tip'|'note'|'warn', text],
// ['img', name, caption], ['code', [lines]], ['table', header, rows].
// In texts, **bold** and `code`.
export default {
	title: 'my-local-ia help',
	subtitle: 'How to use Open WebUI, Ollama and the my-local-ia features',
	intro:
		'my-local-ia brings three things together: **Ollama**, which runs the AI models on the server; **Open WebUI**, the chat interface you use in the browser; and the **my-local-ia** features, which show what runs well on your hardware, look after the disk and make downloads easy. Pick a topic below.',
	open: 'Open',
	adminOnly: 'Administrators only',
	search: 'Search the help…',
	noResults: 'Nothing found. Try another word.',
	sections: [
		{
			id: 'start',
			title: 'Getting started',
			summary: 'Sign in, get to know the screen and choose the language.',
			link: '/',
			blocks: [
				[
					'steps',
					[
						'Open **http://SERVER-IP:4000** in the browser of any computer or phone on the network.',
						'Sign in with your e-mail and password. If you just signed up, wait for an administrator to approve the account.',
						'Pick a model at the top of the chat (or on the button next to the message box) and type your question.'
					]
				],
				['img', 'chat', 'Home screen: sidebar on the left, message box and model selector.'],
				[
					'table',
					['Part of the screen', 'What it is for'],
					[
						[
							'Sidebar',
							'New chat, search, my-local-ia, notes, workspace, folders and the chat history.'
						],
						[
							'Server disk',
							'At the bottom of the sidebar: how full the disk is and the downloads in progress.'
						],
						[
							'Model selector',
							'Chooses which AI answers. The colored label shows how it runs on this server.'
						],
						['Message box', 'Where you type, attach files, turn on tools and use your voice.'],
						[
							'Your picture (bottom)',
							'Settings, archived chats, Admin Panel (administrators) and sign out.'
						]
					]
				],
				[
					'tip',
					'To change the language: profile picture → **Settings** → **General** → **Language**. The interface is fully available in English, Portuguese and Spanish.'
				],
				[
					'p',
					'To open this help from anywhere, click **Help** at the top of the my-local-ia pages.'
				]
			]
		},
		{
			id: 'chat',
			title: 'Chatting with the AI',
			summary: 'Send messages, attach files, use your voice and compare models.',
			link: '/',
			blocks: [
				['h', 'Sending a message'],
				[
					'steps',
					[
						'Click **New Chat** in the sidebar.',
						'Pick the model. If it is heavy for this server, my-local-ia warns you and suggests a lighter one.',
						'Type and press **Enter** (for a new line without sending: **Shift + Enter**).',
						'The answer appears as it is written. To stop it, click the stop button.'
					]
				],
				['h', 'The + button (attachments)'],
				[
					'bullets',
					[
						'**Upload Files**: PDF, Word, spreadsheets, text, images and audio. The content goes with the question.',
						'**Capture**: takes a screenshot and attaches it.',
						'**Attach Webpage**: paste an address and the page text joins the chat.',
						'**Attach notes, knowledge and chats**: uses your notes, knowledge bases or older chats as context.'
					]
				],
				[
					'note',
					'Before you send an attachment, the **Before sending** box says whether the selected model reads that kind of file and how long it will take to read it.'
				],
				['h', 'Tools (integrations button)'],
				[
					'bullets',
					[
						'**Web Search**: the AI searches the internet before answering (an administrator must turn it on).',
						'**Image**: generates images from text (needs an image generator set up).',
						'**Code Interpreter**: the AI writes and runs Python code for calculations, charts and spreadsheet analysis.',
						'**Tools and Skills**: extra tools installed in the Workspace.'
					]
				],
				['h', 'Shortcuts in the message box'],
				[
					'table',
					['Type', 'What happens'],
					[
						['`@`', 'Calls another model for the next message only.'],
						['`/`', 'Uses a saved prompt (see Workspace → Prompts).'],
						['`#`', 'Attaches a knowledge base or a file.'],
						['`$`', 'Uses a skill.'],
						['`:`', 'Inserts an emoji.']
					]
				],
				['h', 'Voice'],
				[
					'bullets',
					[
						'**Dictate** (microphone): speak and the text appears in the box; transcription happens here on the server.',
						'**Call / voice mode**: a spoken conversation, with the answer read aloud.'
					]
				],
				['h', 'Actions on each answer'],
				[
					'bullets',
					[
						'**Copy**, **Edit** your question or the answer, **Read Aloud**.',
						'**Regenerate**: another answer to the same question (versions are kept and you can switch between them).',
						'**Continue Response**: when the answer was cut off.',
						'**Good Response / Bad Response**: ratings the administrator sees in Evaluations.'
					]
				],
				['h', 'Comparing models and other options'],
				[
					'bullets',
					[
						'**Several models**: in the selector, click **+** to add another model; each answers side by side.',
						'**Temporary Chat**: not saved in the history.',
						'**Controls** (icon at the top right): system prompt and parameters such as temperature and context size for this chat only.'
					]
				]
			]
		},
		{
			id: 'organize',
			title: 'Organizing chats',
			summary: 'Search, folders, pin, archive, share and export.',
			link: '/',
			blocks: [
				[
					'bullets',
					[
						'**Search** (sidebar): looks through all your chats.',
						'**Folders**: click **+** next to Folders and drag chats into it. A folder can have its own instructions and files.',
						'**Menu of each chat** (three dots): rename, pin to the top, archive, share, download (text, PDF or JSON), move and delete.',
						'**Tags**: labels the AI suggests that you can use in the search.',
						'**Archived chats**: Settings → **Archived Chats**, to bring them back or delete them for good.',
						'**Export or import everything**: Settings → **Data Controls**.'
					]
				],
				[
					'warn',
					'A share link gives access to the chat to anyone with a my-local-ia account. Do not share chats with sensitive data.'
				]
			]
		},
		{
			id: 'knowledge',
			title: 'Documents and knowledge bases',
			summary: 'Make the AI answer from your own files.',
			link: '/workspace/knowledge',
			blocks: [
				[
					'p',
					'A **knowledge base** is a folder of documents the AI looks up to answer. The text is split into chunks and indexed by an **embeddings** model; for each question only the most similar chunks go to the model.'
				],
				[
					'steps',
					[
						'Open **Workspace** → **Knowledge** → **+**.',
						'Give it a name and a description and choose who can see it.',
						'Upload the files (PDF, Word, text, spreadsheets…) or a whole folder.',
						'In the chat, type `#` and pick the base, or attach the base to a custom model so it is always used.'
					]
				],
				[
					'tip',
					'For documents in Portuguese and Spanish, a multilingual embeddings model (such as **BGE-M3**, recommended in the catalog) gives much better results.'
				],
				[
					'note',
					'A file attached straight to a chat is read too, but only in that chat. Use knowledge bases for documents you will look up many times.'
				]
			]
		},
		{
			id: 'workspace',
			title: 'Workspace',
			summary: 'Custom assistants, prompts, tools, skills and functions.',
			link: '/workspace/models',
			blocks: [
				['h', 'Models (custom assistants)'],
				[
					'steps',
					[
						'**Workspace** → **Models** → **+**.',
						'Choose the **base model** (one of the Ollama models).',
						'Write the **system prompt**: who the assistant is and how it should answer.',
						'Attach **knowledge** bases, **tools** and **capabilities** (vision, web search, image…).',
						'In **Advanced Params**, adjust temperature, context size and the tool calling mode.',
						'Save. The assistant shows up in the model selector for everyone with access.'
					]
				],
				['h', 'Prompts'],
				[
					'p',
					'Ready-made texts you call with `/` in the chat. They can have variables, such as `{{name}}`, that my-local-ia asks for before sending.'
				],
				['h', 'Tools, skills and functions'],
				[
					'bullets',
					[
						'**Tools**: Python code the AI can call (query an API, read a spreadsheet…).',
						'**Skills**: instructions and files that teach the AI a specific task.',
						'**Functions** (Admin Panel): filters and actions that change how the chat works for everyone.'
					]
				],
				[
					'warn',
					'Tools and functions run code on the server. Install only code from sources you trust and review it before turning it on.'
				]
			]
		},
		{
			id: 'more',
			title: 'Notes, channels, calendar and automations',
			summary: 'Other Open WebUI spaces besides the chat.',
			link: '/notes',
			blocks: [
				[
					'bullets',
					[
						'**Notes**: a text editor with the AI at your side to summarize, rewrite and continue. Notes can be attached to chats.',
						'**Channels**: team chat rooms where you can call a model with `@`. They show up when an administrator turns them on.',
						'**Calendar**: events the AI can look up and create (when turned on).',
						'**Automations**: prompts that run on their own at a set time, such as a daily summary (when turned on).',
						'**Playground**: a test area for administrators, with completions and image generation.'
					]
				],
				[
					'note',
					'Channels, calendar and automations stay hidden until an administrator turns them on in **Admin Panel → Settings → General**.'
				]
			]
		},
		{
			id: 'settings',
			title: 'Your settings',
			summary: 'Language, theme, memory, voice, notifications and account.',
			link: '/?settings=general',
			blocks: [
				[
					'table',
					['Tab', 'What is there'],
					[
						[
							'General',
							'Language, theme (light, dark, system), system prompt and default parameters.'
						],
						['Interface', 'Chat appearance, Enter key behavior, suggestions, automatic titles.'],
						['Notifications', 'Alerts when an answer finishes while the tab is in the background.'],
						['Keyboard', 'List of shortcuts.'],
						['Integrations', 'Tools and external servers connected to your account.'],
						['Personalization', 'Memory: facts about you the AI remembers in every chat.'],
						['Audio', 'Voice that reads answers and speech recognition.'],
						['Data Controls', 'Export, import and delete chats.'],
						['Usage', 'How much you used each model.'],
						['Account', 'Name, picture, password and API keys.']
					]
				],
				[
					'tip',
					'Memory helps the AI remember preferences ("always answer in English", "I am an accountant"). You see and delete each memory in **Personalization**.'
				]
			]
		},
		{
			id: 'admin',
			title: 'Administration',
			summary: 'Users, groups, permissions and the server settings.',
			link: '/admin/users',
			admin: true,
			blocks: [
				['h', 'Users and groups'],
				[
					'bullets',
					[
						'**Admin Panel → Users**: create accounts (+), change the role (**pending**, **user**, **admin**), reset the password and delete.',
						'New sign-ups stay **pending** until you approve them.',
						'**Groups**: gather people and grant permissions and access to models, knowledge bases and tools per group.'
					]
				],
				['h', 'Server settings (Admin Panel → Settings)'],
				[
					'table',
					['Tab', 'What it is for'],
					[
						[
							'General',
							'Open or closed sign-up, default role of new users, features such as channels, notes and calendar.'
						],
						['Authentication', 'Sign in with Google, Microsoft, LDAP and others.'],
						['Interface', 'Banners, prompt suggestions and task models (titles, tags).'],
						['Connections', 'Ollama address and connections to OpenAI-compatible APIs.'],
						['Models', 'Who sees each model, names, icons and default parameters.'],
						['Documents', 'Embeddings model, chunk size and how files are read.'],
						['Web Search', 'Search engine used by the search tool.'],
						['Audio', 'Speech recognition (Whisper) and voice.'],
						['Images', 'Image generator (ComfyUI, Automatic1111, OpenAI…).'],
						['Code Execution', 'Where the code interpreter runs.'],
						['Analytics and Evaluations', 'Usage per model and the good/bad ratings of answers.'],
						['Database', 'Export the database and import settings.']
					]
				],
				[
					'warn',
					'To update my-local-ia, use the installer (**Update**), not Open WebUI\'s "new version" notice: it points to the original project, without the my-local-ia features.'
				]
			]
		},
		{
			id: 'ollama',
			title: 'Ollama',
			summary: 'The engine that runs the models: useful commands and settings.',
			blocks: [
				[
					'p',
					'**Ollama** downloads and runs the models. It loads each model into the GPU memory (VRAM) and, when it does not fit, uses system RAM too, which is much slower. The commands below run in the server terminal.'
				],
				[
					'table',
					['Command', 'What it does'],
					[
						['`ollama list`', 'Lists the installed models and the size of each.'],
						[
							'`ollama ps`',
							'Shows the models loaded now and how much is on the GPU and the CPU (e.g. 100% GPU).'
						],
						['`ollama pull qwen3:8b`', 'Downloads a model (my-local-ia does it from the catalog).'],
						['`ollama run qwen3:8b`', 'Chats with the model right in the terminal.'],
						[
							'`ollama show qwen3:8b`',
							'Details: parameters, context, capabilities (vision, tools, thinking).'
						],
						['`ollama stop qwen3:8b`', 'Unloads the model from memory.'],
						['`ollama rm qwen3:8b`', 'Deletes the model from the disk.']
					]
				],
				['h', 'Reading ollama ps'],
				[
					'bullets',
					[
						'**100% GPU**: the whole model is on the GPU. The fastest.',
						'**10%/90% CPU/GPU**: part stayed in RAM and the speed drops a lot. Prefer a smaller model or less context.',
						'**CONTEXT**: how many tokens of conversation the model takes. More context takes more memory.',
						'**UNTIL**: when the model leaves memory if nobody uses it.'
					]
				],
				['h', 'Service settings'],
				[
					'p',
					'On Linux, the settings go in the Ollama service: run `sudo systemctl edit ollama`, add the lines below and restart with `sudo systemctl restart ollama`.'
				],
				[
					'code',
					[
						'[Service]',
						'Environment="OLLAMA_KEEP_ALIVE=30m"        # how long a model stays loaded',
						'Environment="OLLAMA_CONTEXT_LENGTH=8192"   # default context',
						'Environment="OLLAMA_MAX_LOADED_MODELS=2"   # models in memory at the same time',
						'Environment="OLLAMA_NUM_PARALLEL=2"        # simultaneous answers per model',
						'Environment="OLLAMA_FLASH_ATTENTION=1"     # less memory for the context',
						'Environment="OLLAMA_KV_CACHE_TYPE=q8_0"    # compressed context (needs the line above)'
					]
				],
				[
					'tip',
					'The installer applies the two settings that save the most memory for you: run `sudo bash install-my-local-ia.sh` and choose **8) Optimize Ollama** (flash attention and the compressed `q8_0` context). Run it again to undo.'
				],
				[
					'tip',
					'On a 12 GB GPU, a 7–8B model with an 8 thousand token context fits entirely on the GPU. 14B models fit with less context; from 20B up, part goes to RAM.'
				],
				[
					'note',
					'The first answer after a while is slower: Ollama is loading the model from disk into memory.'
				],
				['h', 'GPU unlock (gpu-unlock)'],
				[
					'p',
					'GeForce RTX 20, 30 and 40 cards run FP16/BF16/TF32 tensor math at half speed. Option **9) Unlock the GPU tensor cores** of the installer installs gpu-unlock, which restores the full rate at every boot without changing the driver.'
				],
				[
					'table',
					['Use', 'Gain'],
					[
						['Image generation, fine-tuning, PyTorch FP16/BF16', '25 to 55%'],
						['Ollama reading long prompts', '0 to 15%'],
						['Ollama generating tokens', 'none']
					]
				],
				[
					'warn',
					'In a Proxmox VM, the GPU must arrive as PCIe: on the host, `qm set <VMID> --hostpci0 <address>,pcie=1`. For chat the gain is small; it pays off for images and PyTorch. Details in the installation guide.'
				]
			]
		},
		{
			id: 'catalog',
			title: 'my-local-ia: catalog and downloads',
			summary: 'Find out what runs well here and download without leaving the page.',
			link: '/my-local-ia',
			blocks: [
				[
					'img',
					'catalog',
					'Catalog: detected hardware, ratings and the best picks for this server.'
				],
				[
					'table',
					['Rating', 'Meaning'],
					[
						['Runs smoothly', 'Fits in the GPU memory and answers fast.'],
						['Usable', 'Works, but slower or at the limit of the GPU memory.'],
						['Heavy', 'Does not fit entirely in the GPU: part goes to RAM, which is much slower.'],
						["Won't run", 'Needs more memory than the server has.']
					]
				],
				[
					'bullets',
					[
						'**Best for this server**: one pick per task, recalculated for your hardware.',
						'**Fits this server** (on by default): shows only what runs smoothly or is usable. Turn it off to see everything.',
						'**Filters**: chat, reasoning, vision, code, image, video, speech, embeddings, light, new and installed. The search takes a name or a use.',
						'The **robot** looks for new models every day in the official Ollama library and on Hugging Face (up to 300), with the ones that run well here first.'
					]
				],
				['h', 'Downloading a model'],
				[
					'steps',
					[
						'Click **Download (size)** on the model card.',
						'my-local-ia checks the disk and shows how it will look afterwards. If it does not fit, it offers a similar, smaller model or freeing space by removing unused models.',
						'Click **Download**. You can close the window and change pages: the download goes on on the server.',
						'The progress shows under **Server disk** in the sidebar, for everyone. When it finishes, the model is already in the selector.'
					]
				],
				['img', 'downloads', 'Background download: the progress stays under the disk meter.'],
				[
					'note',
					'Administrators download any model. Users download catalog models if the administrator allows it. Nobody can download something that goes over the disk limit.'
				]
			]
		},
		{
			id: 'warnings',
			title: 'my-local-ia: warnings in the chat',
			summary: 'Heavy model warning, "Before sending" and the automatic tool mode.',
			link: '/',
			blocks: [
				[
					'img',
					'heavy-warning',
					'Warning when picking a heavy model, with an alternative that runs well.'
				],
				[
					'bullets',
					[
						'**Model selector**: each installed model shows its rating on this server.',
						'**Heavy model warning**: picking a heavy model, or one that will not run, shows the reason and a model of the same kind that runs well. Choose **Switch**, **Use it anyway** or **Cancel**.',
						'**Before sending**: when you attach an image, PDF or audio, it says whether the model reads that file and how long it will take to read it.'
					]
				],
				['img', 'before-send', 'Before sending: the selected model does not read images.'],
				['h', 'Automatic tool mode'],
				[
					'p',
					'Open WebUI sends tools (calendar, notes, memory…) with every message. Models that cannot use tools used to answer with a block of JSON instead of text. my-local-ia turns the tools off by itself for those models (qwen2.5-coder, the ones under 4B and the ones without support) and keeps them on for the ones that use them well, such as gpt-oss, qwen3 and llama3.1.'
				],
				[
					'tip',
					'To force a mode: **Workspace → Models → edit → Advanced Params → Function Calling** (Native = with tools; Legacy = without).'
				]
			]
		},
		{
			id: 'simulator',
			title: 'my-local-ia: simulator',
			summary: 'Compare up to 3 models before downloading.',
			link: '/my-local-ia/simulator',
			blocks: [
				['img', 'simulator', 'Simulator comparing 3 models with the same question.'],
				[
					'steps',
					[
						'Choose what you will send: **text question**, **image**, **PDF** or **audio**.',
						'Choose 1, 2 or 3 models, installed or from the catalog.',
						'Choose **Real time** or **5× faster** and click **Start simulation**.'
					]
				],
				[
					'p',
					'Each column shows when the model starts answering, how fast it writes and when it finishes. The text is always the same sample: the simulator measures time, not answer quality.'
				]
			]
		},
		{
			id: 'disk',
			title: 'my-local-ia: disk space',
			summary: 'What fills the disk, alerts and how to free space.',
			link: '/my-local-ia/disk',
			blocks: [
				['img', 'disk', 'Disk space: total use, split by kind and installed models.'],
				[
					'bullets',
					[
						'The bar splits **AI models**, **Open WebUI** (chats, files, documents), **system** and **free**. The dashed lines are the attention, critical and block limits.',
						'When usage grows, the page forecasts in how many days the disk reaches the limit.',
						'The table shows each model with size, rating, last use, answers in 30 days, who downloaded it and a suggestion (unused, heavy, rarely used).',
						'Tick models and click **Remove selected**. The bar shows beforehand how the disk will look.'
					]
				],
				[
					'note',
					'Administrators remove any model; users only the ones they downloaded and nobody used recently. The document search model is protected.'
				]
			]
		},
		{
			id: 'mli-settings',
			title: 'my-local-ia: settings',
			summary: 'Hardware, downloads, disk alerts and the model robot.',
			link: '/my-local-ia/settings',
			admin: true,
			blocks: [
				['img', 'settings', 'my-local-ia settings: detected hardware, downloads and alerts.'],
				[
					'bullets',
					[
						'**Hardware**: detected at startup and checked every few minutes. **Detect again** shows what changed; **Adjust manually** corrects VRAM, RAM or speeds.',
						'**Downloads**: turns user downloads on or off.',
						'**Disk alerts**: attention, critical and block limits, a banner at the top for everyone and a webhook (Discord, Slack, Teams, Google Chat).',
						'**Robot for new models**: frequency, time, minimum downloads, maximum models (300), the Ollama library and the Hugging Face profiles. **Search now** runs it right away.'
					]
				]
			]
		},
		{
			id: 'faq',
			title: 'Frequently asked questions',
			summary: 'Slow answers, JSON instead of text, memory and more.',
			blocks: [
				[
					'table',
					['Question', 'Answer'],
					[
						[
							'The answer is very slow.',
							'The model probably does not fit on the GPU. Check its rating in the catalog and run `ollama ps`: if it is not 100% GPU, use a smaller model.'
						],
						[
							'The first answer is slow and the next ones are fast.',
							'That is the time to load the model into memory. Raise `OLLAMA_KEEP_ALIVE` so it stays loaded longer.'
						],
						[
							'The model answered with a block of JSON.',
							'It tried to use a tool it cannot use. my-local-ia already turns tools off for those models; if it happens with another one, set **Function Calling** to **Legacy** in the model parameters.'
						],
						[
							'The AI "forgot" the start of a long chat.',
							'The context ran out. Raise the context in the chat Controls or start a new chat with a summary.'
						],
						[
							'The model does not read my image.',
							'It is not a vision model. Pick one with the Vision label in the catalog (such as Qwen3-VL or Gemma 3).'
						],
						[
							'The download stopped.',
							'Look at the downloads panel in the sidebar. If it failed, download again: Ollama resumes where it stopped.'
						],
						[
							'I forgot my password.',
							"Ask an administrator: Admin Panel → Users, or the installer (Reset a user's password option)."
						]
					]
				]
			]
		}
	]
};
