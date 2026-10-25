// Ayuda de my-local-ia en español. El mismo contenido genera la página de ayuda y el manual en Word.
// Bloques: ['p', texto], ['h', título], ['steps', [...]], ['bullets', [...]], ['tip'|'note'|'warn', texto],
// ['img', nombre, leyenda], ['code', [líneas]], ['table', encabezado, filas].
// En los textos, **negrita** y `código`.
export default {
	title: 'Ayuda de my-local-ia',
	subtitle: 'Cómo usar Open WebUI, Ollama y las funciones de my-local-ia',
	intro:
		'my-local-ia reúne tres cosas: **Ollama**, que ejecuta los modelos de IA en el servidor; **Open WebUI**, la interfaz de chat que usas en el navegador; y las funciones de **my-local-ia**, que muestran qué funciona bien en tu hardware, cuidan el disco y facilitan las descargas. Elige un tema abajo.',
	open: 'Abrir',
	adminOnly: 'Solo administradores',
	search: 'Buscar en la ayuda…',
	noResults: 'No se encontró nada. Prueba otra palabra.',
	sections: [
		{
			id: 'start',
			title: 'Primeros pasos',
			summary: 'Entrar, conocer la pantalla y elegir el idioma.',
			link: '/',
			blocks: [
				[
					'steps',
					[
						'Abre **http://IP-DEL-SERVIDOR:4000** en el navegador de cualquier computadora o celular de la red.',
						'Entra con tu correo y contraseña. Si te acabas de registrar, espera a que un administrador apruebe la cuenta.',
						'Elige un modelo arriba del chat (o en el botón junto al cuadro de mensaje) y escribe tu pregunta.'
					]
				],
				[
					'img',
					'chat',
					'Pantalla inicial: menú lateral a la izquierda, cuadro de mensaje y selector de modelo.'
				],
				[
					'table',
					['Parte de la pantalla', 'Para qué sirve'],
					[
						[
							'Menú lateral',
							'Nuevo chat, búsqueda, my-local-ia, notas, espacio de trabajo, carpetas y el historial de chats.'
						],
						[
							'Disco del servidor',
							'Al pie del menú: cuánto disco está ocupado y las descargas en curso.'
						],
						[
							'Selector de modelo',
							'Elige qué IA responde. La etiqueta de color muestra cómo funciona en este servidor.'
						],
						[
							'Cuadro de mensaje',
							'Donde escribes, adjuntas archivos, activas herramientas y usas la voz.'
						],
						[
							'Tu foto (abajo)',
							'Ajustes, chats archivados, Administración (administradores) y cerrar sesión.'
						]
					]
				],
				[
					'tip',
					'Para cambiar el idioma: foto de perfil → **Ajustes** → **General** → **Idioma**. La interfaz está completa en español, portugués e inglés.'
				],
				[
					'p',
					'Para abrir esta ayuda desde cualquier lugar, haz clic en **Ayuda** arriba de las páginas de my-local-ia.'
				]
			]
		},
		{
			id: 'chat',
			title: 'Conversar con la IA',
			summary: 'Enviar mensajes, adjuntar archivos, usar la voz y comparar modelos.',
			link: '/',
			blocks: [
				['h', 'Enviar un mensaje'],
				[
					'steps',
					[
						'Haz clic en **Nuevo Chat** en el menú lateral.',
						'Elige el modelo. Si es pesado para este servidor, my-local-ia avisa y sugiere uno más ligero.',
						'Escribe y pulsa **Enter** (para saltar de línea sin enviar: **Shift + Enter**).',
						'La respuesta aparece poco a poco. Para detenerla, haz clic en el botón de detener.'
					]
				],
				['h', 'El botón + (adjuntos)'],
				[
					'bullets',
					[
						'**Subir Archivos**: PDF, Word, hojas de cálculo, textos, imágenes y audios. El contenido va con la pregunta.',
						'**Captura**: toma una captura de pantalla y la adjunta.',
						'**Adjuntar página web**: pega una dirección y el texto de la página entra en el chat.',
						'**Adjuntar notas, conocimiento y chats**: usa tus notas, bases de conocimiento o chats anteriores como contexto.'
					]
				],
				[
					'note',
					'Antes de enviar un adjunto, el cuadro **Antes de enviar** dice si el modelo elegido lee ese tipo de archivo y cuánto va a tardar en leerlo.'
				],
				['h', 'Herramientas (botón de integraciones)'],
				[
					'bullets',
					[
						'**Búsqueda Web**: la IA busca en internet antes de responder (un administrador debe activarla).',
						'**Imagen**: genera imágenes a partir del texto (necesita un generador de imágenes configurado).',
						'**Intérprete de Código**: la IA escribe y ejecuta código Python para cálculos, gráficos y análisis de hojas de cálculo.',
						'**Herramientas y Habilidades**: herramientas extra instaladas en el Espacio de Trabajo.'
					]
				],
				['h', 'Atajos en el cuadro de mensaje'],
				[
					'table',
					['Escribe', 'Qué pasa'],
					[
						['`@`', 'Llama a otro modelo solo para el próximo mensaje.'],
						['`/`', 'Usa un prompt guardado (ver Espacio de Trabajo → Prompts).'],
						['`#`', 'Adjunta una base de conocimiento o un archivo.'],
						['`$`', 'Usa una habilidad.'],
						['`:`', 'Inserta un emoji.']
					]
				],
				['h', 'Voz'],
				[
					'bullets',
					[
						'**Dictar** (micrófono): habla y el texto aparece en el cuadro; la transcripción se hace aquí en el servidor.',
						'**Llamada / modo de voz**: una conversación hablada, con la respuesta leída en voz alta.'
					]
				],
				['h', 'Acciones en cada respuesta'],
				[
					'bullets',
					[
						'**Copiar**, **Editar** tu pregunta o la respuesta, **Leer en voz alta**.',
						'**Regenerar**: otra respuesta a la misma pregunta (las versiones se guardan y puedes alternar).',
						'**Continuar Respuesta**: cuando la respuesta quedó cortada.',
						'**Buena Respuesta / Respuesta Errónea**: valoraciones que el administrador ve en Evaluaciones.'
					]
				],
				['h', 'Comparar modelos y otras opciones'],
				[
					'bullets',
					[
						'**Varios modelos**: en el selector, haz clic en **+** para agregar otro modelo; cada uno responde lado a lado.',
						'**Chat Temporal**: no se guarda en el historial.',
						'**Controles** (icono arriba a la derecha): prompt del sistema y parámetros como temperatura y tamaño del contexto solo para este chat.'
					]
				]
			]
		},
		{
			id: 'organize',
			title: 'Organizar los chats',
			summary: 'Buscar, carpetas, fijar, archivar, compartir y exportar.',
			link: '/',
			blocks: [
				[
					'bullets',
					[
						'**Buscar** (menú lateral): busca en todos tus chats.',
						'**Carpetas**: haz clic en **+** junto a Carpetas y arrastra chats adentro. Una carpeta puede tener instrucciones y archivos propios.',
						'**Menú de cada chat** (tres puntos): renombrar, fijar arriba, archivar, compartir, descargar (texto, PDF o JSON), mover y eliminar.',
						'**Etiquetas**: etiquetas que la IA sugiere y que puedes usar en la búsqueda.',
						'**Chats archivados**: Ajustes → **Chats archivados**, para recuperarlos o eliminarlos del todo.',
						'**Exportar o importar todo**: Ajustes → **Controles de Datos**.'
					]
				],
				[
					'warn',
					'Un enlace para compartir da acceso al chat a cualquiera con cuenta en my-local-ia. No compartas chats con datos sensibles.'
				]
			]
		},
		{
			id: 'knowledge',
			title: 'Documentos y bases de conocimiento',
			summary: 'Hacer que la IA responda con tus propios archivos.',
			link: '/workspace/knowledge',
			blocks: [
				[
					'p',
					'Una **base de conocimiento** es una carpeta de documentos que la IA consulta para responder. El texto se divide en fragmentos y lo indexa un modelo de **embeddings**; en cada pregunta solo los fragmentos más parecidos van al modelo.'
				],
				[
					'steps',
					[
						'Abre **Espacio de Trabajo** → **Conocimiento** → **+**.',
						'Dale un nombre y una descripción y elige quién puede verla.',
						'Sube los archivos (PDF, Word, textos, hojas de cálculo…) o una carpeta entera.',
						'En el chat, escribe `#` y elige la base, o vincula la base a un modelo personalizado para usarla siempre.'
					]
				],
				[
					'tip',
					'Para documentos en español y portugués, un modelo de embeddings multilingüe (como **BGE-M3**, recomendado en el catálogo) da resultados mucho mejores.'
				],
				[
					'note',
					'Un archivo adjuntado directo en el chat también se lee, pero solo en ese chat. Usa bases de conocimiento para documentos que vas a consultar muchas veces.'
				]
			]
		},
		{
			id: 'workspace',
			title: 'Espacio de Trabajo',
			summary: 'Asistentes personalizados, prompts, herramientas, habilidades y funciones.',
			link: '/workspace/models',
			blocks: [
				['h', 'Modelos (asistentes personalizados)'],
				[
					'steps',
					[
						'**Espacio de Trabajo** → **Modelos** → **+**.',
						'Elige el **modelo base** (uno de los modelos de Ollama).',
						'Escribe el **prompt del sistema**: quién es el asistente y cómo debe responder.',
						'Vincula bases de **conocimiento**, **herramientas** y **capacidades** (visión, búsqueda web, imagen…).',
						'En **Parámetros Avanzados**, ajusta temperatura, tamaño del contexto y el modo de llamada de herramientas.',
						'Guarda. El asistente aparece en el selector de modelos para quien tenga acceso.'
					]
				],
				['h', 'Prompts'],
				[
					'p',
					'Textos listos que llamas con `/` en el chat. Pueden tener variables, como `{{nombre}}`, que my-local-ia pregunta antes de enviar.'
				],
				['h', 'Herramientas, habilidades y funciones'],
				[
					'bullets',
					[
						'**Herramientas**: código Python que la IA puede llamar (consultar una API, leer una hoja de cálculo…).',
						'**Habilidades**: instrucciones y archivos que enseñan a la IA una tarea específica.',
						'**Funciones** (Administración): filtros y acciones que cambian cómo funciona el chat para todos.'
					]
				],
				[
					'warn',
					'Las herramientas y funciones ejecutan código en el servidor. Instala solo código de fuentes de confianza y revísalo antes de activarlo.'
				]
			]
		},
		{
			id: 'more',
			title: 'Notas, canales, calendario y automatizaciones',
			summary: 'Otros espacios de Open WebUI además del chat.',
			link: '/notes',
			blocks: [
				[
					'bullets',
					[
						'**Notas**: un editor de textos con la IA al lado para resumir, reescribir y continuar. Las notas se pueden adjuntar a los chats.',
						'**Canales**: salas de chat del equipo donde puedes llamar a un modelo con `@`. Aparecen cuando un administrador los activa.',
						'**Calendario**: eventos que la IA puede consultar y crear (cuando está activado).',
						'**Automatizaciones**: prompts que se ejecutan solos a una hora, como un resumen diario (cuando están activadas).',
						'**Zona de Pruebas**: área de pruebas para administradores, con completions y generación de imágenes.'
					]
				],
				[
					'note',
					'Canales, calendario y automatizaciones quedan ocultos hasta que un administrador los activa en **Administración → Ajustes → General**.'
				]
			]
		},
		{
			id: 'settings',
			title: 'Tus ajustes',
			summary: 'Idioma, tema, memoria, voz, notificaciones y cuenta.',
			link: '/?settings=general',
			blocks: [
				[
					'table',
					['Pestaña', 'Qué tiene'],
					[
						[
							'General',
							'Idioma, tema (claro, oscuro, sistema), prompt del sistema y parámetros por defecto.'
						],
						[
							'Interfaz',
							'Apariencia del chat, comportamiento de Enter, sugerencias, títulos automáticos.'
						],
						[
							'Notificaciones',
							'Avisos cuando una respuesta termina con la pestaña en segundo plano.'
						],
						['Teclado', 'Lista de atajos.'],
						['Integraciones', 'Herramientas y servidores externos conectados a tu cuenta.'],
						['Personalización', 'Memoria: datos sobre ti que la IA recuerda en todos los chats.'],
						['Audio', 'Voz que lee las respuestas y el reconocimiento de voz.'],
						['Controles de Datos', 'Exportar, importar y eliminar chats.'],
						['Uso', 'Cuánto usaste cada modelo.'],
						['Cuenta', 'Nombre, foto, contraseña y claves de API.']
					]
				],
				[
					'tip',
					'La memoria ayuda a la IA a recordar preferencias ("responde siempre en español", "soy contador"). Ves y borras cada recuerdo en **Personalización**.'
				]
			]
		},
		{
			id: 'admin',
			title: 'Administración',
			summary: 'Usuarios, grupos, permisos y los ajustes del servidor.',
			link: '/admin/users',
			admin: true,
			blocks: [
				['h', 'Usuarios y grupos'],
				[
					'bullets',
					[
						'**Administración → Usuarios**: crear cuentas (+), cambiar el rol (**pending**, **user**, **admin**), restablecer la contraseña y eliminar.',
						'Los registros nuevos quedan **pendientes** hasta que los apruebes.',
						'**Grupos**: reúne personas y da permisos y acceso a modelos, bases de conocimiento y herramientas por grupo.'
					]
				],
				['h', 'Ajustes del servidor (Administración → Ajustes)'],
				[
					'table',
					['Pestaña', 'Para qué sirve'],
					[
						[
							'General',
							'Registro abierto o cerrado, rol por defecto de los usuarios nuevos, funciones como canales, notas y calendario.'
						],
						['Autenticación', 'Inicio de sesión con Google, Microsoft, LDAP y otros.'],
						['Interfaz', 'Avisos, sugerencias de prompt y modelos de tareas (títulos, etiquetas).'],
						['Conexiones', 'Dirección de Ollama y conexiones a APIs compatibles con OpenAI.'],
						['Modelos', 'Quién ve cada modelo, nombres, iconos y parámetros por defecto.'],
						[
							'Documentos',
							'Modelo de embeddings, tamaño de los fragmentos y cómo se leen los archivos.'
						],
						['Búsqueda Web', 'Motor de búsqueda que usa la herramienta de búsqueda.'],
						['Audio', 'Reconocimiento de voz (Whisper) y voz.'],
						['Imágenes', 'Generador de imágenes (ComfyUI, Automatic1111, OpenAI…).'],
						['Ejecución de Código', 'Dónde se ejecuta el intérprete de código.'],
						[
							'Analíticas y Evaluaciones',
							'Uso por modelo y las valoraciones (buena/errónea) de las respuestas.'
						],
						['Base de datos', 'Exportar la base de datos e importar ajustes.']
					]
				],
				[
					'warn',
					'Para actualizar my-local-ia, usa el instalador (**Actualizar**), no el aviso de "nueva versión" de Open WebUI: lleva al proyecto original, sin las funciones de my-local-ia.'
				]
			]
		},
		{
			id: 'ollama',
			title: 'Ollama',
			summary: 'El motor que ejecuta los modelos: comandos y ajustes útiles.',
			blocks: [
				[
					'p',
					'**Ollama** descarga y ejecuta los modelos. Carga cada modelo en la memoria de la GPU (VRAM) y, si no cabe, usa también la RAM, que es mucho más lenta. Los comandos de abajo se ejecutan en la terminal del servidor.'
				],
				[
					'table',
					['Comando', 'Qué hace'],
					[
						['`ollama list`', 'Lista los modelos instalados y el tamaño de cada uno.'],
						[
							'`ollama ps`',
							'Muestra los modelos cargados ahora y cuánto está en la GPU y en la CPU (ej.: 100% GPU).'
						],
						[
							'`ollama pull qwen3:8b`',
							'Descarga un modelo (my-local-ia lo hace desde el catálogo).'
						],
						['`ollama run qwen3:8b`', 'Conversa con el modelo directo en la terminal.'],
						[
							'`ollama show qwen3:8b`',
							'Detalles: parámetros, contexto, capacidades (visión, herramientas, razonamiento).'
						],
						['`ollama stop qwen3:8b`', 'Descarga el modelo de la memoria.'],
						['`ollama rm qwen3:8b`', 'Borra el modelo del disco.']
					]
				],
				['h', 'Cómo leer ollama ps'],
				[
					'bullets',
					[
						'**100% GPU**: todo el modelo está en la GPU. Es lo más rápido.',
						'**10%/90% CPU/GPU**: una parte quedó en la RAM y la velocidad baja mucho. Prefiere un modelo más pequeño o menos contexto.',
						'**CONTEXT**: cuántos tokens de conversación acepta el modelo. Más contexto ocupa más memoria.',
						'**UNTIL**: cuándo el modelo sale de la memoria si nadie lo usa.'
					]
				],
				['h', 'Ajustes del servicio'],
				[
					'p',
					'En Linux, los ajustes van en el servicio de Ollama: ejecuta `sudo systemctl edit ollama`, agrega las líneas de abajo y reinicia con `sudo systemctl restart ollama`.'
				],
				[
					'code',
					[
						'[Service]',
						'Environment="OLLAMA_KEEP_ALIVE=30m"        # tiempo que el modelo queda cargado',
						'Environment="OLLAMA_CONTEXT_LENGTH=8192"   # contexto por defecto',
						'Environment="OLLAMA_MAX_LOADED_MODELS=2"   # modelos en memoria a la vez',
						'Environment="OLLAMA_NUM_PARALLEL=2"        # respuestas simultáneas por modelo',
						'Environment="OLLAMA_FLASH_ATTENTION=1"     # menos memoria para el contexto',
						'Environment="OLLAMA_KV_CACHE_TYPE=q8_0"    # contexto comprimido (necesita la línea anterior)'
					]
				],
				[
					'tip',
					'En una GPU de 12 GB, un modelo de 7–8B con contexto de 8 mil tokens cabe entero en la GPU. Los de 14B caben con menos contexto; de 20B para arriba, una parte va a la RAM.'
				],
				[
					'note',
					'La primera respuesta después de un rato tarda más: Ollama está cargando el modelo del disco a la memoria.'
				]
			]
		},
		{
			id: 'catalog',
			title: 'my-local-ia: catálogo y descargas',
			summary: 'Saber qué funciona bien aquí y descargar sin salir de la página.',
			link: '/my-local-ia',
			blocks: [
				[
					'img',
					'catalog',
					'Catálogo: hardware detectado, notas y las mejores opciones para este servidor.'
				],
				[
					'table',
					['Nota', 'Significado'],
					[
						['Va fluido', 'Cabe en la memoria de la GPU y responde rápido.'],
						['Usable', 'Funciona, pero más lento o al límite de la memoria de la GPU.'],
						['Pesado', 'No cabe entero en la GPU: una parte va a la RAM, que es mucho más lenta.'],
						['No funciona', 'Necesita más memoria de la que tiene el servidor.']
					]
				],
				[
					'bullets',
					[
						'**Los mejores para este servidor**: una opción por tarea, recalculada para tu hardware.',
						'**Cabe en este servidor** (activado por defecto): muestra solo lo que va fluido o es usable. Desactívalo para ver todo.',
						'**Filtros**: chat, razonamiento, visión, código, imagen, video, voz, embeddings, ligeros, nuevos e instalados. La búsqueda acepta nombre o uso.',
						'El **robot** busca modelos nuevos todos los días en la biblioteca oficial de Ollama y en Hugging Face (hasta 300), con los que funcionan bien aquí primero.'
					]
				],
				['h', 'Descargar un modelo'],
				[
					'steps',
					[
						'Haz clic en **Descargar (tamaño)** en la tarjeta del modelo.',
						'my-local-ia revisa el disco y muestra cómo quedará después. Si no cabe, ofrece un modelo parecido más pequeño o liberar espacio quitando modelos sin uso.',
						'Haz clic en **Descargar**. Puedes cerrar la ventana y cambiar de página: la descarga sigue en el servidor.',
						'El progreso aparece debajo de **Disco del servidor**, en el menú lateral, para todos. Cuando termina, el modelo ya está en el selector.'
					]
				],
				[
					'img',
					'downloads',
					'Descarga en segundo plano: el progreso queda debajo del medidor de disco.'
				],
				[
					'note',
					'Los administradores descargan cualquier modelo. Los usuarios descargan modelos del catálogo si el administrador lo permite. Nadie puede descargar algo que supere el límite del disco.'
				]
			]
		},
		{
			id: 'warnings',
			title: 'my-local-ia: avisos en el chat',
			summary: 'Aviso de modelo pesado, "Antes de enviar" y el modo de herramientas automático.',
			link: '/',
			blocks: [
				[
					'img',
					'heavy-warning',
					'Aviso al elegir un modelo pesado, con una alternativa que funciona bien.'
				],
				[
					'bullets',
					[
						'**Selector de modelos**: cada modelo instalado muestra su nota en este servidor.',
						'**Aviso de modelo pesado**: al elegir un modelo pesado o que no funciona, aparece el motivo y un modelo del mismo tipo que funciona bien. Elige **Cambiar**, **Usarlo de todos modos** o **Cancelar**.',
						'**Antes de enviar**: al adjuntar una imagen, un PDF o un audio, dice si el modelo lee ese archivo y cuánto tardará en leerlo.'
					]
				],
				['img', 'before-send', 'Antes de enviar: el modelo elegido no lee imágenes.'],
				['h', 'Modo de herramientas automático'],
				[
					'p',
					'Open WebUI envía herramientas (calendario, notas, memoria…) con cada mensaje. Los modelos que no saben usar herramientas respondían con un bloque de JSON en lugar del texto. my-local-ia desactiva solo las herramientas para esos modelos (qwen2.5-coder, los de menos de 4B y los sin soporte) y las mantiene en los que las usan bien, como gpt-oss, qwen3 y llama3.1.'
				],
				[
					'tip',
					'Para forzar un modo: **Espacio de Trabajo → Modelos → editar → Parámetros Avanzados → Function Calling** (Native = con herramientas; Legacy = sin ellas).'
				]
			]
		},
		{
			id: 'simulator',
			title: 'my-local-ia: simulador',
			summary: 'Comparar hasta 3 modelos antes de descargar.',
			link: '/my-local-ia/simulator',
			blocks: [
				['img', 'simulator', 'Simulador comparando 3 modelos con la misma pregunta.'],
				[
					'steps',
					[
						'Elige qué vas a enviar: **pregunta de texto**, **imagen**, **PDF** o **audio**.',
						'Elige 1, 2 o 3 modelos, instalados o del catálogo.',
						'Elige **Tiempo real** o **5× más rápido** y haz clic en **Empezar simulación**.'
					]
				],
				[
					'p',
					'Cada columna muestra cuándo el modelo empieza a responder, a qué velocidad escribe y cuándo termina. El texto siempre es el mismo ejemplo: el simulador mide tiempo, no la calidad de la respuesta.'
				]
			]
		},
		{
			id: 'disk',
			title: 'my-local-ia: espacio en disco',
			summary: 'Qué ocupa el disco, alertas y cómo liberar espacio.',
			link: '/my-local-ia/disk',
			blocks: [
				['img', 'disk', 'Espacio en disco: uso total, división por tipo y modelos instalados.'],
				[
					'bullets',
					[
						'La barra separa **modelos de IA**, **Open WebUI** (chats, archivos, documentos), **sistema** y **libre**. Las líneas punteadas son los límites de atención, crítico y bloqueo.',
						'Cuando el uso crece, la página prevé en cuántos días el disco llega al límite.',
						'La tabla muestra cada modelo con tamaño, nota, último uso, respuestas en 30 días, quién lo descargó y una sugerencia (sin uso, pesado, poco usado).',
						'Marca modelos y haz clic en **Quitar marcados**. La barra muestra antes cómo quedará el disco.'
					]
				],
				[
					'note',
					'Los administradores quitan cualquier modelo; los usuarios solo los que descargaron ellos y que nadie usó recientemente. El modelo de la búsqueda en documentos queda protegido.'
				]
			]
		},
		{
			id: 'mli-settings',
			title: 'my-local-ia: ajustes',
			summary: 'Hardware, descargas, alertas de disco y el robot de modelos.',
			link: '/my-local-ia/settings',
			admin: true,
			blocks: [
				['img', 'settings', 'Ajustes de my-local-ia: hardware detectado, descargas y alertas.'],
				[
					'bullets',
					[
						'**Hardware**: detectado al iniciar y revisado cada pocos minutos. **Detectar de nuevo** muestra qué cambió; **Ajustar manualmente** corrige la VRAM, la RAM o las velocidades.',
						'**Descargas**: activa o desactiva las descargas de los usuarios.',
						'**Alertas de disco**: límites de atención, crítico y bloqueo, aviso arriba para todos y webhook (Discord, Slack, Teams, Google Chat).',
						'**Robot de modelos nuevos**: frecuencia, hora, mínimo de descargas, máximo de modelos (300), biblioteca de Ollama y perfiles de Hugging Face. **Buscar ahora** lo ejecuta enseguida.'
					]
				]
			]
		},
		{
			id: 'faq',
			title: 'Preguntas frecuentes',
			summary: 'Respuestas lentas, JSON en lugar del texto, memoria y más.',
			blocks: [
				[
					'table',
					['Pregunta', 'Respuesta'],
					[
						[
							'La respuesta es muy lenta.',
							'El modelo probablemente no cabe en la GPU. Mira su nota en el catálogo y ejecuta `ollama ps`: si no está 100% GPU, usa un modelo más pequeño.'
						],
						[
							'La primera respuesta tarda y las siguientes son rápidas.',
							'Es el tiempo de cargar el modelo en la memoria. Aumenta `OLLAMA_KEEP_ALIVE` para que quede cargado más tiempo.'
						],
						[
							'El modelo respondió con un bloque de JSON.',
							'Intentó usar una herramienta que no sabe usar. my-local-ia ya desactiva las herramientas de esos modelos; si pasa con otro, cambia **Function Calling** a **Legacy** en los parámetros del modelo.'
						],
						[
							'La IA "olvidó" el comienzo de un chat largo.',
							'Se acabó el contexto. Aumenta el contexto en los Controles del chat o empieza un chat nuevo con un resumen.'
						],
						[
							'El modelo no lee mi imagen.',
							'No es un modelo de visión. Elige uno con la etiqueta Visión en el catálogo (como Qwen3-VL o Gemma 3).'
						],
						[
							'La descarga se detuvo.',
							'Mira el panel de descargas en el menú lateral. Si falló, descarga de nuevo: Ollama sigue desde donde se quedó.'
						],
						[
							'Olvidé mi contraseña.',
							'Pídeselo a un administrador: Administración → Usuarios, o el instalador (opción Restablecer la contraseña).'
						]
					]
				]
			]
		}
	]
};
