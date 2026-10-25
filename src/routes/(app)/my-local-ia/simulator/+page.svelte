<script lang="ts">
	// Shows, at this server's speed, how long each model takes to read the input
	// (question, image, PDF, transcribed audio) and to write the answer. The answer
	// text is the same sample for every model: this compares time, not quality.
	import { getContext, onDestroy, onMount } from 'svelte';
	import { page } from '$app/stores';

	import { getCatalog, getHardware, type Estimate, type Hardware } from '$lib/apis/my-local-ia';
	import Spinner from '$lib/components/common/Spinner.svelte';
	import LevelBadge from '$lib/components/my-local-ia/LevelBadge.svelte';
	import { formatSeconds } from '$lib/components/my-local-ia/labels';
	import { installedModels, loadInstalled } from '$lib/components/my-local-ia/store';

	const i18n = getContext('i18n');

	type Option = { id: string; label: string; estimate: Estimate; vision: boolean };
	type Scenario = 'text' | 'image' | 'pdf' | 'audio';

	// Input size of each scenario, in tokens; audio is 5 minutes, transcribed first.
	const INPUT_TOKENS: Record<Scenario, number> = { text: 40, image: 800, pdf: 10000, audio: 900 };
	const IMAGE_ENCODE_SECONDS = 1.2;
	const AUDIO_SECONDS = 300;
	// Whisper speed in times real time (Open WebUI transcribes on the server).
	const WHISPER_SPEED = { gpu: 25, cpu: 1.5 };

	const SAMPLES: Record<string, Record<Scenario, [string, string]>> = {
		en: {
			text: [
				'What are the advantages of running AI on my own computer?',
				'Running AI on your own computer has three main advantages.\n\n1. Privacy: nothing you type leaves your machine.\n2. Cost: once the model is downloaded, you do not pay per use.\n3. Availability: it works without internet.\n\nThe limit is the GPU memory. If the model fits in it, the answer comes fast; if not, part goes to system RAM and the speed drops.'
			],
			image: [
				'[spreadsheet-screenshot.png] What does this spreadsheet show?',
				'The spreadsheet shows sales from January to June by region.\n\n- The Southeast leads every month.\n- March had the highest total of the semester.\n- The North grew 18% between January and June.\n\nThe targets column is empty in May; it may be missing data.'
			],
			pdf: [
				'[report.pdf · 20 pages] Summarize it in 5 points.',
				'Report summary:\n\n1. Revenue grew 12% in the quarter.\n2. Logistics costs fell after the supplier change.\n3. Two new stores open in November.\n4. Winter stock is above the ideal level.\n5. The annual target is still possible, but tight.'
			],
			audio: [
				'[meeting.m4a · 5 min] List the decisions of the meeting.',
				'Meeting decisions:\n\n- Launch the year-end campaign on November 15.\n- Ana is responsible for the final budget.\n- The new website goes live only in January.\n- Next meeting on Monday at 10 am.'
			]
		},
		'pt-BR': {
			text: [
				'Quais as vantagens de rodar IA no meu próprio computador?',
				'Rodar IA no seu computador tem três vantagens principais.\n\n1. Privacidade: nada do que você digita sai da sua máquina.\n2. Custo: depois de baixar o modelo, você não paga por uso.\n3. Disponibilidade: funciona sem internet.\n\nO limite é a memória da placa de vídeo. Se o modelo cabe inteiro nela, a resposta sai rápida; se não cabe, parte vai para a RAM e a velocidade cai.'
			],
			image: [
				'[print-da-planilha.png] O que essa planilha mostra?',
				'A planilha mostra as vendas de janeiro a junho por região.\n\n- O Sudeste lidera em todos os meses.\n- Março teve o maior total do semestre.\n- O Norte cresceu 18% entre janeiro e junho.\n\nA coluna de metas está vazia em maio; talvez falte preencher.'
			],
			pdf: [
				'[relatorio.pdf · 20 páginas] Resuma em 5 tópicos.',
				'Resumo do relatório:\n\n1. A receita subiu 12% no trimestre.\n2. Os custos de logística caíram após a troca de fornecedor.\n3. Duas lojas novas abrem em novembro.\n4. O estoque de inverno está acima do ideal.\n5. A meta anual segue possível, mas apertada.'
			],
			audio: [
				'[reuniao.m4a · 5 min] Liste as decisões da reunião.',
				'Decisões da reunião:\n\n- Lançar a campanha de fim de ano em 15 de novembro.\n- Ana fica responsável pelo orçamento final.\n- O site novo entra no ar só em janeiro.\n- Próxima reunião na segunda, às 10h.'
			]
		},
		es: {
			text: [
				'¿Qué ventajas tiene ejecutar IA en mi propio equipo?',
				'Ejecutar IA en tu propio equipo tiene tres ventajas principales.\n\n1. Privacidad: nada de lo que escribes sale de tu máquina.\n2. Costo: después de descargar el modelo, no pagas por uso.\n3. Disponibilidad: funciona sin internet.\n\nEl límite es la memoria de la GPU. Si el modelo cabe entero en ella, la respuesta llega rápido; si no, una parte va a la RAM y la velocidad cae.'
			],
			image: [
				'[captura-de-la-planilla.png] ¿Qué muestra esta planilla?',
				'La planilla muestra las ventas de enero a junio por región.\n\n- El Sudeste lidera todos los meses.\n- Marzo tuvo el mayor total del semestre.\n- El Norte creció 18% entre enero y junio.\n\nLa columna de metas está vacía en mayo; quizá falte completarla.'
			],
			pdf: [
				'[informe.pdf · 20 páginas] Resúmelo en 5 puntos.',
				'Resumen del informe:\n\n1. Los ingresos subieron 12% en el trimestre.\n2. Los costos de logística bajaron tras cambiar de proveedor.\n3. Dos tiendas nuevas abren en noviembre.\n4. El stock de invierno está por encima de lo ideal.\n5. La meta anual sigue siendo posible, pero ajustada.'
			],
			audio: [
				'[reunion.m4a · 5 min] Enumera las decisiones de la reunión.',
				'Decisiones de la reunión:\n\n- Lanzar la campaña de fin de año el 15 de noviembre.\n- Ana es responsable del presupuesto final.\n- El nuevo sitio web sale recién en enero.\n- Próxima reunión el lunes a las 10.'
			]
		}
	};

	let loading = true;
	let hardware: Hardware | null = null;
	let options: Option[] = [];
	let scenario: Scenario = 'text';
	let count = 3;
	let speed = 1;
	let slots: string[] = ['', '', ''];
	let elapsed = 0;
	let running = false;
	let finished = false;
	let timer: ReturnType<typeof setInterval> | null = null;

	$: lang = $i18n.language?.startsWith('pt')
		? 'pt-BR'
		: $i18n.language?.startsWith('es')
			? 'es'
			: 'en';
	$: [question, answer] = SAMPLES[lang][scenario];
	$: tokens = answer.match(/\s*\S{1,4}/g) ?? [];
	$: sttSeconds =
		scenario === 'audio'
			? AUDIO_SECONDS / (hardware?.has_gpu ? WHISPER_SPEED.gpu : WHISPER_SPEED.cpu)
			: 0;

	$: lanes = slots.slice(0, count).map((id, idx) => {
		const option = options.find((o) => o.id === id);
		if (!option) return null;
		const unsupported = scenario === 'image' && !option.vision;
		const prefill = option.estimate.prefill_tps ?? 1;
		const tps = option.estimate.tps ?? 1;
		const read =
			INPUT_TOKENS[scenario] / prefill + (scenario === 'image' ? IMAGE_ENCODE_SECONDS : 0);
		const write = tokens.length / tps;
		const start = sttSeconds + read;
		const total = start + write;
		const written =
			elapsed >= total ? tokens.length : elapsed > start ? Math.floor((elapsed - start) * tps) : 0;
		return { idx, option, unsupported, read, write, start, total, written, tps };
	});
	$: maxTotal = Math.max(0, ...lanes.filter((l) => l && !l.unsupported).map((l) => l?.total ?? 0));

	const phaseOf = (lane) => {
		if (elapsed <= 0) return $i18n.t('Ready to start');
		if (elapsed < sttSeconds) return $i18n.t('Transcribing the audio…');
		if (elapsed < lane.start) return $i18n.t('Reading the input…');
		if (elapsed < lane.total) return $i18n.t('Writing…');
		return $i18n.t('Done in {{time}}', { time: formatSeconds(lane.total, $i18n.language) });
	};

	const pct = (part: number, whole: number) =>
		whole <= 0 ? 0 : Math.max(0, Math.min(100, (100 * part) / whole));

	const stop = () => {
		if (timer) clearInterval(timer);
		timer = null;
		running = false;
	};

	const reset = () => {
		stop();
		elapsed = 0;
		finished = false;
	};

	const start = () => {
		reset();
		running = true;
		let last = performance.now();
		timer = setInterval(() => {
			const now = performance.now();
			elapsed += ((now - last) / 1000) * speed;
			last = now;
			if (elapsed >= maxTotal) {
				elapsed = maxTotal;
				finished = true;
				stop();
			}
		}, 60);
	};

	$: valid = lanes.filter((l) => l && !l.unsupported);
	$: verdict = (() => {
		if (!finished || valid.length === 0) return '';
		const sorted = [...valid].sort((a, b) => (a?.total ?? 0) - (b?.total ?? 0));
		const first = sorted[0];
		const last = sorted[sorted.length - 1];
		if (!first || !last) return '';
		if (sorted.length === 1)
			return $i18n.t('{{model}} started answering after {{start}} and finished in {{total}}.', {
				model: first.option.label,
				start: formatSeconds(first.start, $i18n.language),
				total: formatSeconds(first.total, $i18n.language)
			});
		return $i18n.t(
			'{{first}} finished first, in {{time}}. {{last}} took {{lastTime}}, {{times}}× longer.',
			{
				first: first.option.label,
				time: formatSeconds(first.total, $i18n.language),
				last: last.option.label,
				lastTime: formatSeconds(last.total, $i18n.language),
				times: (last.total / first.total).toLocaleString($i18n.language, {
					maximumFractionDigits: 1
				})
			}
		);
	})();

	onMount(async () => {
		try {
			const token = localStorage.token;
			const [hw, catalog] = await Promise.all([getHardware(token), getCatalog(token)]);
			hardware = hw;
			await loadInstalled(true);
			const installed = Object.values($installedModels)
				.filter((m) => m.estimate.tps)
				.map((m) => ({
					id: `installed:${m.name}`,
					label: m.name,
					estimate: m.estimate,
					vision: m.category === 'vis'
				}));
			const inCatalog = catalog
				.filter((m) => m.estimate.tps)
				.map((m) => ({
					id: m.id,
					label: m.name,
					estimate: m.estimate,
					vision: m.category === 'vis'
				}));
			options = [...installed, ...inCatalog];
			const wanted = ($page.url.searchParams.get('models') ?? '').split(',').filter(Boolean);
			const defaults = [...wanted, ...installed.map((o) => o.id), ...inCatalog.map((o) => o.id)];
			slots = [...new Set(defaults.filter((id) => options.some((o) => o.id === id)))].slice(0, 3);
			while (slots.length < 3) slots.push(options[slots.length]?.id ?? '');
			count = wanted.length === 1 ? 1 : Math.min(3, options.length);
		} finally {
			loading = false;
		}
	});

	onDestroy(stop);
