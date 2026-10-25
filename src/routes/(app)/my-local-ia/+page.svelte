<script lang="ts">
	import { getContext, onMount } from 'svelte';
	import { goto } from '$app/navigation';

	import {
		getCatalog,
		getHardware,
		getPicks,
		getPublicSettings,
		type CatalogModel,
		type Hardware,
		type Level,
		type Pick
	} from '$lib/apis/my-local-ia';
	import { user } from '$lib/stores';
	import Spinner from '$lib/components/common/Spinner.svelte';
	import CatalogCard from '$lib/components/my-local-ia/CatalogCard.svelte';
	import DownloadDialog from '$lib/components/my-local-ia/DownloadDialog.svelte';
	import LevelBadge from '$lib/components/my-local-ia/LevelBadge.svelte';
	import {
		LEVEL_BAR,
		formatGb,
		levelLabel,
		noSpeedLabel,
		taskLabel,
		taskWhy
	} from '$lib/components/my-local-ia/labels';
	import { installedModels, loadInstalled } from '$lib/components/my-local-ia/store';

	const i18n = getContext('i18n');
	$: t = (key: string) => $i18n.t(key);

	let loading = true;
	let hardware: Hardware | null = null;
	let catalog: CatalogModel[] = [];
	let picks: Pick[] = [];
	let usersCanDownload = false;

	let filter = 'all';
	let level: Level | null = null;
	let query = '';

	let downloadEntry: CatalogModel | null = null;
	let showDownload = false;

	const LEVELS: Level[] = ['smooth', 'usable', 'heavy', 'wont_run'];

	$: canDownload = $user?.role === 'admin' || usersCanDownload;
	$: installedByCatalog = Object.fromEntries(
		Object.values($installedModels)
			.filter((m) => m.catalog_id)
			.map((m) => [m.catalog_id, m.name])
	);

	$: chips = [
		['all', $i18n.t('All')],
		['chat', $i18n.t('Chat')],
		['reasoning', $i18n.t('Reasoning')],
		['vis', $i18n.t('Vision')],
		['code', $i18n.t('Code')],
		['img', $i18n.t('Image')],
		['vid', $i18n.t('Video')],
		['stt', $i18n.t('Speech to text')],
		['tts', $i18n.t('Text to speech')],
		['emb', $i18n.t('Embeddings')],
		['light', $i18n.t('Light (up to 3 GB)')],
		['new', $i18n.t('New')],
		['installed', $i18n.t('Installed')]
	];

	const fold = (text: string) => text.toLowerCase().normalize('NFD').replace(/[̀-ͯ]/g, '');

	$: counts = LEVELS.map((l) => catalog.filter((m) => m.estimate.level === l).length);
	$: shown = catalog.filter((m) => {
		if (level && m.estimate.level !== level) return false;
		if (filter === 'reasoning' && !m.reasoning) return false;
		if (filter === 'light' && m.size_gb > 3) return false;
		if (filter === 'new' && m.source !== 'auto') return false;
		if (filter === 'installed' && !installedByCatalog[m.id]) return false;
		if (
			!['all', 'reasoning', 'light', 'new', 'installed'].includes(filter) &&
			m.category !== filter
		)
			return false;
		if (!query.trim()) return true;
		const text = [
			m.name,
			...Object.values(m.description ?? {}),
			...Object.values(m.use_for ?? {})
		].join(' ');
		return fold(text).includes(fold(query.trim()));
	});

	const load = async () => {
		const token = localStorage.token;
		[hardware, catalog, picks] = await Promise.all([
			getHardware(token),
			getCatalog(token),
			getPicks(token)
		]);
		usersCanDownload =
			(await getPublicSettings(token).catch(() => null))?.users_can_download ?? false;
		await loadInstalled(true);
	};

	onMount(async () => {
		try {
			await load();
		} finally {
			loading = false;
		}
	});

	const openDownload = (entry) => {
		downloadEntry = entry;
		showDownload = true;
	};
</script>

