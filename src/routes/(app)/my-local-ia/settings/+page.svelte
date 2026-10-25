<script lang="ts">
	import { getContext, onMount } from 'svelte';
	import { toast } from 'svelte-sonner';

	import {
		checkDiskNow,
		detectHardware,
		getHardware,
		getRobotStatus,
		getSettings,
		runRobot,
		saveSettings,
		setHardwareOverrides,
		type Hardware,
		type RobotStatus,
		type Settings
	} from '$lib/apis/my-local-ia';
	import { user } from '$lib/stores';
	import Spinner from '$lib/components/common/Spinner.svelte';
	import Switch from '$lib/components/common/Switch.svelte';
	import { formatGb, sourceLabel } from '$lib/components/my-local-ia/labels';
	import { loadDisk, loadInstalled } from '$lib/components/my-local-ia/store';

	const i18n = getContext('i18n');
	$: t = (key: string) => $i18n.t(key);

	const OVERRIDES = [
		'vram_gb',
		'gpu_bandwidth_gbs',
		'gpu_efficiency',
		'ram_for_models_gb',
		'ram_bandwidth_gbs'
	] as const;

	let loading = true;
	let hardware: Hardware | null = null;
	let settings: Settings | null = null;
	let robot: RobotStatus = {};
	let overrides: Record<string, string> = {};
	let sources = '';
	let busy = '';

	$: overrideLabels = {
		vram_gb: $i18n.t('GPU memory (VRAM, GB)'),
		gpu_bandwidth_gbs: $i18n.t('GPU memory speed (GB/s)'),
		gpu_efficiency: $i18n.t('Share of the GPU speed used in practice (0–1)'),
		ram_for_models_gb: $i18n.t('System RAM free for models (GB)'),
		ram_bandwidth_gbs: $i18n.t('System RAM speed, measured (GB/s)')
	};

	const fillOverrides = (hw: Hardware) => {
		overrides = Object.fromEntries(OVERRIDES.map((key) => [key, `${hw[key]}`]));
	};

	const refreshAfterHardware = async (hw: Hardware) => {
		hardware = hw;
		fillOverrides(hw);
		await loadInstalled(true);
	};

	// Says what changed, or what the system still reports, so a resize that did not reach
	// the VM (or a manual value hiding the new one) is obvious.
	const describeChange = (before: Hardware | null, after: Hardware) => {
		const changes: string[] = [];
		const gb = (value: number) => formatGb(value, $i18n.language);
		if (before && before.ram_total_gb !== after.ram_total_gb)
			changes.push(`RAM ${gb(before.ram_total_gb)} → ${gb(after.ram_total_gb)}`);
		if (before && before.vram_gb !== after.vram_gb)
			changes.push(`VRAM ${gb(before.vram_gb)} → ${gb(after.vram_gb)}`);
		if (before && before.cpu_threads !== after.cpu_threads)
			changes.push(`CPU ${before.cpu_threads} → ${after.cpu_threads} threads`);
		return changes.length
			? $i18n.t('Hardware changed: {{changes}}.', { changes: changes.join(' · ') })
			: $i18n.t(
					'Nothing changed: the system reports {{ram}} of RAM and {{vram}} of GPU memory. If you added memory, restart the server so the system sees it.',
					{ ram: gb(after.ram_total_gb), vram: gb(after.vram_gb) }
				);
	};

	const detect = async () => {
		busy = 'detect';
		const before = hardware;
		try {
			const after = await detectHardware(localStorage.token);
			await refreshAfterHardware(after);
			toast.success(describeChange(before, after), { duration: 8000 });
			const manual = OVERRIDES.filter((key) => after.sources?.[key] === 'manual');
			if (manual.length) {
				toast.warning(
					$i18n.t(
						'Values set by hand are still used instead of the detected ones. Click "Use detected values" to drop them.'
					),
					{ duration: 10000 }
				);
			}
		} catch (e) {
			toast.error(`${e}`);
		}
		busy = '';
	};

	const saveOverrides = async () => {
		if (!hardware) return;
		busy = 'overrides';
		const changes: Record<string, number | null> = {};
		for (const key of OVERRIDES) {
			const value = parseFloat(`${overrides[key]}`.replace(',', '.'));
			if (Number.isFinite(value) && value !== hardware[key]) changes[key] = value;
		}
		try {
			await refreshAfterHardware(await setHardwareOverrides(localStorage.token, changes));
			toast.success($i18n.t('Saved. The estimates now use these values.'));
		} catch (e) {
			toast.error(`${e}`);
		}
		busy = '';
	};

	const resetOverrides = async () => {
		busy = 'overrides';
		try {
			await refreshAfterHardware(
				await setHardwareOverrides(
					localStorage.token,
					Object.fromEntries(OVERRIDES.map((key) => [key, null]))
				)
			);
			toast.success($i18n.t('Back to the detected values.'));
		} catch (e) {
			toast.error(`${e}`);
		}
		busy = '';
	};

	const save = async () => {
		if (!settings) return;
		busy = 'settings';
		try {
			settings = await saveSettings(localStorage.token, {
				...settings,
				robot_sources: sources
					.split(',')
					.map((s) => s.trim())
					.filter(Boolean)
			});
			sources = settings.robot_sources.join(', ');
			await loadDisk(true);
			toast.success($i18n.t('Settings saved.'));
		} catch (e) {
			toast.error(
				`${e}`.includes('thresholds')
					? $i18n.t('The disk limits must go up: attention ≤ critical ≤ block downloads.')
					: `${e}`
			);
		}
		busy = '';
	};

	const checkNow = async () => {
		busy = 'disk';
		try {
			await checkDiskNow(localStorage.token);
			await loadDisk(true);
			toast.success($i18n.t('Disk checked; alerts updated.'));
		} catch (e) {
			toast.error(`${e}`);
		}
		busy = '';
	};

	const searchNow = async () => {
		busy = 'robot';
		try {
			robot = await runRobot(localStorage.token);
			if (robot.error) toast.error(robot.error);
			else
				toast.success(
					$i18n.t('{{total}} models found, {{added}} new.', {
						total: robot.total ?? 0,
						added: robot.added ?? 0
					})
				);
		} catch (e) {
			toast.error(`${e}`);
		}
		busy = '';
	};

	onMount(async () => {
		if ($user?.role !== 'admin') {
			loading = false;
			return;
		}
		const token = localStorage.token;
		const [hw, s, r] = await Promise.all([
			getHardware(token),
			getSettings(token),
			getRobotStatus(token).catch(() => ({}))
		]);
		hardware = hw;
		fillOverrides(hw);
		settings = s;
		sources = s.robot_sources.join(', ');
		robot = r;
		loading = false;
	});
