<script lang="ts">
	// Small badge next to an Ollama model in the model selector: how it runs on this server.
	import { getContext, onMount } from 'svelte';

	import Tooltip from '$lib/components/common/Tooltip.svelte';
	import { LEVEL_STYLE, levelLabel, placementLabel } from './labels';
	import { findInstalled, installedModels, loadInstalled } from './store';

	const i18n = getContext('i18n');

	export let modelId: string;

	$: info = findInstalled($installedModels, modelId);
	$: estimate = info?.estimate;
	$: tooltip = estimate
		? [
				estimate.tps ? $i18n.t('~{{tps}} tokens/s', { tps: Math.round(estimate.tps) }) : '',
				placementLabel((key) => $i18n.t(key), estimate.placement),
				estimate.tight_vram ? $i18n.t('little room left for long conversations') : ''
			]
				.filter(Boolean)
				.join(' · ')
		: '';

	onMount(() => {
		loadInstalled();
	});
</script>

{#if estimate}
	<Tooltip content={tooltip} className="flex items-center">
		<span
			class="whitespace-nowrap rounded-full px-1.5 py-px text-[0.625rem] font-medium {LEVEL_STYLE[
				estimate.level
			]}">{levelLabel((key) => $i18n.t(key), estimate.level)}</span
		>
	</Tooltip>
{/if}