{#if loading}
	<div class="flex justify-center py-20"><Spinner className="size-6" /></div>
{:else}
	<div class="flex flex-col gap-8">
		<header class="flex flex-col gap-3">
			<h1 class="text-2xl font-semibold">{$i18n.t('Does it run on my GPU?')}</h1>
			<p class="text-gray-600 dark:text-gray-300">
				{$i18n.t('What each model is for and how it runs on this server, before you download it.')}
			</p>
			{#if hardware}
				<div
					class="flex flex-wrap items-center gap-x-4 gap-y-1 rounded-2xl border border-gray-100 dark:border-gray-850 px-4 py-3 text-sm"
				>
					<span class="font-medium">{$i18n.t('Detected automatically')}</span>
					{#if hardware.has_gpu}
						<span class="text-gray-600 dark:text-gray-300"
							>{hardware.gpus.map((g) => g.name).join(' + ') || $i18n.t('GPU')} · {formatGb(
								hardware.vram_gb,
								$i18n.language
							)} VRAM</span
						>
					{:else}
						<span class="text-amber-700 dark:text-amber-300"
							>{$i18n.t('No GPU: models run on the CPU')}</span
						>
					{/if}
					<span class="text-gray-600 dark:text-gray-300"
						>{formatGb(hardware.ram_total_gb, $i18n.language)} RAM</span
					>
					{#if hardware.cpu_name}
						<span class="text-gray-500">{hardware.cpu_name}</span>
					{/if}
					{#if $user?.role === 'admin'}
						<a class="ml-auto text-sm font-medium underline" href="/my-local-ia/settings"
							>{$i18n.t('Adjust hardware')}</a
						>
					{/if}
				</div>
			{/if}
			<div class="flex flex-wrap gap-2">
				{#each LEVELS as l, idx}
					<button
						type="button"
						aria-pressed={level === l}
						class="flex items-baseline gap-2 rounded-xl border px-3 py-1.5 text-sm transition {level ===
						l
							? 'border-black dark:border-white'
							: 'border-gray-100 dark:border-gray-850'}"
						on:click={() => (level = level === l ? null : l)}
					>
						<span class="inline-block size-2 rounded-full {LEVEL_BAR[l]}"></span>
						<b>{counts[idx]}</b>
						{levelLabel(t, l)}
					</button>
				{/each}
			</div>
		</header>

		{#if picks.length > 0}
			<section class="flex flex-col gap-3">
				<div>
					<h2 class="text-lg font-semibold">{$i18n.t('Best for this server')}</h2>
					<p class="text-sm text-gray-500">
						{$i18n.t('One pick per task, recalculated for the detected hardware.')}
					</p>
				</div>
				<div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
					{#each picks as pick}
						<article
							class="flex flex-col gap-2 rounded-2xl border border-gray-100 dark:border-gray-850 p-4"
						>
							<span
								class="text-xs font-semibold uppercase tracking-wide text-orange-600 dark:text-orange-400"
								>{taskLabel(t, pick.task)}</span
							>
							<div class="flex items-start justify-between gap-2">
								<h3 class="font-medium">{pick.entry.name}</h3>
								<LevelBadge level={pick.estimate.level} />
							</div>
							<div class="text-xs text-gray-500">
								{formatGb(pick.entry.size_gb, $i18n.language)} ·
								{pick.estimate.tps
									? `~${Math.round(pick.estimate.tps)} ${$i18n.t('tokens/s')}`
									: noSpeedLabel(t, pick.entry.category)}
							</div>
							<p class="text-sm text-gray-600 dark:text-gray-300">{taskWhy(t, pick.task)}</p>
							<div class="mt-auto pt-1">
								{#if pick.installed_as}
									<button
										type="button"
										class="w-full rounded-xl border border-gray-200 dark:border-gray-700 px-3 py-1.5 text-sm font-medium"
										on:click={() => goto(`/?model=${encodeURIComponent(pick.installed_as ?? '')}`)}
										>{$i18n.t('Installed · Use')}</button
									>
								{:else if pick.entry.ollama && canDownload}
									<button
										type="button"
										class="w-full rounded-xl bg-black px-3 py-1.5 text-sm font-medium text-white dark:bg-white dark:text-black"
										on:click={() => openDownload({ ...pick.entry, estimate: pick.estimate })}
										>{$i18n.t('Download ({{size}})', {
											size: formatGb(pick.entry.size_gb, $i18n.language)
										})}</button
									>
								{/if}
							</div>
						</article>
					{/each}
				</div>
			</section>
		{/if}

		<section class="flex flex-col gap-3">
			<div class="flex flex-wrap items-center justify-between gap-3">
				<h2 class="text-lg font-semibold">
					{$i18n.t('Catalog')}
					<span class="text-sm font-normal text-gray-500"
						>{$i18n.t('{{shown}} of {{total}}', {
							shown: shown.length,
							total: catalog.length
						})}</span
					>
				</h2>
				<input
					class="w-64 max-w-full rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-1.5 text-sm outline-hidden"
					type="search"
					placeholder={$i18n.t('Search: qwen, code, vision…')}
					aria-label={$i18n.t('Search the catalog')}
					bind:value={query}
				/>
			</div>
			<div class="flex flex-wrap gap-1.5">
				{#each chips as [id, label]}
					<button
						type="button"
						aria-pressed={filter === id}
						class="rounded-full px-3 py-1 text-sm transition {filter === id
							? 'bg-black text-white dark:bg-white dark:text-black'
							: 'bg-gray-100 dark:bg-gray-850 hover:bg-gray-200 dark:hover:bg-gray-800'}"
						on:click={() => (filter = id)}>{label}</button
					>
				{/each}
			</div>
			{#if shown.length === 0}
				<p class="text-sm text-gray-500">{$i18n.t('No model matches this filter.')}</p>
			{/if}
			<div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
				{#each shown as model (model.id)}
					<CatalogCard
						{model}
						installedAs={installedByCatalog[model.id] ?? null}
						{canDownload}
						onDownload={openDownload}
					/>
				{/each}
			</div>
		</section>

		<p class="text-xs text-gray-500">
			{$i18n.t(
				'Estimates calculated for the detected hardware: tokens per second come from the memory speed of the GPU and RAM. Measure the real speed with llama-bench if you need exact numbers.'
			)}
		</p>
	</div>
{/if}

<DownloadDialog
	bind:show={showDownload}
	entry={downloadEntry}
	onDone={async () => {
		picks = await getPicks(localStorage.token);
	}}
/>
