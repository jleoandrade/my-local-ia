<script lang="ts">
	import { getContext } from 'svelte';

	import type { Level } from '$lib/apis/my-local-ia';
	import { LEVEL_STYLE, levelLabel } from './labels';

	const i18n = getContext('i18n');

	export let level: Level;
	export let className = 'text-xs px-2 py-0.5';
</script>

<span class="shrink-0 whitespace-nowrap rounded-full font-medium {LEVEL_STYLE[level]} {className}"
	>{levelLabel((key) => $i18n.t(key), level)}</span
>
