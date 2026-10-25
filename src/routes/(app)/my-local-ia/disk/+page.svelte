<script lang="ts">
	import { getContext, onMount } from 'svelte';
	import { toast } from 'svelte-sonner';

	import { removeInstalled, type InstalledModel } from '$lib/apis/my-local-ia';
	import { user } from '$lib/stores';
	import Spinner from '$lib/components/common/Spinner.svelte';
	import LevelBadge from '$lib/components/my-local-ia/LevelBadge.svelte';
	import { formatGb } from '$lib/components/my-local-ia/labels';
	import {
		diskStatus,
		installedModels,
		loadDisk,
		loadInstalled
	} from '$lib/components/my-local-ia/store';

	const i18n = getContext('i18n');

	let loading = true;
	let selected: Record<string, boolean> = {};
	let removing = false;

	const LEVEL_STYLE = {
		ok: 'text-emerald-600 dark:text-emerald-400 bg-emerald-500/10',
		warning: 'text-amber-700 dark:text-amber-300 bg-amber-500/10',
		critical: 'text-red-700 dark:text-red-300 bg-red-500/10',
		blocked: 'text-red-700 dark:text-red-300 bg-red-500/15'
	};

	$: status = $diskStatus;
	$: models = Object.values($installedModels).sort((a, b) => b.size_gb - a.size_gb);
	$: freed = models.filter((m) => selected[m.name]).reduce((sum, m) => sum + m.size_gb, 0);
	$: previewUsed = status ? status.used_gb - freed : 0;
	$: previewPct = status && status.total_gb ? (100 * previewUsed) / status.total_gb : 0;
	$: share = (gb: number | null) =>
		status && status.total_gb ? `${(100 * Math.max(0, gb ?? 0)) / status.total_gb}%` : '0%';

	// Each part is capped by what is left of the used space, so the bar never overflows
	// (Ollama may keep its models on another disk than the one measured).
	$: bar = status
		? (() => {
				let left = Math.max(0, status.used_gb - freed);
				return [
					{ color: 'bg-gray-400', gb: status.other_gb },
					{ color: 'bg-slate-500', gb: status.app_gb },
					{ color: 'bg-blue-600', gb: (status.models_gb ?? 0) - freed }
				].map((part) => {
					const gb = Math.min(Math.max(0, part.gb), left);
					left -= gb;
					return { ...part, gb };
				});
			})()
		: [];
	$: legend = status
		? [
				{ color: 'bg-blue-600', label: $i18n.t('AI models'), gb: (status.models_gb ?? 0) - freed },
				{
					color: 'bg-slate-500',
					label: $i18n.t('Open WebUI (files, chats, document search)'),
					gb: status.app_gb
				},
				{ color: 'bg-gray-400', label: $i18n.t('System and other files'), gb: status.other_gb },
				{
					color: 'bg-gray-100 dark:bg-gray-800 border border-gray-300',
					label: $i18n.t('Free'),
					gb: status.free_gb + freed
				}
			]
		: [];

	const levelLabel = (level: string) => {
		switch (level) {
			case 'warning':
				return $i18n.t('Attention');
			case 'critical':
				return $i18n.t('Critical');
			case 'blocked':
				return $i18n.t('Downloads blocked');
			default:
				return $i18n.t('All good');
		}
	};

	const suggestionLabel = (model: InstalledModel) => {
		if (model.protected) return $i18n.t('Protected: used by document search');
		switch (model.suggestion) {
			case 'unused':
				return $i18n.t('Not used recently');
			case 'heavy':
				return $i18n.t('Heavy here; a lighter model may do the same');
			case 'rarely_used':
				return $i18n.t('Rarely used');
			default:
				return '';
		}
	};

	const lastUsed = (model: InstalledModel) =>
		model.last_used
			? new Date(model.last_used * 1000).toLocaleDateString($i18n.language)
			: $i18n.t('never');

	const canRemove = (model: InstalledModel) =>
		!model.protected && ($user?.role === 'admin' || model.downloaded_by?.user_id === $user?.id);

	const removeSelected = async () => {
		removing = true;
		for (const model of models.filter((m) => selected[m.name])) {
			try {
				await removeInstalled(localStorage.token, model.name);
				toast.success($i18n.t('{{name}} removed', { name: model.name }));
			} catch (e) {
				const code = `${e}`;
				toast.error(
					`${model.name}: ${
						code === 'not_yours'
							? $i18n.t('Only an administrator or the person who downloaded it can remove it.')
							: code === 'used_by_others'
								? $i18n.t('Other people used this model recently. Ask an administrator.')
								: code
					}`
				);
			}
		}
		selected = {};
		await Promise.all([loadInstalled(true), loadDisk(true)]);
		removing = false;
	};

	onMount(async () => {
		await Promise.all([loadDisk(true), loadInstalled(true)]);
		loading = false;
	});
