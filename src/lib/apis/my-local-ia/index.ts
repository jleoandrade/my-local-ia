import { WEBUI_API_BASE_URL } from '$lib/constants';

const BASE = `${WEBUI_API_BASE_URL}/my-local-ia`;

export type Level = 'smooth' | 'usable' | 'heavy' | 'wont_run';
export type Placement = 'vram' | 'vram+ram' | 'ram' | 'wont_load';
export type Category = 'chat' | 'vis' | 'code' | 'img' | 'vid' | 'stt' | 'tts' | 'emb';
export type Localized = Record<string, string>; // { en, 'pt-BR', es }

export type Estimate = {
	size_gb: number;
	placement: Placement;
	tps: number | null;
	prefill_tps: number | null;
	score: number;
	level: Level;
	tight_vram: boolean;
};

export type Hardware = {
	gpus: { name: string; vram_gb: number; bandwidth_gbs: number; bandwidth_source: string }[];
	vram_gb: number;
	gpu_bandwidth_gbs: number;
	gpu_efficiency: number;
	ram_total_gb: number;
	ram_for_models_gb: number;
	ram_bandwidth_gbs: number;
	cpu_name: string | null;
	cpu_threads: number | null;
	sources: Record<string, string>;
	detected_at: number | null;
	has_gpu: boolean;
};

export type CatalogModel = {
	id: string;
	name: string;
	category: Category;
	size_gb: number;
	active_ratio: number;
	reasoning: boolean;
	description: Localized | null;
	use_for: Localized | null;
	ollama: string | null;
	whisper: string | null;
	unsure: boolean;
	source: 'curated' | 'auto';
	meta: Record<string, any> | null;
	created_at: number;
	estimate: Estimate;
};

export type InstalledModel = {
	name: string;
	size_gb: number;
	parameter_size: string | null;
	quantization: string | null;
	family: string | null;
	category: Category;
	reasoning: boolean;
	active_ratio: number;
	catalog_id: string | null;
	estimate: Estimate;
	last_used: number | null;
	uses_30d: number;
	downloaded_by: { user_id: string; user_name: string; at: number } | null;
	protected: string | null;
	suggestion: 'unused' | 'rarely_used' | 'heavy' | null;
};

export type Pick = {
	task: string;
	entry: Omit<CatalogModel, 'estimate'>;
	estimate: Estimate;
	installed_as: string | null;
};

export type DiskStatus = {
	path: string;
	models_mounted: boolean;
	total_gb: number;
	used_gb: number;
	free_gb: number;
	used_pct: number;
	level: 'ok' | 'warning' | 'critical' | 'blocked';
	models_gb: number | null;
	app_gb: number;
	other_gb: number;
	warning_pct: number;
	critical_pct: number;
	block_pct: number;
	margin_gb: number;
	growth_gb_per_day: number | null;
	days_to_block: number | null;
};

export type DownloadCheck = {
	fits: boolean;
	needed_gb: number;
	free_gb: number;
	used_pct_now: number;
	used_pct_after: number;
	block_pct: number;
};

export type Alternative = {
	kind: 'smaller' | 'free_space';
	entry: Omit<CatalogModel, 'estimate'> | null;
	estimate: Estimate | null;
	remove: string[];
	frees_gb: number;
	used_pct_after: number;
};

export type PullCheck = { allowed: boolean; check: DownloadCheck; alternatives: Alternative[] };

export type Settings = {
	users_can_download: boolean;
	disk_warning_pct: number;
	disk_critical_pct: number;
	disk_block_pct: number;
	disk_margin_gb: number;
	disk_check_minutes: number;
	unused_days: number;
	alert_banner: boolean;
	alert_webhook_url: string;
	robot_enabled: boolean;
	robot_frequency: 'daily' | 'weekly' | 'manual';
	robot_time: string;
	robot_min_downloads: number;
	robot_max_models: number;
	robot_sources: string[];
	robot_trending_audio_embeddings: boolean;
};

export type RobotStatus = {
	last_run?: number;
	added?: number;
	total?: number;
	error?: string | null;
};

const request = async (
	token: string,
	path: string,
	method = 'GET',
	body: object | undefined = undefined
) => {
	const res = await fetch(`${BASE}${path}`, {
		method,
		headers: {
			Accept: 'application/json',
			'Content-Type': 'application/json',
			authorization: `Bearer ${token}`
		},
		body: body ? JSON.stringify(body) : undefined
	});
	if (!res.ok) {
		const error = await res.json().catch(() => ({ detail: res.statusText }));
		throw error?.detail ?? error;
	}
	return res.json();
};

export const getHardware = (token: string): Promise<Hardware> => request(token, '/hardware');
export const detectHardware = (token: string): Promise<Hardware> =>
	request(token, '/hardware/detect', 'POST');
export const setHardwareOverrides = (
	token: string,
	overrides: Record<string, number | null>
): Promise<Hardware> => request(token, '/hardware/overrides', 'POST', overrides);

export const getCatalog = (token: string): Promise<CatalogModel[]> => request(token, '/models');
export const getPicks = (token: string): Promise<Pick[]> => request(token, '/picks');
export const getInstalled = (token: string): Promise<InstalledModel[]> =>
	request(token, '/installed');
export const removeInstalled = (token: string, name: string) =>
	request(token, `/installed/${encodeURIComponent(name)}`, 'DELETE');

export const getDisk = (token: string): Promise<DiskStatus> => request(token, '/disk');
export const checkDiskNow = (token: string): Promise<DiskStatus> =>
	request(token, '/disk/check', 'POST');

export const checkPull = (token: string, form: { catalog_id?: string; model?: string }) =>
	request(token, '/pull/check', 'POST', form) as Promise<PullCheck>;

/** Starts a download and calls onProgress for every line Ollama sends. Resolves when it ends. */
export const pullModel = async (
	token: string,
	form: { catalog_id?: string; model?: string },
	onProgress: (line: {
		status?: string;
		total?: number;
		completed?: number;
		error?: string;
	}) => void,
	signal?: AbortSignal
) => {
	const res = await fetch(`${BASE}/pull`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json', authorization: `Bearer ${token}` },
		body: JSON.stringify(form),
		signal
	});
	if (!res.ok || !res.body) {
		const error = await res.json().catch(() => ({ detail: res.statusText }));
		throw error?.detail ?? error;
	}
	const reader = res.body.getReader();
	const decoder = new TextDecoder();
	let buffer = '';
	let succeeded = false;
	for (;;) {
		const { value, done } = await reader.read();
		if (done) break;
		buffer += decoder.decode(value, { stream: true });
		const lines = buffer.split('\n');
		buffer = lines.pop() ?? '';
		for (const line of lines) {
			if (!line.trim()) continue;
			try {
				const data = JSON.parse(line);
				if (data.status === 'success') succeeded = true;
				if (data.error) throw data.error;
				onProgress(data);
			} catch (e) {
				if (typeof e === 'string') throw e;
			}
		}
	}
	return succeeded;
};

export const getPublicSettings = (token: string): Promise<{ users_can_download: boolean }> =>
	request(token, '/settings/public');
export const getSettings = (token: string): Promise<Settings> => request(token, '/settings');
export const saveSettings = (token: string, settings: Partial<Settings>): Promise<Settings> =>
	request(token, '/settings', 'POST', settings);

export const getRobotStatus = (token: string): Promise<RobotStatus> => request(token, '/robot');
export const runRobot = (token: string): Promise<RobotStatus> =>
	request(token, '/robot/run', 'POST');
