<script lang="ts">
	import { getContext } from 'svelte';
	import { page } from '$app/stores';

	import { WEBUI_NAME, showSidebar, mobile, user } from '$lib/stores';
	import Tooltip from '$lib/components/common/Tooltip.svelte';
	import Sidebar from '$lib/components/icons/Sidebar.svelte';

	const i18n = getContext('i18n');

	$: tabs = [
		{ href: '/my-local-ia', label: $i18n.t('Catalog'), exact: true },
		{ href: '/my-local-ia/simulator', label: $i18n.t('Simulator') },
		{ href: '/my-local-ia/disk', label: $i18n.t('Disk space') },
		...($user?.role === 'admin'
			? [{ href: '/my-local-ia/settings', label: $i18n.t('Settings') }]
			: [])
	];

	const isActive = (tab, pathname: string) =>
		tab.exact
			? pathname === tab.href || pathname === `${tab.href}/`
			: pathname.startsWith(tab.href);
</script>

<svelte:head>
	<!-- LICENSE covers this Open WebUI browser-title identifier.
	Do not alter, remove, obscure, or replace it except as LICENSE permits:
	https://docs.openwebui.com/license. -->
	<title>
		my-local-ia / {$WEBUI_NAME}
	</title>
</svelte:head>

<div
	class="flex flex-col w-full h-screen max-h-[100dvh] transition-width duration-200 ease-in-out {$showSidebar
		? 'md:max-w-[calc(100%-var(--sidebar-width))]'
		: ''} max-w-full"
>
	<nav class="pb-1 px-2.5 pt-2 backdrop-blur-xl drag-region select-none">
		<div class="flex items-center gap-0.5 md:gap-1">
			{#if $mobile}
				<div class="{$showSidebar ? 'md:hidden' : ''} self-center flex flex-none items-center">
					<Tooltip
						content={$showSidebar ? $i18n.t('Close Sidebar') : $i18n.t('Open Sidebar')}
						interactive={true}
					>
						<button
							class=" cursor-pointer flex rounded-lg hover:bg-gray-100 dark:hover:bg-gray-850 transition"
							aria-label={$showSidebar ? $i18n.t('Close Sidebar') : $i18n.t('Open Sidebar')}
							on:click={() => {
								showSidebar.set(!$showSidebar);
							}}
						>
							<div class=" self-center p-1.5">
								<Sidebar className="size-4" />
							</div>
						</button>
					</Tooltip>
				</div>
			{/if}

			<div
				class="flex min-w-0 items-center gap-0.5 md:gap-1 scrollbar-none overflow-x-auto w-fit text-sm py-1"
			>
				{#each tabs as tab}
					<a
						draggable="false"
						class="min-w-fit px-1 text-sm {isActive(tab, $page.url.pathname)
							? ''
							: 'text-gray-300 dark:text-gray-600 hover:text-gray-700 dark:hover:text-white'} transition select-none"
						href={tab.href}>{tab.label}</a
					>
				{/each}
			</div>
		</div>
	</nav>

	<div class="flex-1 max-h-full overflow-y-auto">
		<div class="mx-auto w-full max-w-6xl px-4 pb-10 pt-2 md:px-6">
			<slot />
		</div>
	</div>
</div>
