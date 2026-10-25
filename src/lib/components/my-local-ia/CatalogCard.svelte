<script lang="ts">
	import { getContext } from 'svelte';
	import { goto } from '$app/navigation';

	import type { CatalogModel } from '$lib/apis/my-local-ia';
	import LevelBadge from './LevelBadge.svelte';
	import {
		LEVEL_BAR,
		categoryLabel,
		formatGb,
		localized,
		noSpeedLabel,
		placementLabel
	} from './labels';

	const i18n = getContext('i18n');

	export let model: CatalogModel;
	export let installedAs: string | null = null;
	export let canDownload = false;
	export let onDownload: (model: CatalogModel) => void = () => {};

	$: t = (key: string) => $i18n.t(key);
	$: estimate = model.estimate;
	$: addedOn = model.meta?.added
		? new Date(model.meta.added * 1000).toLocaleDateString($i18n.language)
		: '';
</script>

<article
	class="flex flex-col gap-2 rounded-2xl border border-gray-100 dark:border-gray-850 p-4 bg-white dark:bg-gray-900"
>
	<div class="flex items-start justify-between gap-2">
		<h3 class="font-medium leading-tight">{model.name}</h3>
		<LevelBadge level={estimate.level} />
	</div>

	<div class="flex flex-wrap gap-x-3 gap-y-0.5 text-xs text-gray-500">
		<span
			>{categoryLabel(t, model.category)}{model.reasoning ? ` · ${$i18n.t('reasons')}` : ''}</span
		>
		<span>{formatGb(model.size_gb, $i18n.language)} · {placementLabel(t, estimate.placement)}</span>
		{#if model.source === 'auto'}
			<span class="font-medium text-orange-600 dark:text-orange-400">{$i18n.t('New')}</span>
		{/if}
	</div>

	<div class="flex items-center gap-2 text-xs text-gray-600 dark:text-gray-300">
		<div class="h-1.5 flex-1 overflow-hidden rounded-full bg-gray-100 dark:bg-gray-800">
			<div class="h-full {LEVEL_BAR[estimate.level]}" style="width: {estimate.score}%"></div>
		</div>
		<span class="tabular-nums">{estimate.score}/100</span>
	</div>

	<div class="text-xs">
		<span class="rounded-md bg-gray-100 dark:bg-gray-850 px-2 py-0.5">
			{#if estimate.tps}
				{$i18n.t('Estimated')} ~{Math.round(estimate.tps)} {$i18n.t('tokens/s')}
			{:else}
				{noSpeedLabel(t, model.category)}
			{/if}
		</span>
		{#if estimate.tight_vram}
			<span class="ml-1 text-amber-700 dark:text-amber-300"
				>{$i18n.t('little room left for long conversations')}</span
			>
		{/if}
	</div>

	<p class="text-sm text-gray-700 dark:text-gray-300">
		{localized(model.description, $i18n.language)}
	</p>
	<div class="text-sm">
		<span class="font-medium">{$i18n.t('Use for')}:</span>
		{localized(model.use_for, $i18n.language)}
	</div>
	{#if model.unsure}
		<div class="text-xs text-gray-500">
			{$i18n.t('Summary based on the model name only; check the model card.')}
		</div>
	{/if}
	{#if model.source === 'auto'}
		<div class="text-xs text-gray-500">
			{$i18n.t('Found by the robot on Hugging Face on {{date}}. Estimated numbers.', {
				date: addedOn
			})}
		</div>
	{/if}

	<div class="mt-auto flex flex-wrap gap-2 pt-1">
		{#if installedAs}
			<button
				type="button"
				class="flex-1 rounded-xl border border-gray-200 dark:border-gray-700 px-3 py-1.5 text-sm font-medium"
				on:click={() => goto(`/?model=${encodeURIComponent(installedAs ?? '')}`)}
				>{$i18n.t('Installed · Use')}</button
			>
		{:else if model.ollama && estimate.level !== 'wont_run' && canDownload}
			<button
				type="button"
				class="flex-1 rounded-xl bg-black px-3 py-1.5 text-sm font-medium text-white dark:bg-white dark:text-black"
				on:click={() => onDownload(model)}
				>{$i18n.t('Download ({{size}})', { size: formatGb(model.size_gb, $i18n.language) })}</button
			>
		{:else if estimate.level === 'wont_run'}
			<button
				type="button"
				disabled
				class="flex-1 rounded-xl bg-gray-100 dark:bg-gray-850 px-3 py-1.5 text-sm text-gray-500"
				>{$i18n.t('Does not fit this server')}</button
			>
		{:else if !model.ollama}
			<a
				class="flex-1 rounded-xl border border-gray-200 dark:border-gray-700 px-3 py-1.5 text-center text-sm"
				href={`https://huggingface.co/models?search=${encodeURIComponent(model.name)}`}
				target="_blank"
				rel="noopener">{$i18n.t('Find on Hugging Face')} ↗</a
			>
		{/if}
		{#if estimate.tps}
			<a
				class="rounded-xl border border-gray-200 dark:border-gray-700 px-3 py-1.5 text-sm font-medium"
				href={`/my-local-ia/simulator?models=${encodeURIComponent(model.id)}`}
				>{$i18n.t('Simulate')}</a
			>
		{/if}
	</div>
</article>
