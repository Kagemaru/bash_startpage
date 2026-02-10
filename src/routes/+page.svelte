<!-- vim: set ts=2 sw=2 et: -->

<script lang="ts">
	import { untrack } from 'svelte';
	import { fade } from 'svelte/transition';
	import SiteRow from '$lib/components/SiteRow.svelte';
	import Clock from '$lib/components/Clock.svelte';
	import Weather from '$lib/components/Weather.svelte';
	import Suggestions from '$lib/components/Suggestions.svelte';
	import Changelog from '$lib/components/Changelog.svelte';
	import CommandInput from '$lib/components/CommandInput.svelte';
	import { processCommand, availableCommands, themeOptions } from '$lib/commands';
	import { stringify } from 'smol-toml';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();
	const buildData = $derived(data.buildData);

	// --- STATE MANAGEMENT ---
	let sites = $state<any[]>([]);
	let currentTheme = $state('mocha');
	let query = $state('');
	let selectedIndex = $state(0);
	let showHelp = $state(false);
	let showChangelog = $state(false);
	let tooltip = $state({ visible: false, text: '', x: 0, y: 0 });

	// Tooltip Helper
	const handleHover = (visible: boolean, text = '', x = 0, y = 0) => {
		tooltip = { visible, text, x, y: y + 20 };
	};

	// Sync config to state using untrack to prevent infinite loops
	$effect(() => {
		if (data.buildData) {
			untrack(() => {
				sites = data.buildData.sites || [];
				currentTheme = data.buildData.settings?.theme || 'mocha';
			});
		}
	});

	// --- RESTORED FULL PROJECT HISTORY ---
	const changelogData = [
		{ v: '6.4', f: 'Manual UTC Offset via config.toml (Fixed persistent 1h offset).' },
		{ v: '6.3', f: 'Manual Timezone override via [settings] config key.' },
		{ v: '6.2', f: 'Attempted OS TimeZone resolution fix for clock offset.' },
		{ v: '6.1', f: 'Hard-sync clock to system local time via locale array.' },
		{ v: '6.0', f: 'Switched to 24h dashboard clock for technical look.' },
		{ v: '5.9', f: 'Weather caching (15m) for zero-latency dashboard load.' },
		{ v: '5.8', f: "Fixed :add/:del logic & expanded input field to 100% width." },
		{ v: '5.7', f: 'Dashboard: Added real-time clock & IP-based weather fetch.' },
		{ v: '5.6', f: "UX: Internal link launching (_self) & focused clickable input." },
		{ v: '5.5', f: 'Arch: Static Build-Time Injection master config system.' },
		{ v: '5.0', f: 'IO: Switched to config.toml with settings/sites headers.' },
		{ v: '4.5', f: "UI: Interactive URL tooltips on hover & mouse tracking." },
		{ v: '4.4', f: "Style: Removed URL text for 'Zen' look & refined tag spacing." },
		{ v: '4.2', f: 'A11y: Contrast & legibility overhaul for Glassmorphism.' },
		{ v: '4.1', f: 'Visuals: Glassmorphism (Blur) & centered palette layout.' },
		{ v: '4.0', f: 'Theme: Catppuccin Mocha theme & palette-aware variables.' },
		{ v: '3.3', f: 'Compat: Firefox stacking context & popup rendering fixes.' },
		{ v: '3.1', f: 'CLI: Contextual command popups & Tab-to-complete logic.' },
		{ v: '2.8', f: "Logic: Vim-style ':' prefix for administrative actions." },
		{ v: '2.6', f: 'Search: Strict hierarchy (#tags, !keys, name/url).' },
		{ v: '2.2', f: 'Assets: Favicon auto-fetching & multiple alias support.' },
		{ v: '1.0', f: 'Init: Svelte TOML Launcher core release.' }
	];

	// --- DERIVED LOGIC ---
	let filteredSites = $derived(
		sites.filter((site) => {
			const q = query.toLowerCase().trim();
			if (!q || q.startsWith(':')) return true;
			const terms = q.split(/\s+/);
			return terms.every((term) => {
				if (term.startsWith('#'))
					return site.tags.some((t: string) => t.toLowerCase().includes(term.substring(1)));
				if (term.startsWith('!'))
					return site.shortcuts.some((s: string) => s.toLowerCase().includes(term.substring(1)));
				return site.name.toLowerCase().includes(term) || site.url.toLowerCase().includes(term);
			});
		})
	);

	let suggestions = $derived.by(() => {
		const q = query.toLowerCase();
		if (!q.startsWith(':')) return [];
		const parts = q.substring(1).split(' ');
		if (parts.length === 1) return availableCommands.filter((c) => c.startsWith(parts[0]));
		if (parts[0] === 'theme' && parts.length === 2)
			return themeOptions.filter((t) => t.startsWith(parts[1]));
		return [];
	});

	// --- COMMAND HANDLER ---
	function handleCommand(input: string) {
		const result = processCommand(input, sites, currentTheme);
		
		sites = result.updatedSites;
		currentTheme = result.updatedTheme;
		showHelp = result.view.help;
		showChangelog = result.view.changelog;

		if (input.startsWith(':export')) {
			const config = {
				settings: { theme: currentTheme, offset: buildData.settings?.offset || 0 },
				sites: $state.snapshot(sites)
			};
			const blob = new Blob([stringify(config)], { type: 'text/plain' });
			const url = URL.createObjectURL(blob);
			const a = document.createElement('a');
			a.href = url;
			a.download = 'config.toml';
			a.click();
		}
		query = '';
	}

	function onKeyDown(e: KeyboardEvent) {
		if (suggestions.length > 0) {
			if (e.key === 'ArrowUp') {
				e.preventDefault();
				selectedIndex = (selectedIndex - 1 + suggestions.length) % suggestions.length;
				return;
			}
			if (e.key === 'ArrowDown') {
				e.preventDefault();
				selectedIndex = (selectedIndex + 1) % suggestions.length;
				return;
			}
			if (e.key === 'Tab') {
				e.preventDefault();
				const parts = query.split(' ');
				query = parts.length === 1
						? `:${suggestions[selectedIndex]} `
						: `${parts[0]} ${suggestions[selectedIndex]}`;
				return;
			}
		}

		if (e.key === 'Enter') {
			if (query.startsWith(':')) {
				handleCommand(query);
			} else if (query.startsWith('!')) {
				const key = query.substring(1).toLowerCase();
				const site = sites.find((s) => s.shortcuts.includes(key));
				if (site) window.open(site.url, '_self');
				query = '';
			} else if (filteredSites.length > 0) {
				window.open(filteredSites[0].url, '_self');
				query = '';
			}
		}
	}

	const themeClasses = $derived(
		{
			mocha: 'bg-[#1e1e2e] text-white',
			tokyo: 'bg-[#1a1b26] text-white',
			matrix: 'bg-black text-[#00ff41] font-mono',
			light: 'bg-slate-100 text-slate-900'
		}[currentTheme] || 'bg-[#1e1e2e] text-white'
	);
