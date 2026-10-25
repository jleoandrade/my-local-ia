<script lang="ts">
	// Downloads a catalog model into Ollama: checks the disk first and, when it does not fit,
	// offers a smaller model of the same kind or removing models nobody uses.
	import { getContext } from 'svelte';
	import { toast } from 'svelte-sonner';

	import {
		cancelDownload,
		checkPull,
		removeInstalled,
		startDownload,
		type Alternative,
		type PullCheck
	} from '$lib/apis/my-local-ia';
	import Modal from '$lib/components/common/Modal.svelte';
	import Spinner from '$lib/components/common/Spinner.svelte';
	import LevelBadge from './LevelBadge.svelte';
	import { formatGb } from './labels';
	import { downloads, loadDisk, loadInstalled, refreshDownloads } from './store';

	const i18n = getContext('i18n');

	export let show = false;
	export let entry: { id: string; name: string; size_gb: number } | null = null;
	export let onDone: () => void = () => {};

	let checking = false;
	let check: PullCheck | null = null;
	let choice = 0;
	// Name of the server download this window follows; closing the window does not stop it.
	let jobName: string | null = null;

	$: job = jobName ? ($downloads.find((d) => d.name === jobName) ?? null) : null;
	$: downloading = !!jobName;
	$: progress = Math.round(job?.percent ?? 0);
	$: statusText = job?.message || $i18n.t('Starting…');
	$: if (job && job.status !== 'downloading') finished(job.status);

	$: if (show && entry) start();

	const start = async () => {
		if (checking || downloading || check) return;
		checking = true;
		try {
			check = await checkPull(localStorage.token, { catalog_id: entry?.id });
		} catch (e) {
			toast.error(errorText(`${e}`));
			show = false;
		}
		checking = false;
	};

	const errorText = (code: string) => {
		switch (code) {
			case 'downloads_disabled':
				return $i18n.t('Downloads are turned off for users. Ask an administrator.');
			case 'no_space':
				return $i18n.t('Not enough disk space for this model.');
			case 'not_yours':
				return $i18n.t('Only an administrator or the person who downloaded it can remove it.');
			case 'used_by_others':
				return $i18n.t('Other people used this model recently. Ask an administrator.');
			default:
				return code.startsWith('protected')
					? $i18n.t('This model is in use by Open WebUI (document search) and cannot be removed.')
					: code;
		}
	};

	const download = async (catalogId: string, name: string) => {
		try {
			const started = await startDownload(localStorage.token, { catalog_id: catalogId });
			jobName = started.name;
			await refreshDownloads();
		} catch (e) {
			toast.error(errorText(`${e}`));
		}
	};

	// The toast for a finished download comes from the panel under the disk meter.
	const finished = async (status: string) => {
		jobName = null;
		if (status === 'done') {
			await Promise.all([loadInstalled(true), loadDisk(true)]);
			onDone();
			close();
		}
	};

	const cancel = async () => {
		if (!jobName) return;
		try {
			await cancelDownload(localStorage.token, jobName);
		} catch (e) {
			toast.error(`${e}`);
		}
		jobName = null;
		await refreshDownloads();
	};

	const run = async (alternative: Alternative | null) => {
		if (!entry) return;
		if (alternative?.kind === 'smaller' && alternative.entry) {
			return download(alternative.entry.id, alternative.entry.name);
		}
		if (alternative?.kind === 'free_space') {
			for (const name of alternative.remove) {
				try {
					await removeInstalled(localStorage.token, name);
				} catch (e) {
					toast.error(`${name}: ${errorText(`${e}`)}`);
					return;
				}
			}
		}
		return download(entry.id, entry.name);
	};

	// Only hides the window: a running download goes on and shows under the disk meter.
	const close = () => {
		show = false;
		check = null;
		choice = 0;
		jobName = null;
	};
</script>

