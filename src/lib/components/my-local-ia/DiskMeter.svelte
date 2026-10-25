<script lang="ts">
	// Compact disk meter for the sidebar, visible to everyone.
	import { getContext, onDestroy, onMount } from 'svelte';
	import { goto } from '$app/navigation';

	import DownloadsPanel from './DownloadsPanel.svelte';
	import { diskStatus, loadDisk } from './store';

	const i18n = getContext('i18n');

	const STYLE = {
		ok: { bar: 'bg-emerald-500', text: 'text-gray-500 dark:text-gray-400' },
		warning: { bar: 'bg-amber-500', text: 'text-amber-700 dark:text-amber-300' },
		critical: { bar: 'bg-red-500', text: 'text-red-700 dark:text-red-300' },
		blocked: { bar: 'bg-red-600', text: 'text-red-700 dark:text-red-300' }
	};

	let timer: ReturnType<typeof setInterval>;

	onMount(() => {
		loadDisk();
		timer = setInterval(() => loadDisk(true), 5 * 60_000);
	});
	onDestroy(() => clearInterval(timer));
</script>

{#if $diskStatus}
	{@const style = STYLE[$diskStatus.level]}
	<a
		href="/my-local-ia/disk"
		class="mx-1 mb-1 flex flex-col gap-1 rounded-xl px-2.5 py-2 text-xs hover:bg-gray-100 dark:hover:bg-gray-900 transition"
		on:click|preventDefault={() => goto('/my-local-ia/disk')}
	>
		<div class="flex items-baseline justify-between">
			<span class="font-medium">{$i18n.t('Server disk')}</span>
			<span class="font-medium {style.text}">{Math.round($diskStatus.used_pct)}%</span>
		</div>
		<div class="h-1.5 overflow-hidden rounded-full bg-gray-200 dark:bg-gray-800">
			<div class="h-full {style.bar}" style="width: {Math.min(100, $diskStatus.used_pct)}%"></div>
		</div>
		<span class={style.text}>
			{$diskStatus.level === 'ok'
				? $i18n.t('{{free}} GB free', { free: Math.round($diskStatus.free_gb) })
				: $i18n.t('{{free}} GB left · almost full', { free: Math.round($diskStatus.free_gb) })}
		</span>
	</a>
{/if}

<DownloadsPanel />