</script>

<main class="flex min-h-screen items-center justify-center transition-colors duration-500 {themeClasses}">
	<div class="relative w-full max-w-2xl px-4">
		<Suggestions list={suggestions} {selectedIndex} />

		<div class="terminal rounded-2xl border border-white/10 bg-black/40 p-6 shadow-2xl backdrop-blur-xl">
			<div class="mb-6 flex items-center justify-between border-b border-white/10 pb-4">
				<div class="text-[10px] tracking-widest uppercase opacity-50">
					# Dashboard | {currentTheme}
				</div>
				<div class="flex gap-4 text-xs font-bold text-cyan-400">
					<Weather />
					<Clock offset={buildData.settings?.offset} />
				</div>
			</div>

			<div class="custom-scrollbar mb-6 max-h-[50vh] space-y-1 overflow-y-auto pr-2">
				{#if showHelp}
					<div class="space-y-3 p-2" transition:fade>
						<div class="border-b border-emerald-400/20 pb-1 text-xs font-bold text-emerald-400">
							HELP
						</div>
						<div class="grid grid-cols-[80px_1fr] gap-y-2 text-[11px]">
							<span class="font-bold text-purple-400">:add</span>
							<span class="text-gray-400">name url key?</span>
							<span class="text-purple-400">:del</span>
							<span class="text-gray-400">name_or_shortcut</span>
							<span class="text-purple-400">:theme</span>
							<span class="text-gray-400">mocha/tokyo/matrix/light</span>
						</div>
					</div>
				{:else if showChangelog}
					<Changelog changelog={changelogData} />
				{:else}
					{#each filteredSites as site}
						<SiteRow {site} onHover={handleHover} />
					{/each}
				{/if}
			</div>

			<CommandInput bind:query {onKeyDown} />
		</div>
	</div>

	{#if tooltip.visible}
		<div
			class="pointer-events-none fixed z-[100] rounded border border-white/20 bg-black/90 px-3 py-1 text-[10px] text-white shadow-xl backdrop-blur-sm"
			style="left: {tooltip.x}px; top: {tooltip.y}px;"
			transition:fade={{ duration: 100 }}
		>
			{tooltip.text}
		</div>
	{/if}
</main>

<style>
	.custom-scrollbar::-webkit-scrollbar {
		width: 4px;
	}
	.custom-scrollbar::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.1);
		border-radius: 10px;
	}
</style>
