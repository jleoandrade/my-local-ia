<script lang="ts">
	// "Before sending": what the attached files will cost with the selected model on this server.
	import { getContext, onMount } from 'svelte';

	import { formatSeconds } from './labels';
	import { findInstalled, installedModels, loadInstalled } from './store';

	const i18n = getContext('i18n');

	export let files: any[] = [];
	export let modelId: string | undefined = undefined;

	// What a vision model reads for one image, in tokens (depends on the model; order of magnitude).
	const IMAGE_TOKENS = 800;

	$: model = findInstalled($installedModels, modelId);
	$: prefill = model?.estimate?.prefill_tps ?? null;

	const tokensOf = (file: any) => {
		const content = file?.file?.data?.content;
		if (typeof content === 'string' && content.length > 0) return Math.ceil(content.length / 4);
		return Math.ceil((file?.size ?? 0) / 6); // rough: binary formats are larger than their text
	};

	const kindOf = (file: any) => {
		const type = `${file?.content_type ?? file?.file?.meta?.content_type ?? ''}`;
		if (file?.type === 'image' || type.startsWith('image/')) return 'image';
		if (type.startsWith('audio/') || type.startsWith('video/')) return 'audio';
		return 'document';
	};

	$: rows = files
		.filter((file) => file?.status !== 'uploading' || file?.size)
		.map((file) => {
			const kind = kindOf(file);
			const tokens = kind === 'image' ? IMAGE_TOKENS : kind === 'document' ? tokensOf(file) : 0;
			return { name: file?.name ?? '', kind, tokens };
		});
	$: totalTokens = rows.reduce((sum, row) => sum + row.tokens, 0);
	$: readSeconds = prefill ? totalTokens / prefill : null;
	$: imageWithoutVision = model && model.category !== 'vis' && rows.some((r) => r.kind === 'image');

	onMount(() => {
		loadInstalled();
	});
</script>

{#if model && rows.length > 0}
	<div
		class="mx-2 mt-2 flex flex-col gap-1 rounded-xl border border-gray-100 dark:border-gray-850 px-3 py-2 text-xs text-gray-600 dark:text-gray-300"
	>
		<div class="font-medium text-gray-800 dark:text-gray-100">{$i18n.t('Before sending')}</div>
		{#each rows as row}
			<div class="flex gap-1.5">
				<span class="shrink-0 font-medium truncate max-w-[40%]">{row.name}</span>
				<span>
					{#if row.kind === 'image'}
						{#if model.category === 'vis'}
							{$i18n.t('{{model}} reads images.', { model: model.name })}
						{:else}
							<span class="text-red-600 dark:text-red-400"
								>{$i18n.t('{{model}} does not read images. Choose a vision model to analyze it.', {
									model: model.name
								})}</span
							>
						{/if}
					{:else if row.kind === 'audio'}
						{$i18n.t(
							'Transcribed here on the server before going to the model; it never leaves it.'
						)}
					{:else}
						{$i18n.t('~{{tokens}} tokens to read.', {
							tokens: row.tokens.toLocaleString($i18n.language)
						})}
					{/if}
				</span>
			</div>
		{/each}
		{#if readSeconds !== null && totalTokens > 0 && !imageWithoutVision}
			<div class="pt-0.5 text-gray-500">
				{$i18n.t('{{model}} takes about {{time}} reading before it starts answering.', {
					model: model.name,
					time: formatSeconds(readSeconds, $i18n.language)
				})}
				<a class="underline" href="/my-local-ia/simulator">{$i18n.t('Simulate')}</a>
			</div>
		{/if}
	</div>
{/if}
