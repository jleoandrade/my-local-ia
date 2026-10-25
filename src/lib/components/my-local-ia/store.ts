import { get, writable } from 'svelte/store';

import { getDisk, getInstalled } from '$lib/apis/my-local-ia';
import type { DiskStatus, InstalledModel } from '$lib/apis/my-local-ia';

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
