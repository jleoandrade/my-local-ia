<script lang="ts">
	// Help for every feature: Open WebUI, Ollama and my-local-ia. The text lives in
	// $lib/components/my-local-ia/help/<language>.js, which also builds the Word manual.
	import { getContext, onMount, tick } from 'svelte';
	import { goto } from '$app/navigation';
	import { page } from '$app/stores';

	import { user } from '$lib/stores';
	import en from '$lib/components/my-local-ia/help/en.js';
	import es from '$lib/components/my-local-ia/help/es.js';
	import ptBR from '$lib/components/my-local-ia/help/pt-BR.js';

	const i18n = getContext('i18n');

	type Block = [string, ...any[]];
	type Section = {
		id: string;
		title: string;
		summary: string;
		link?: string;
		admin?: boolean;
		blocks: Block[];
	};

	$: lang = $i18n.language?.startsWith('pt')
		? 'pt-BR'
		: $i18n.language?.startsWith('es')
			? 'es'
			: 'en';
	$: help = lang === 'pt-BR' ? ptBR : lang === 'es' ? es : en;

	let query = '';

	const fold = (text: string) => text.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');

	const blockText = (block: Block): string =>
		block
			.slice(1)
			.map((part) =>
				Array.isArray(part) ? part.map((p) => blockText(['', p])).join(' ') : `${part}`
			)
			.join(' ');

	$: sections = (help.sections as Section[]).filter((s) => {
		if (!query.trim()) return true;
		const text = fold([s.title, s.summary, ...s.blocks.map(blockText)].join(' '));
		return fold(query.trim())
			.split(/\s+/)
			.every((word) => text.includes(word));
	});

	// **bold** and `code` inside the texts.
	const parts = (text: string) =>
		`${text}`
			.split(/(\*\*[^*]+\*\*|`[^`]+`)/g)
			.filter(Boolean)
			.map((t) =>
				t.startsWith('**')
					? { text: t.slice(2, -2), kind: 'bold' }
					: t.startsWith('`')
						? { text: t.slice(1, -1), kind: 'code' }
						: { text: t, kind: 'plain' }
			);

	const image = (name: string) => `/my-local-ia-help/${lang}/${name}.webp`;

	const BOX = {
		tip: 'border-emerald-500 bg-emerald-50 dark:bg-emerald-500/10',
		note: 'border-blue-500 bg-blue-50 dark:bg-blue-500/10',
		warn: 'border-amber-500 bg-amber-50 dark:bg-amber-500/10'
	};

	const jump = async (id: string) => {
		await tick();
		const scroll = () =>
			document.getElementById(`help-${id}`)?.scrollIntoView({ behavior: 'smooth', block: 'start' });
		scroll();
		// Images above the section load afterwards and push it down: aim again once they settle.
		setTimeout(scroll, 700);
		history.replaceState(history.state, '', `#${id}`);
	};

	// A link like /my-local-ia/help#catalog opens straight at that section.
	onMount(() => {
		if ($page.url.hash) jump($page.url.hash.slice(1));
	});
</script>