</script>

{#if loading}
	<div class="flex justify-center py-20"><Spinner className="size-6" /></div>
{:else if $user?.role !== 'admin'}
	<p class="py-10 text-sm text-gray-500">
		{$i18n.t('Only administrators can change these settings.')}
	</p>
{:else if hardware && settings}
	<div class="flex flex-col gap-10">
		<section class="flex flex-col gap-4">
			<div class="flex flex-wrap items-end justify-between gap-3">
				<div>
					<h1 class="text-2xl font-semibold">{$i18n.t('Hardware of this server')}</h1>
					<p class="text-sm text-gray-500">
						{$i18n.t(
							'Detected at startup and checked again every few minutes. Every rating and estimate comes from these numbers.'
						)}
						{#if hardware.detected_at}
							{$i18n.t('Last detection: {{date}}', {
								date: new Date(hardware.detected_at * 1000).toLocaleString($i18n.language)
							})}
						{/if}
					</p>
				</div>
				<button
					type="button"
					class="rounded-xl bg-black px-4 py-2 text-sm font-medium text-white dark:bg-white dark:text-black"
					disabled={busy !== ''}
					on:click={detect}
					>{#if busy === 'detect'}<Spinner className="size-4 inline" />{/if}
					{$i18n.t('Detect again')}</button
				>
			</div>

			{#if !hardware.has_gpu}
				<p class="rounded-xl bg-amber-500/10 px-4 py-3 text-sm text-amber-800 dark:text-amber-200">
					{$i18n.t(
						'No GPU found: CPU-only mode. Ollama uses system RAM for everything, so estimates use the RAM speed and small or MoE models are the ones that run well.'
					)}
				</p>
			{/if}

			<div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
				<div class="rounded-2xl border border-gray-100 dark:border-gray-850 p-4">
					<div class="text-xs font-medium uppercase text-gray-500">{$i18n.t('GPU')}</div>
					<div class="text-lg font-medium">
						{hardware.gpus.map((g) => g.name).join(' + ') || $i18n.t('None')}
					</div>
					<div class="text-sm text-gray-600 dark:text-gray-300">
						{formatGb(hardware.vram_gb, $i18n.language)} VRAM · {hardware.gpu_bandwidth_gbs} GB/s
					</div>
					<div class="text-xs text-gray-500">
						{sourceLabel(t, hardware.sources.vram_gb)} · {sourceLabel(
							t,
							hardware.sources.gpu_bandwidth_gbs
						)}
					</div>
				</div>
				<div class="rounded-2xl border border-gray-100 dark:border-gray-850 p-4">
					<div class="text-xs font-medium uppercase text-gray-500">RAM</div>
					<div class="text-lg font-medium">{formatGb(hardware.ram_total_gb, $i18n.language)}</div>
					<div class="text-sm text-gray-600 dark:text-gray-300">
						{$i18n.t('{{size}} free for models', {
							size: formatGb(hardware.ram_for_models_gb, $i18n.language)
						})}
					</div>
					<div class="text-xs text-gray-500">
						{sourceLabel(t, hardware.sources.ram_for_models_gb)}
					</div>
				</div>
				<div class="rounded-2xl border border-gray-100 dark:border-gray-850 p-4">
					<div class="text-xs font-medium uppercase text-gray-500">{$i18n.t('RAM speed')}</div>
					<div class="text-lg font-medium">~{hardware.ram_bandwidth_gbs} GB/s</div>
					<div class="text-xs text-gray-500">
						{sourceLabel(t, hardware.sources.ram_bandwidth_gbs)}
					</div>
				</div>
				<div class="rounded-2xl border border-gray-100 dark:border-gray-850 p-4">
					<div class="text-xs font-medium uppercase text-gray-500">CPU</div>
					<div class="text-sm font-medium">{hardware.cpu_name ?? '—'}</div>
					<div class="text-xs text-gray-500">
						{$i18n.t('{{threads}} threads', { threads: hardware.cpu_threads ?? '?' })}
					</div>
				</div>
			</div>

			<details class="rounded-2xl border border-gray-100 dark:border-gray-850 px-4 py-3">
				<summary class="cursor-pointer text-sm font-medium">{$i18n.t('Adjust manually')}</summary>
				<div class="grid gap-3 pt-3 sm:grid-cols-2 lg:grid-cols-3">
					{#each OVERRIDES as key}
						<label class="flex flex-col gap-1 text-xs text-gray-600 dark:text-gray-300">
							{overrideLabels[key]}
							<input
								class="rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-1.5 text-sm"
								inputmode="decimal"
								bind:value={overrides[key]}
							/>
						</label>
					{/each}
				</div>
				<div class="flex flex-wrap gap-2 pt-3">
					<button
						type="button"
						class="rounded-xl bg-black px-4 py-1.5 text-sm font-medium text-white dark:bg-white dark:text-black"
						disabled={busy !== ''}
						on:click={saveOverrides}>{$i18n.t('Save values')}</button
					>
					<button
						type="button"
						class="rounded-xl bg-gray-100 px-4 py-1.5 text-sm dark:bg-gray-850"
						disabled={busy !== ''}
						on:click={resetOverrides}>{$i18n.t('Use detected values')}</button
					>
				</div>
			</details>
		</section>

		<section class="flex flex-col gap-4">
			<h2 class="text-lg font-semibold">{$i18n.t('Downloads')}</h2>
			<label
				class="flex items-center justify-between gap-3 rounded-2xl border border-gray-100 dark:border-gray-850 px-4 py-3 text-sm"
			>
				<span>
					<span class="font-medium">{$i18n.t('Users can download models from the catalog')}</span>
					<span class="block text-xs text-gray-500"
						>{$i18n.t(
							'Administrators can always download. Downloads that do not fit the disk are refused.'
						)}</span
					>
				</span>
				<Switch bind:state={settings.users_can_download} />
			</label>
		</section>

		<section class="flex flex-col gap-4">
			<div class="flex flex-wrap items-end justify-between gap-3">
				<h2 class="text-lg font-semibold">{$i18n.t('Disk monitoring and alerts')}</h2>
				<button
					type="button"
					class="rounded-xl bg-gray-100 px-4 py-1.5 text-sm dark:bg-gray-850"
					disabled={busy !== ''}
					on:click={checkNow}>{$i18n.t('Check now')}</button
				>
			</div>
			<div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
				{#each [['disk_warning_pct', $i18n.t('Attention from (%)')], ['disk_critical_pct', $i18n.t('Critical from (%)')], ['disk_block_pct', $i18n.t('Block downloads above (%)')], ['disk_margin_gb', $i18n.t('Safety margin (GB)')], ['disk_check_minutes', $i18n.t('Check every (minutes)')], ['unused_days', $i18n.t('Suggest removing after unused for (days)')]] as [key, label]}
					<label class="flex flex-col gap-1 text-xs text-gray-600 dark:text-gray-300">
						{label}
						<input
							class="rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-1.5 text-sm"
							type="number"
							min="0"
							bind:value={settings[key]}
						/>
					</label>
				{/each}
			</div>
			<label class="flex items-center justify-between gap-3 text-sm">
				<span>{$i18n.t('Banner at the top for every user while the disk is almost full')}</span>
				<Switch bind:state={settings.alert_banner} />
			</label>
			<label class="flex flex-col gap-1 text-xs text-gray-600 dark:text-gray-300">
				{$i18n.t('Webhook for alerts (Discord, Slack, Teams, Google Chat) — optional')}
				<input
					class="rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-1.5 text-sm"
					type="url"
					placeholder="https://…"
					bind:value={settings.alert_webhook_url}
				/>
			</label>
		</section>

		<section class="flex flex-col gap-4">
			<div class="flex flex-wrap items-end justify-between gap-3">
				<div>
					<h2 class="text-lg font-semibold">{$i18n.t('Robot for new models')}</h2>
					<p class="text-sm text-gray-500">
						{$i18n.t(
							'Looks for models in the Ollama library and on Hugging Face and adds them to the catalog with the rating for this hardware. The ones that run well here come first.'
						)}
					</p>
				</div>
				<button
					type="button"
					class="rounded-xl bg-gray-100 px-4 py-1.5 text-sm dark:bg-gray-850"
					disabled={busy !== ''}
					on:click={searchNow}
					>{#if busy === 'robot'}<Spinner className="size-4 inline" />{/if}
					{$i18n.t('Search now')}</button
				>
			</div>
			<div class="rounded-xl bg-gray-50 dark:bg-gray-900 px-4 py-2 text-sm">
				{#if robot.last_run}
					{$i18n.t('Last search: {{date}} · {{added}} new models', {
						date: new Date(robot.last_run * 1000).toLocaleString($i18n.language),
						added: robot.added ?? 0
					})}
					{#if robot.error}
						<span class="text-red-600 dark:text-red-400"> · {robot.error}</span>
					{/if}
				{:else}
					{$i18n.t('No search yet.')}
				{/if}
			</div>
			<label class="flex items-center justify-between gap-3 text-sm">
				<span>{$i18n.t('Enabled')}</span>
				<Switch bind:state={settings.robot_enabled} />
			</label>
			<div class="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
				<label class="flex flex-col gap-1 text-xs text-gray-600 dark:text-gray-300">
					{$i18n.t('Frequency')}
					<select
						class="rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-1.5 text-sm"
						bind:value={settings.robot_frequency}
					>
						<option value="daily">{$i18n.t('Every day')}</option>
						<option value="weekly">{$i18n.t('Every week')}</option>
						<option value="manual">{$i18n.t('Only manually')}</option>
					</select>
				</label>
				<label class="flex flex-col gap-1 text-xs text-gray-600 dark:text-gray-300">
					{$i18n.t('Time (server clock)')}
					<input
						class="rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-1.5 text-sm"
						type="time"
						bind:value={settings.robot_time}
					/>
				</label>
				<label class="flex flex-col gap-1 text-xs text-gray-600 dark:text-gray-300">
					{$i18n.t('Minimum downloads on Hugging Face')}
					<input
						class="rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-1.5 text-sm"
						type="number"
						min="0"
						bind:value={settings.robot_min_downloads}
					/>
				</label>
				<label class="flex flex-col gap-1 text-xs text-gray-600 dark:text-gray-300">
					{$i18n.t('Maximum new models in the catalog')}
					<input
						class="rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-1.5 text-sm"
						type="number"
						min="1"
						bind:value={settings.robot_max_models}
					/>
				</label>
			</div>
			<label class="flex flex-col gap-1 text-xs text-gray-600 dark:text-gray-300">
				{$i18n.t(
					'Where to look (Hugging Face users that publish GGUF models, separated by commas)'
				)}
				<input
					class="rounded-xl border border-gray-200 dark:border-gray-700 bg-transparent px-3 py-1.5 text-sm"
					bind:value={sources}
				/>
			</label>
			<label class="flex items-center justify-between gap-3 text-sm">
				<span>{$i18n.t('Read the official Ollama library (every model in every size)')}</span>
				<Switch bind:state={settings.robot_ollama_library} />
			</label>
			<label class="flex items-center justify-between gap-3 text-sm">
				<span>{$i18n.t('Also look at trending audio and embeddings models')}</span>
				<Switch bind:state={settings.robot_trending_audio_embeddings} />
			</label>
		</section>

		<div
			class="sticky bottom-0 flex justify-end bg-gradient-to-t from-white dark:from-gray-950 py-3"
		>
			<button
				type="button"
				class="rounded-xl bg-black px-5 py-2 text-sm font-medium text-white dark:bg-white dark:text-black"
				disabled={busy !== ''}
				on:click={save}
				>{#if busy === 'settings'}<Spinner className="size-4 inline" />{/if}
				{$i18n.t('Save settings')}</button
			>
		</div>
	</div>
{/if}