</script>

{#if loading}
	<div class="flex justify-center py-20"><Spinner className="size-6" /></div>
{:else if !status}
	<p class="py-10 text-sm text-gray-500">{$i18n.t('Could not read the disk status.')}</p>
{:else}
	<div class="flex flex-col gap-8">
		<header class="flex flex-col gap-1">
			<h1 class="text-2xl font-semibold">{$i18n.t('Disk space')}</h1>
			<p class="text-gray-600 dark:text-gray-300">
				{$i18n.t('Everyone can see this page. It is checked every few minutes.')}
			</p>
		</header>

		<section
			class="flex flex-col gap-4 rounded-2xl border border-gray-100 dark:border-gray-850 p-5"
		>
			<div class="flex flex-wrap items-baseline gap-x-4 gap-y-1">
				<span class="text-4xl font-semibold tabular-nums"
					>{Math.round(freed ? previewPct : status.used_pct)}%</span
				>
				<span class="text-gray-600 dark:text-gray-300"
					>{$i18n.t('{{used}} of {{total}} used', {
						used: formatGb(freed ? previewUsed : status.used_gb, $i18n.language),
						total: formatGb(status.total_gb, $i18n.language)
					})}</span
				>
				<span class="rounded-full px-2.5 py-0.5 text-xs font-medium {LEVEL_STYLE[status.level]}"
					>{levelLabel(status.level)}</span
				>
				{#if freed > 0}
					<span class="text-sm font-medium text-blue-700 dark:text-blue-300"
						>{$i18n.t('Preview: after removing the selected models')}</span
					>
				{/if}
			</div>

			<div class="relative pt-4">
				<div class="flex h-5 overflow-hidden rounded-lg bg-gray-100 dark:bg-gray-800">
					{#each bar as segment}
						<div class={segment.color} style="width: {share(segment.gb)}"></div>
					{/each}
				</div>
				{#each [[status.warning_pct, 'border-amber-500'], [status.critical_pct, 'border-red-500'], [status.block_pct, 'border-gray-700 dark:border-gray-300']] as [pct, color]}
					<div class="absolute top-0 h-10 border-l-2 border-dashed {color}" style="left: {pct}%">
						<span class="absolute -top-1 left-1 whitespace-nowrap text-[0.625rem] text-gray-500"
							>{pct}%</span
						>
					</div>
				{/each}
			</div>

			<div class="flex flex-wrap gap-x-5 gap-y-1 text-xs text-gray-600 dark:text-gray-300">
				{#each legend as item}
					<span class="flex items-center gap-1.5">
						<span class="size-2.5 rounded-sm {item.color}"></span>
						{item.label}
						<b>{formatGb(item.gb, $i18n.language)}</b>
					</span>
				{/each}
			</div>

			{#if status.days_to_block}
				<p class="rounded-xl bg-gray-50 dark:bg-gray-900 px-3 py-2 text-sm">
					{$i18n.t(
						'Usage grew {{growth}} per day recently. At this pace the disk reaches {{block}}% in about {{days}} days, and new downloads will be blocked.',
						{
							growth: formatGb(status.growth_gb_per_day, $i18n.language),
							block: status.block_pct,
							days: Math.round(status.days_to_block)
						}
					)}
				</p>
			{/if}
			{#if !status.models_mounted}
				<p class="text-xs text-gray-500">
					{$i18n.t(
						"Measuring the disk of Open WebUI's data. To measure the disk of the Ollama models, install with the my-local-ia installer (it mounts the models folder)."
					)}
				</p>
			{/if}
		</section>

		<section class="flex flex-col gap-3">
			<div class="flex flex-wrap items-end justify-between gap-3">
				<div>
					<h2 class="text-lg font-semibold">{$i18n.t('Installed models')}</h2>
					<p class="text-sm text-gray-500">
						{$i18n.t('Largest first. Suggestions to free space are highlighted.')}
					</p>
				</div>
				<button
					type="button"
					disabled={freed === 0 || removing}
					class="rounded-xl bg-red-600 px-4 py-2 text-sm font-medium text-white disabled:opacity-40"
					on:click={removeSelected}
				>
					{#if removing}<Spinner className="size-4 inline" />{/if}
					{freed > 0
						? $i18n.t('Remove selected · frees {{size}}', {
								size: formatGb(freed, $i18n.language)
							})
						: $i18n.t('Select models to remove')}
				</button>
			</div>

			<div class="overflow-x-auto rounded-2xl border border-gray-100 dark:border-gray-850">
				<table class="w-full min-w-[52rem] text-sm">
					<thead class="text-left text-xs text-gray-500">
						<tr>
							<th class="px-3 py-2 w-8"><span class="sr-only">{$i18n.t('Remove')}</span></th>
							<th class="px-3 py-2 font-medium">{$i18n.t('Model')}</th>
							<th class="px-3 py-2 font-medium">{$i18n.t('Size')}</th>
							<th class="px-3 py-2 font-medium">{$i18n.t('How it runs here')}</th>
							<th class="px-3 py-2 font-medium">{$i18n.t('Last used')}</th>
							<th class="px-3 py-2 font-medium">{$i18n.t('Answers in 30 days')}</th>
							<th class="px-3 py-2 font-medium">{$i18n.t('Downloaded by')}</th>
							<th class="px-3 py-2 font-medium">{$i18n.t('Suggestion')}</th>
						</tr>
					</thead>
					<tbody>
						{#each models as model (model.name)}
							<tr
								class="border-t border-gray-100 dark:border-gray-850 {selected[model.name]
									? 'bg-red-500/5'
									: ''}"
							>
								<td class="px-3 py-2">
									<input
										type="checkbox"
										aria-label={$i18n.t('Remove {{name}}', { name: model.name })}
										disabled={!canRemove(model)}
										bind:checked={selected[model.name]}
									/>
								</td>
								<td class="px-3 py-2 font-medium">{model.name}</td>
								<td class="px-3 py-2 tabular-nums">{formatGb(model.size_gb, $i18n.language)}</td>
								<td class="px-3 py-2"><LevelBadge level={model.estimate.level} /></td>
								<td class="px-3 py-2 text-gray-600 dark:text-gray-300">{lastUsed(model)}</td>
								<td class="px-3 py-2 tabular-nums">{model.uses_30d}</td>
								<td class="px-3 py-2 text-gray-600 dark:text-gray-300"
									>{model.downloaded_by?.user_name ?? '—'}</td
								>
								<td
									class="px-3 py-2 text-xs font-medium {model.protected
										? 'text-gray-500'
										: 'text-orange-600 dark:text-orange-400'}">{suggestionLabel(model)}</td
								>
							</tr>
						{/each}
					</tbody>
				</table>
			</div>
			<p class="text-xs text-gray-500">
				{$i18n.t(
					'Administrators can remove any model. Users can remove only the models they downloaded and nobody else used recently. Models used by document search are protected.'
				)}
			</p>
		</section>
	</div>
{/if}
