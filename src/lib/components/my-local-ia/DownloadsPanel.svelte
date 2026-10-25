<script lang="ts">
	// Progress of the downloads running on the server, under the disk meter. Downloads go on
	// when their window is closed or the page changes; this is where everyone follows them.
	import { getContext, onDestroy, onMount } from 'svelte';
	import { toast } from 'svelte-sonner';

	import { cancelDownload, type Download } from '$lib/apis/my-local-ia';
	import { user } from '$lib/stores';
	import { formatGb } from './labels';
	import { downloads, onDownloadsFinished, refreshDownloads, watchDownloads } from './store';

	const i18n = getContext('i18n');

	let stopListening: () => void = () => {};

	onMount(() => {
		watchDownloads();
		stopListening = onDownloadsFinished((finished) => {
			for (const d of finished) {
				if (d.status === 'done') {
					toast.success(
						$i18n.t('{{name}} downloaded. It is now in the model list.', { name: d.display_name })
					);
				} else if (d.status === 'error') {
					toast.error(`${d.display_name}: ${d.error ?? $i18n.t('The download did not finish.')}`);
				}
			}
		});
	});
	onDestroy(() => stopListening());

	const canCancel = (d: Download) =>
		d.status === 'downloading' && ($user?.role === 'admin' || d.user_id === $user?.id);

	const cancel = async (d: Download) => {
		try {
			await cancelDownload(localStorage.token, d.name);
			toast.info($i18n.t('Download of {{name}} cancelled.', { name: d.display_name }));
		} catch (e) {
			toast.error(`${e}`);
		}
		await refreshDownloads();
	};

	const amount = (d: Download) =>
		d.total
			? `${formatGb(d.completed / 1e9, $i18n.language)} / ${formatGb(d.total / 1e9, $i18n.language)}`
			: d.message;
</script>

{#if $downloads.length}
	<div class="mx-1 mb-1 flex flex-col gap-2 rounded-xl px-2.5 py-2 text-xs" aria-live="polite">
		<span class="font-medium">{$i18n.t('Downloads')}</span>
		{#each $downloads as d (d.name)}
			<div class="flex flex-col gap-1">
				<div class="flex items-center justify-between gap-2">
					<span class="truncate" title={d.name}>{d.display_name}</span>
					{#if d.status === 'downloading'}
						<span class="tabular-nums text-gray-500">{Math.round(d.percent)}%</span>
					{:else if d.status === 'done'}
						<span class="text-emerald-600 dark:text-emerald-400">{$i18n.t('Ready')}</span>
					{:else if d.status === 'cancelled'}
						<span class="text-gray-500">{$i18n.t('Cancelled')}</span>
					{:else}
						<span class="text-red-600 dark:text-red-400">{$i18n.t('Failed')}</span>
					{/if}
				</div>
				{#if d.status === 'downloading'}
					<div
						class="h-1.5 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-800"
						role="progressbar"
						aria-label={d.display_name}
						aria-valuemin="0"
						aria-valuemax="100"
						aria-valuenow={Math.round(d.percent)}
					>
						<div class="h-full bg-blue-600 transition-all" style="width: {d.percent}%"></div>
					</div>
					<div class="flex items-center justify-between gap-2 text-gray-500">
						<span class="truncate">{amount(d)} · {d.user_name}</span>
						{#if canCancel(d)}
							<button
								type="button"
								class="shrink-0 underline hover:text-red-600"
								on:click={() => cancel(d)}>{$i18n.t('Cancel')}</button
							>
						{/if}
					</div>
				{:else if d.status === 'error' && d.error}
					<span class="text-gray-500 line-clamp-2" title={d.error}>{d.error}</span>
				{/if}
			</div>
		{/each}
	</div>
{/if}
