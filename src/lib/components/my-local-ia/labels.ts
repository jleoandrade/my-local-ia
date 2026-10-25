// Shared labels of my-local-ia. Every text goes through t() with a literal key,
// so `npm run i18n:parse` finds it and the locale files carry its translation.
import type { Category, Level, Localized, Placement } from '$lib/apis/my-local-ia';

type T = (key: string, options?: Record<string, unknown>) => string;

export const LEVEL_STYLE: Record<Level, string> = {
	smooth: 'bg-emerald-500/15 text-emerald-700 dark:text-emerald-300',
	usable: 'bg-amber-500/15 text-amber-700 dark:text-amber-300',
	heavy: 'bg-red-500/15 text-red-700 dark:text-red-300',
	wont_run: 'bg-gray-500/15 text-gray-600 dark:text-gray-400'
};

export const LEVEL_BAR: Record<Level, string> = {
	smooth: 'bg-emerald-500',
	usable: 'bg-amber-500',
	heavy: 'bg-red-500',
	wont_run: 'bg-gray-400'
};

export const levelLabel = (t: T, level: Level) => {
	switch (level) {
		case 'smooth':
			return t('Runs smoothly');
		case 'usable':
			return t('Usable');
		case 'heavy':
			return t('Heavy');
		default:
			return t("Won't run");
	}
};

export const categoryLabel = (t: T, category: Category) => {
	switch (category) {
		case 'chat':
			return t('Chat');
		case 'vis':
			return t('Vision');
		case 'code':
			return t('Code');
		case 'img':
			return t('Image');
		case 'vid':
			return t('Video');
		case 'stt':
			return t('Speech to text');
		case 'tts':
			return t('Text to speech');
		default:
			return t('Embeddings');
	}
};

export const placementLabel = (t: T, placement: Placement) => {
	switch (placement) {
		case 'vram':
			return t('fits in the GPU memory');
		case 'vram+ram':
			return t('uses system RAM too');
		case 'ram':
			return t('runs in system RAM');
		default:
			return t('does not load');
	}
};

/** What a model that does not write text does, shown instead of tokens per second. */
export const noSpeedLabel = (t: T, category: Category) => {
	switch (category) {
		case 'img':
			return t('generates images');
		case 'vid':
			return t('generates video');
		case 'stt':
			return t('transcribes audio');
		case 'tts':
			return t('generates voice');
		default:
			return t('indexes texts');
	}
};

export const taskLabel = (t: T, task: string) => {
	switch (task) {
		case 'assistant':
			return t('Everyday assistant');
		case 'writing':
			return t('Writing');
		case 'coding':
			return t('Programming');
		case 'reasoning':
			return t('Reasoning and math');
		case 'vision':
			return t('Reading images and documents');
		case 'transcription':
			return t('Transcribing audio');
		default:
			return t('Searching your documents');
	}
};

export const taskWhy = (t: T, task: string) => {
	switch (task) {
		case 'assistant':
			return t('The strongest general model that still answers fast on this server.');
		case 'writing':
			return t('Natural text in Portuguese, Spanish and other languages.');
		case 'coding':
			return t('Writes and explains code quickly on this server.');
		case 'reasoning':
			return t('Thinks before answering and keeps a good speed here.');
		case 'vision':
			return t('Reads screenshots, scanned PDFs and charts.');
		case 'transcription':
			return t('Transcribes meetings and videos with very good accuracy.');
		default:
			return t('Multilingual embeddings: the base for chatting with your files.');
	}
};

export const sourceLabel = (t: T, source: string | undefined) => {
	switch (source) {
		case 'detected':
			return t('Detected');
		case 'table':
			return t('From the GPU table');
		case 'measured':
			return t('Measured');
		case 'manual':
			return t('Set by the admin');
		default:
			return t('Default value');
	}
};

/** Catalog texts come in en, pt-BR and es. */
export const localized = (text: Localized | null | undefined, language: string) => {
	if (!text) return '';
	const lang = language?.toLowerCase() ?? 'en';
	if (lang.startsWith('pt')) return text['pt-BR'] ?? text.en ?? '';
	if (lang.startsWith('es')) return text.es ?? text.en ?? '';
	return text.en ?? '';
};

export const formatGb = (value: number | null | undefined, language: string) =>
	value == null
		? '—'
		: `${value.toLocaleString(language, { maximumFractionDigits: 1, minimumFractionDigits: 1 })} GB`;

export const formatSeconds = (seconds: number, language: string) => {
	if (seconds < 0.1) return `< ${(0.1).toLocaleString(language)} s`;
	if (seconds < 60) return `${seconds.toLocaleString(language, { maximumFractionDigits: 1 })} s`;
	const minutes = Math.floor(seconds / 60);
	return `${minutes} min ${Math.round(seconds % 60)} s`;
};
