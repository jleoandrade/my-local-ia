import { get, writable } from 'svelte/store';

import { getModels } from '$lib/apis';
import { getDisk, getDownloads, getInstalled } from '$lib/apis/my-local-ia';
import type { DiskStatus, Download, InstalledModel } from '$lib/apis/my-local-ia';
import { config, models, settings } from '$lib/stores';

/** Installed Ollama models by name, with their estimate for this server. */
export const installedModels = writable<Record<string, InstalledModel>>({});
export const diskStatus = writable<DiskStatus | null>(null);

const REFRESH_MS = 60_000;
let installedLoadedAt = 0;
let installedLoading: Promise<void> | null = null;
let diskLoadedAt = 0;

export const loadInstalled = async (force = false) => {
	if (!force && Date.now() - installedLoadedAt < REFRESH_MS) return;
	installedLoading ??= getInstalled(localStorage.token)
		.then((list) => {
			installedModels.set(Object.fromEntries(list.map((m) => [m.name, m])));
			installedLoadedAt = Date.now();
		})
		.catch(() => {})
		.finally(() => {
			installedLoading = null;
		});
	await installedLoading;
};

export const loadDisk = async (force = false) => {
	if (!force && Date.now() - diskLoadedAt < REFRESH_MS) return get(diskStatus);
	try {
		diskStatus.set(await getDisk(localStorage.token));
		diskLoadedAt = Date.now();
	} catch {
		// The disk meter simply stays hidden.
	}
	return get(diskStatus);
};

/** Installed entry for an Open WebUI model id (Ollama names may omit ":latest"). */
export const findInstalled = (models: Record<string, InstalledModel>, id: string | undefined) => {
	if (!id) return undefined;
	return models[id] ?? models[`${id}:latest`] ?? models[id.replace(/:latest$/, '')];
};

/** Picking this model deserves a warning: slow here, may not load, or barely fits the GPU. */
export const shouldWarn = (model: InstalledModel | undefined) =>
	!!model &&
	(model.estimate.level === 'heavy' ||
		model.estimate.level === 'wont_run' ||
		model.estimate.tight_vram);

/** The biggest installed model of the same kind that runs smoothly here. */
export const bestAlternative = (
	models: Record<string, InstalledModel>,
	model: InstalledModel | undefined
) =>
	Object.values(models)
		.filter(
			(m) =>
				model &&
				m.name !== model.name &&
				m.category === model.category &&
				m.estimate.level === 'smooth' &&
				!m.estimate.tight_vram
		)
		.sort((a, b) => b.size_gb - a.size_gb)[0] ?? null;

/** Downloads running on the server (and the ones that just finished), for every user. */
export const downloads = writable<Download[]>([]);

const POLL_ACTIVE_MS = 1_500;
const POLL_IDLE_MS = 30_000;
let pollTimer: ReturnType<typeof setTimeout> | null = null;
let lastStatus: Record<string, Download['status']> = {};
const finishedListeners = new Set<(finished: Download[]) => void>();

/** Called with the downloads that finished since the last check (for toasts). */
export const onDownloadsFinished = (listener: (finished: Download[]) => void) => {
	finishedListeners.add(listener);
	return () => finishedListeners.delete(listener);
};

const refreshModelList = async () => {
	const directConnections = get(config)?.features?.enable_direct_connections
		? (get(settings)?.directConnections ?? null)
		: null;
	models.set(await getModels(localStorage.token, directConnections));
};

/** Reads the downloads now; polls fast while one is running, slowly otherwise. */
export const refreshDownloads = async () => {
	if (pollTimer) clearTimeout(pollTimer);
	let list: Download[] = [];
	try {
		list = await getDownloads(localStorage.token);
	} catch {
		pollTimer = setTimeout(refreshDownloads, POLL_IDLE_MS);
		return;
	}
	const finished = list.filter(
		(d) => d.status !== 'downloading' && lastStatus[d.name] === 'downloading'
	);
	lastStatus = Object.fromEntries(list.map((d) => [d.name, d.status]));
	downloads.set(list);
	if (finished.some((d) => d.status === 'done')) {
		await Promise.all([loadInstalled(true), loadDisk(true), refreshModelList().catch(() => {})]);
	}
	if (finished.length) finishedListeners.forEach((listener) => listener(finished));
	const active = list.some((d) => d.status === 'downloading');
	pollTimer = setTimeout(refreshDownloads, active ? POLL_ACTIVE_MS : POLL_IDLE_MS);
};

/** Starts watching once per page load (the sidebar calls it). */
let watching = false;
export const watchDownloads = () => {
	if (watching) return;
	watching = true;
	refreshDownloads();
};
