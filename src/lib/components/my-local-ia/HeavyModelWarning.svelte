<script lang="ts">
	// Shown when someone picks a model that is heavy here or barely fits the GPU,
	// with the best installed alternative of the same kind.
	import { getContext } from 'svelte';

	import type { InstalledModel } from '$lib/apis/my-local-ia';
	import Modal from '$lib/components/common/Modal.svelte';
	import LevelBadge from './LevelBadge.svelte';
	import { formatGb } from './labels';

	const i18n = getContext('i18n');

	export let show = false;
	export let model: InstalledModel | null = null;
	export let alternative: InstalledModel | null = null;
	export let onUse: () => void = () => {};
	export let onSwap: (name: string) => void = () => {};
</script>

<Modal size="sm" bind:show>
	{#if model}
		<div class="flex flex-col gap-3 px-5 py-4">
			<div class="flex items-center justify-between gap-2">
				<h2 class="text-lg font-medium">
					{#if model.estimate.level === 'usable'}
						{$i18n.t('{{name}} runs, but at the limit', { name: model.name })}
					{:else if model.estimate.level === 'wont_run'}
						{$i18n.t('{{name}} probably will not run here', { name: model.name })}
					{:else}
						{$i18n.t('{{name}} will be slow here', { name: model.name })}
					{/if}
				</h2>
				<LevelBadge level={model.estimate.level} />
			</div>

			<p class="text-sm text-gray-600 dark:text-gray-300">
				{#if model.estimate.level === 'wont_run'}
					{$i18n.t(
						'It needs more memory than this server has (GPU + RAM). It will probably fail to load.'
					)}
				{:else if model.estimate.tight_vram}
					{$i18n.t(
						'It takes almost all the GPU memory. Long conversations or large PDFs may not fit and the speed drops.'
					)}
				{:else}
					{$i18n.t(
						'It has {{size}} and does not fit in the GPU memory: the rest goes to system RAM, which is much slower. Expect about {{tps}} tokens per second.',
						{
							size: formatGb(model.size_gb, $i18n.language),
							tps: Math.max(1, Math.round(model.estimate.tps ?? 0))
						}
					)}
				{/if}
			</p>

			{#if alternative}
				<div class="rounded-xl border border-gray-100 dark:border-gray-800 px-3 py-2 text-sm">
					<div class="text-xs text-gray-500">{$i18n.t('Alternative that runs well here')}</div>
					<div class="font-medium">
						{alternative.name} · ~{Math.round(alternative.estimate.tps ?? 0)}
						{$i18n.t('tokens/s')}
					</div>
				</div>
			{/if}

			<div class="flex flex-wrap justify-end gap-2 pt-1">
				<button
					class="px-3.5 py-1.5 text-sm font-medium rounded-full hover:bg-gray-100 dark:hover:bg-gray-850 transition"
					type="button"
					on:click={() => (show = false)}>{$i18n.t('Cancel')}</button
				>
				<button
					class="px-3.5 py-1.5 text-sm font-medium rounded-full bg-gray-100 hover:bg-gray-200 dark:bg-gray-850 dark:hover:bg-gray-800 transition"
					type="button"
					on:click={() => {
						show = false;
						onUse();
					}}>{$i18n.t('Use it anyway')}</button
				>
				{#if alternative}
					<button
						class="px-3.5 py-1.5 text-sm font-medium rounded-full bg-black text-white dark:bg-white dark:text-black transition"
						type="button"
						on:click={() => {
							show = false;
							onSwap(alternative?.name ?? '');
						}}>{$i18n.t('Switch to {{name}}', { name: alternative.name })}</button
					>
				{/if}
			</div>
		</div>
	{/if}
</Modal>