</script>

{#if loading}
	<div class="flex justify-center py-20"><Spinner className="size-6" /></div>
{:else}
	<div class="flex flex-col gap-5">
		<header class="flex flex-col gap-1">
			<h1 class="text-2xl font-semibold">{$i18n.t('Simulator')}</h1>
			<p class="text-gray-600 dark:text-gray-300">
				{$i18n.t(
					'See how each model behaves on this server: how long it takes to read what you send and how fast it writes. Compare up to three side by side.'
				)}
			</p>
		</header>

		<div class="flex flex-wrap items-end gap-x-6 gap-y-3">
			<div class="flex flex-col gap-1">
				<span class="text-xs font-medium text-gray-500">{$i18n.t('What you will send')}</span>
				<div class="flex flex-wrap gap-1.5">
					{#each [['text', $i18n.t('Text question')], ['image', $i18n.t('Image')], ['pdf', $i18n.t('PDF')], ['audio', $i18n.t('Audio')]] as [id, label]}
						<button
							type="button"
							aria-pressed={scenario === id}
							class="rounded-xl px-3 py-1.5 text-sm font-medium {scenario === id
								? 'bg-black text-white dark:bg-white dark:text-black'
								: 'bg-gray-100 dark:bg-gray-850'}"
							on:click={() => {
								scenario = id;
								reset();
							}}>{label}</button
						>
					{/each}
				</div>
			</div>
			<div class="flex flex-col gap-1">
				<span class="text-xs font-medium text-gray-500">{$i18n.t('Models side by side')}</span>
				<div class="flex gap-1.5">
					{#each [1, 2, 3] as n}
						<button
							type="button"
							aria-pressed={count === n}
							class="min-w-10 rounded-xl px-3 py-1.5 text-sm font-medium {count === n
								? 'bg-black text-white dark:bg-white dark:text-black'
								: 'bg-gray-100 dark:bg-gray-850'}"
							on:click={() => {
								count = n;
								reset();
							}}>{n}</button
						>
					{/each}
				</div>
			</div>
			<div class="flex flex-col gap-1">
				<span class="text-xs font-medium text-gray-500">{$i18n.t('Simulation pace')}</span>
				<div class="flex gap-1.5">
					{#each [[1, $i18n.t('Real time')], [5, $i18n.t('5× faster')]] as [value, label]}
						<button
							type="button"
							aria-pressed={speed === value}
							class="rounded-xl px-3 py-1.5 text-sm font-medium {speed === value
								? 'bg-black text-white dark:bg-white dark:text-black'
								: 'bg-gray-100 dark:bg-gray-850'}"
							on:click={() => (speed = Number(value))}>{label}</button
						>
					{/each}
				</div>
			</div>
			<div class="ml-auto flex gap-2">
				<button
					type="button"
					class="rounded-xl bg-orange-600 px-4 py-2 text-sm font-medium text-white"
					on:click={start}>{running ? $i18n.t('Restart') : $i18n.t('Start simulation')}</button
				>
				<button
					type="button"
					class="rounded-xl bg-gray-100 px-4 py-2 text-sm font-medium dark:bg-gray-850"
					on:click={stop}>{$i18n.t('Stop')}</button
				>
			</div>
		</div>

		<div class="rounded-xl bg-gray-50 dark:bg-gray-900 px-4 py-3 text-sm">
			<span
				class="mr-2 rounded-md bg-black px-2 py-0.5 text-xs font-medium text-white dark:bg-white dark:text-black"
				>{$i18n.t('You')}</span
			>{question}
		</div>

		<div class="grid gap-4 {count === 1 ? '' : count === 2 ? 'md:grid-cols-2' : 'lg:grid-cols-3'}">
			{#each lanes as lane, idx}
				<article
					class="flex min-w-0 flex-col gap-3 rounded-2xl border border-gray-100 dark:border-gray-850 p-4"
				>
					<label class="flex flex-col gap-1 text-xs text-gray-500">
						{$i18n.t('Model {{letter}}', { letter: 'ABC'[idx] })}
						<select
							class="rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-2 py-1.5 text-sm font-medium text-gray-900 dark:text-gray-100"
							bind:value={slots[idx]}
							on:change={reset}
						>
							{#each options as option}
								<option value={option.id}>
									{option.label}{option.id.startsWith('installed:')
										? ` (${$i18n.t('installed')})`
										: ''}
								</option>
							{/each}
						</select>
					</label>

					{#if lane}
						<div class="flex items-center justify-between gap-2 text-xs">
							<LevelBadge level={lane.option.estimate.level} />
							<span class="text-gray-500">~{Math.round(lane.tps)} {$i18n.t('tokens/s')}</span>
						</div>

						{#if lane.unsupported}
							<div
								class="rounded-xl bg-red-500/10 px-3 py-2 text-sm text-red-700 dark:text-red-300"
							>
								{$i18n.t(
									'This model does not read images. In the chat, my-local-ia warns before sending and suggests a vision model.'
								)}
							</div>
						{:else}
							<div class="grid grid-cols-3 gap-2 text-center">
								<div class="rounded-xl bg-gray-50 dark:bg-gray-900 px-2 py-1.5">
									<div class="text-[0.6875rem] text-gray-500">{$i18n.t('Starts answering')}</div>
									<div class="font-medium tabular-nums">
										{formatSeconds(lane.start, $i18n.language)}
									</div>
								</div>
								<div class="rounded-xl bg-gray-50 dark:bg-gray-900 px-2 py-1.5">
									<div class="text-[0.6875rem] text-gray-500">{$i18n.t('Writes at')}</div>
									<div class="font-medium tabular-nums">{Math.round(lane.tps)} tok/s</div>
								</div>
								<div class="rounded-xl bg-gray-50 dark:bg-gray-900 px-2 py-1.5">
									<div class="text-[0.6875rem] text-gray-500">{$i18n.t('Answer ready')}</div>
									<div class="font-medium tabular-nums">
										{formatSeconds(lane.total, $i18n.language)}
									</div>
								</div>
							</div>

							<div class="flex flex-col gap-1.5 text-xs">
								{#if sttSeconds > 0}
									<div class="flex items-center gap-2">
										<span class="w-28 shrink-0">{$i18n.t('Listen to the audio')}</span>
										<div class="h-2 flex-1 overflow-hidden rounded bg-gray-100 dark:bg-gray-800">
											<div
												class="h-full bg-purple-500"
												style="width: {pct(elapsed, sttSeconds)}%"
											></div>
										</div>
										<span class="w-16 text-right tabular-nums text-gray-500"
											>{formatSeconds(sttSeconds, $i18n.language)}</span
										>
									</div>
								{/if}
								<div class="flex items-center gap-2">
									<span class="w-28 shrink-0">{$i18n.t('Read the input')}</span>
									<div class="h-2 flex-1 overflow-hidden rounded bg-gray-100 dark:bg-gray-800">
										<div
											class="h-full bg-amber-500"
											style="width: {pct(elapsed - sttSeconds, lane.read)}%"
										></div>
									</div>
									<span class="w-16 text-right tabular-nums text-gray-500"
										>{formatSeconds(lane.read, $i18n.language)}</span
									>
								</div>
								<div class="flex items-center gap-2">
									<span class="w-28 shrink-0">{$i18n.t('Write')}</span>
									<div class="h-2 flex-1 overflow-hidden rounded bg-gray-100 dark:bg-gray-800">
										<div
											class="h-full bg-blue-500"
											style="width: {pct(elapsed - lane.start, lane.write)}%"
										></div>
									</div>
									<span class="w-16 text-right tabular-nums text-gray-500"
										>{formatSeconds(lane.write, $i18n.language)}</span
									>
								</div>
							</div>

							<div class="text-xs font-medium text-gray-600 dark:text-gray-300">
								{phaseOf(lane)}
							</div>
							<pre
								class="min-h-48 max-h-64 overflow-auto whitespace-pre-wrap break-words rounded-xl bg-gray-950 p-3 font-mono text-xs leading-relaxed text-gray-100">{tokens
									.slice(0, lane.written)
									.join('')}{running && lane.written < tokens.length ? '▌' : ''}</pre>
						{/if}
					{/if}
				</article>
			{/each}
		</div>

		{#if verdict}
			<p
				aria-live="polite"
				class="rounded-xl bg-emerald-500/10 px-4 py-3 text-sm text-emerald-800 dark:text-emerald-200"
			>
				{verdict}
			</p>
		{/if}

		<p class="text-xs text-gray-500">
			{$i18n.t(
				'The text is always the same sample so the comparison is fair: the simulator shows time, not answer quality. Times are estimated from the detected hardware; audio is transcribed on the server before going to the model.'
			)}
		</p>
	</div>
{/if}