<div class="flex flex-col gap-8">
	<header class="flex flex-col gap-2">
		<h1 class="text-2xl font-semibold">{help.title}</h1>
		<p class="text-gray-600 dark:text-gray-300">{help.subtitle}</p>
		<p class="max-w-3xl text-sm text-gray-600 dark:text-gray-300">
			{#each parts(help.intro) as p}{#if p.kind === 'bold'}<b>{p.text}</b
					>{:else if p.kind === 'code'}<code>{p.text}</code>{:else}{p.text}{/if}{/each}
		</p>
		<input
			class="mt-2 w-full max-w-md rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-2 text-sm outline-hidden"
			type="search"
			placeholder={help.search}
			aria-label={help.search}
			bind:value={query}
		/>
	</header>

	{#if sections.length === 0}
		<p class="text-sm text-gray-500">{help.noResults}</p>
	{/if}

	<nav class="grid gap-2 sm:grid-cols-2 lg:grid-cols-3" aria-label={help.title}>
		{#each sections as s (s.id)}
			<button
				type="button"
				class="flex flex-col gap-0.5 rounded-xl border border-gray-100 dark:border-gray-850 px-3 py-2 text-left transition hover:bg-gray-50 dark:hover:bg-gray-900"
				on:click={() => jump(s.id)}
			>
				<span class="text-sm font-medium">{s.title}</span>
				<span class="text-xs text-gray-500">{s.summary}</span>
			</button>
		{/each}
	</nav>

	{#each sections as s (s.id)}
		<section
			id={`help-${s.id}`}
			class="flex scroll-mt-4 flex-col gap-3 border-t border-gray-100 dark:border-gray-850 pt-6"
		>
			<div class="flex flex-wrap items-center justify-between gap-2">
				<div class="flex items-center gap-2">
					<h2 class="text-xl font-semibold">{s.title}</h2>
					{#if s.admin}
						<span
							class="rounded-full bg-gray-100 dark:bg-gray-850 px-2 py-0.5 text-xs text-gray-600 dark:text-gray-300"
							>{help.adminOnly}</span
						>
					{/if}
				</div>
				{#if s.link && (!s.admin || $user?.role === 'admin')}
					<button
						type="button"
						class="rounded-full bg-black px-3.5 py-1 text-sm font-medium text-white dark:bg-white dark:text-black"
						on:click={() => goto(s.link ?? '/')}>{help.open} →</button
					>
				{/if}
			</div>
			<p class="text-sm text-gray-500">{s.summary}</p>

			{#each s.blocks as block}
				{#if block[0] === 'h'}
					<h3 class="mt-2 font-semibold">{block[1]}</h3>
				{:else if block[0] === 'p'}
					<p class="text-sm leading-relaxed">
						{#each parts(block[1]) as p}{#if p.kind === 'bold'}<b>{p.text}</b
								>{:else if p.kind === 'code'}<code
									class="rounded bg-gray-100 dark:bg-gray-850 px-1 text-[0.8125rem]">{p.text}</code
								>{:else}{p.text}{/if}{/each}
					</p>
				{:else if block[0] === 'steps' || block[0] === 'bullets'}
					<svelte:element
						this={block[0] === 'steps' ? 'ol' : 'ul'}
						class="flex flex-col gap-1.5 pl-5 text-sm leading-relaxed {block[0] === 'steps'
							? 'list-decimal'
							: 'list-disc'}"
					>
						{#each block[1] as item}
							<li>
								{#each parts(item) as p}{#if p.kind === 'bold'}<b>{p.text}</b
										>{:else if p.kind === 'code'}<code
											class="rounded bg-gray-100 dark:bg-gray-850 px-1 text-[0.8125rem]"
											>{p.text}</code
										>{:else}{p.text}{/if}{/each}
							</li>
						{/each}
					</svelte:element>
				{:else if block[0] === 'tip' || block[0] === 'note' || block[0] === 'warn'}
					<p class="rounded-r-xl border-l-4 px-3 py-2 text-sm leading-relaxed {BOX[block[0]]}">
						{#each parts(block[1]) as p}{#if p.kind === 'bold'}<b>{p.text}</b
								>{:else if p.kind === 'code'}<code>{p.text}</code>{:else}{p.text}{/if}{/each}
					</p>
				{:else if block[0] === 'code'}
					<pre
						class="overflow-x-auto rounded-xl bg-gray-50 dark:bg-gray-900 p-3 font-mono text-xs leading-relaxed">{block[1].join(
							'\n'
						)}</pre>
				{:else if block[0] === 'img'}
					<figure class="flex flex-col gap-1">
						<img
							class="w-full max-w-3xl rounded-xl border border-gray-100 dark:border-gray-850"
							src={image(block[1])}
							alt={block[2]}
							loading="lazy"
						/>
						<figcaption class="text-xs text-gray-500">{block[2]}</figcaption>
					</figure>
				{:else if block[0] === 'table'}
					<div class="overflow-x-auto rounded-xl border border-gray-100 dark:border-gray-850">
						<table class="w-full text-sm">
							<thead class="bg-gray-50 dark:bg-gray-900 text-left">
								<tr>
									{#each block[1] as head}<th class="px-3 py-2 font-medium">{head}</th>{/each}
								</tr>
							</thead>
							<tbody>
								{#each block[2] as row}
									<tr class="border-t border-gray-100 dark:border-gray-850 align-top">
										{#each row as cell}
											<td class="px-3 py-2">
												{#each parts(cell) as p}{#if p.kind === 'bold'}<b>{p.text}</b
														>{:else if p.kind === 'code'}<code
															class="rounded bg-gray-100 dark:bg-gray-850 px-1 text-[0.8125rem]"
															>{p.text}</code
														>{:else}{p.text}{/if}{/each}
											</td>
										{/each}
									</tr>
								{/each}
							</tbody>
						</table>
					</div>
				{/if}
			{/each}
		</section>
	{/each}
</div>