<Modal size="sm" bind:show onRequestClose={close}>
	{#if entry}
		<div class="flex flex-col gap-3 px-5 py-4">
			{#if checking || !check}
				<div class="flex items-center justify-between gap-2 text-sm">
					<span class="flex items-center gap-2">
						<Spinner className="size-4" />
						{$i18n.t('Checking the disk…')}
					</span>
					<!-- The dialog traps focus, so it always needs something focusable. -->
					<button
						class="px-3.5 py-1.5 text-sm rounded-full bg-gray-100 dark:bg-gray-850"
						type="button"
						on:click={close}>{$i18n.t('Cancel')}</button
					>
				</div>
			{:else if downloading}
				<h2 class="text-lg font-medium">{$i18n.t('Downloading {{name}}', { name: entry.name })}</h2>
				<div class="h-2 overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
					<div class="h-full bg-emerald-500 transition-all" style="width: {progress}%"></div>
				</div>
				<div class="flex justify-between text-xs text-gray-500">
					<span>{statusText}</span><span>{progress}%</span>
				</div>
				<p class="text-xs text-gray-500">
					{$i18n.t(
						'You can close this window: the download goes on on the server and its progress shows under the disk meter.'
					)}
				</p>
				<div class="flex justify-end gap-2">
					<button
						class="px-3.5 py-1.5 text-sm rounded-full hover:bg-gray-100 dark:hover:bg-gray-850"
						type="button"
						on:click={cancel}>{$i18n.t('Cancel download')}</button
					>
					<button
						class="px-3.5 py-1.5 text-sm rounded-full bg-gray-100 dark:bg-gray-850"
						type="button"
						on:click={close}>{$i18n.t('Close')}</button
					>
				</div>
			{:else if check.check.fits}
				<h2 class="text-lg font-medium">{$i18n.t('Download {{name}}?', { name: entry.name })}</h2>
				<p class="text-sm text-gray-600 dark:text-gray-300">
					{$i18n.t('It takes about {{size}}. Afterwards the disk will be at {{pct}}%.', {
						size: formatGb(entry.size_gb, $i18n.language),
						pct: Math.round(check.check.used_pct_after)
					})}
				</p>
				<div class="flex justify-end gap-2">
					<button
						class="px-3.5 py-1.5 text-sm rounded-full bg-gray-100 dark:bg-gray-850"
						type="button"
						on:click={close}>{$i18n.t('Cancel')}</button
					>
					<button
						class="px-3.5 py-1.5 text-sm font-medium rounded-full bg-black text-white dark:bg-white dark:text-black"
						type="button"
						on:click={() => run(null)}>{$i18n.t('Download')}</button
					>
				</div>
			{:else}
				<div class="text-xs font-semibold uppercase tracking-wide text-red-600 dark:text-red-400">
					{$i18n.t('Not enough space')}
				</div>
				<h2 class="text-lg font-medium">
					{$i18n.t('{{name}} cannot be downloaded right now', { name: entry.name })}
				</h2>
				<p class="text-sm text-gray-600 dark:text-gray-300">
					{$i18n.t(
						'It takes {{size}}. After the download the disk would be at {{pct}}%, over the {{block}}% limit set by the administrator.',
						{
							size: formatGb(entry.size_gb, $i18n.language),
							pct: Math.round(check.check.used_pct_after),
							block: Math.round(check.check.block_pct)
						}
					)}
				</p>

				{#if check.alternatives.length === 0}
					<p class="text-sm">
						{$i18n.t(
							'No alternative fits either. Remove models on the "Disk space" page or ask an administrator.'
						)}
					</p>
				{:else}
					<div class="flex flex-col gap-2" role="radiogroup">
						{#each check.alternatives as alternative, idx}
							<button
								type="button"
								role="radio"
								aria-checked={choice === idx}
								class="flex flex-col gap-1 rounded-xl border-2 px-3 py-2 text-left text-sm transition {choice ===
								idx
									? 'border-black dark:border-white'
									: 'border-gray-100 dark:border-gray-800'}"
								on:click={() => (choice = idx)}
							>
								{#if alternative.kind === 'smaller' && alternative.entry && alternative.estimate}
									<span class="text-xs font-semibold uppercase text-gray-500"
										>{$i18n.t('Similar, smaller model')}</span
									>
									<span class="flex items-center gap-2 font-medium">
										{alternative.entry.name}
										<LevelBadge level={alternative.estimate.level} />
									</span>
									<span class="text-xs text-gray-500">
										{formatGb(alternative.entry.size_gb, $i18n.language)}
										{#if alternative.estimate.tps}
											· ~{Math.round(alternative.estimate.tps)} {$i18n.t('tokens/s')}{/if}
										· {$i18n.t('disk at {{pct}}%', { pct: Math.round(alternative.used_pct_after) })}
									</span>
								{:else}
									<span class="text-xs font-semibold uppercase text-gray-500"
										>{$i18n.t('Free space and download the original')}</span
									>
									<span class="font-medium"
										>{$i18n.t('Remove {{count}} unused model(s)', {
											count: alternative.remove.length
										})} · {$i18n.t('frees {{size}}', {
											size: formatGb(alternative.frees_gb, $i18n.language)
										})}</span
									>
									<span class="text-xs text-gray-500"
										>{alternative.remove.join(', ')} · {$i18n.t('disk at {{pct}}%', {
											pct: Math.round(alternative.used_pct_after)
										})}</span
									>
								{/if}
							</button>
						{/each}
					</div>
				{/if}

				<div class="flex justify-end gap-2">
					<button
						class="px-3.5 py-1.5 text-sm rounded-full bg-gray-100 dark:bg-gray-850"
						type="button"
						on:click={close}>{$i18n.t('Cancel')}</button
					>
					{#if check.alternatives.length > 0}
						<button
							class="px-3.5 py-1.5 text-sm font-medium rounded-full bg-black text-white dark:bg-white dark:text-black"
							type="button"
							on:click={() => run(check?.alternatives[choice] ?? null)}
						>
							{check.alternatives[choice]?.kind === 'free_space'
								? $i18n.t('Remove and download')
								: $i18n.t('Download {{name}}', {
										name: check.alternatives[choice]?.entry?.name ?? ''
									})}
						</button>
					{/if}
				</div>
			{/if}
		</div>
	{/if}
</Modal>
