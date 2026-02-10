<script lang="ts">
	import { onMount, untrack } from 'svelte';
	import { stringify } from 'smol-toml';
	import { fade } from 'svelte/transition';
	import type { PageData } from './$types';

	let { data }: { data: PageData } = $props();

	const buildData = $derived(data.buildData);

	let sites = $state<any[]>([]);
	let currentTheme = $state('mocha');

	$effect(() => {
		if (data.buildData) {
			untrack(() => {
				sites = data.buildData.sites || [];
				currentTheme = data.buildData.settings?.theme || 'mocha';
			});
		}
	});

	// --- REACIVE STATE (Svelte 5 Runes) ---

	let query = $state('');
	let time = $state('');
	let selectedIndex = $state(0);
	let showHelp = $state(false);
	let showChangelog = $state(false);

	const availableCommands = ['add', 'del', 'theme', 'export', 'help', 'changelog'];
	const themeOptions = ['mocha', 'tokyo', 'matrix', 'light'];

	// --- DERIVED STATE ---
	let filteredSites = $derived(
		sites.filter((site) => {
			const q = query.toLowerCase().trim();
			if (!q || q.startsWith(':')) return true;
			const terms = q.split(/\s+/);
			return terms.every((term) => {
				if (term.startsWith('#'))
					return site.tags.some((t) => t.toLowerCase().includes(term.substring(1)));
				if (term.startsWith('!'))
					return site.shortcuts.some((s) => s.toLowerCase().includes(term.substring(1)));
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

	// --- ACTIONS & HANDLERS ---
	function focusOnInit(node: HTMLInputElement) {
		node.focus();
	}

	function handleCommand(input: string) {
		const trimmed = input.trim();
		const parts = trimmed.substring(1).split(/\s+/);
		const cmd = parts[0].toLowerCase();

		showHelp = cmd === 'help';
		showChangelog = cmd === 'changelog';

		if (cmd === 'theme' && themeOptions.includes(parts[1])) {
			currentTheme = parts[1];
		} else if (cmd === 'add' && parts.length >= 3) {
			const url = parts[2].includes('.')
				? parts[2].startsWith('http')
					? parts[2]
					: `https://${parts[2]}`
				: parts[2];
			sites = [...sites, { name: parts[1], url, shortcuts: parts[3] ? [parts[3]] : [], tags: [] }];
		} else if (cmd === 'del' && parts.length >= 2) {
			const id = parts[1].toLowerCase();
			sites = sites.filter((s) => s.name.toLowerCase() !== id && !s.shortcuts.includes(id));
		} else if (cmd === 'export') {
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
				query =
					parts.length === 1
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

	// 1. Weather State
	let weather = $state({ temp: '--', desc: 'Loading...' });
	const CACHE_KEY = 'svelte_launcher_weather';

	// 2. Weather Fetching Logic
	async function fetchWeather() {
		// Check Cache (15m/900000ms)
		const cached = localStorage.getItem(CACHE_KEY);
		if (cached) {
			const { data, timestamp } = JSON.parse(cached);
			if (Date.now() - timestamp < 900000) {
				weather = data;
				return;
			}
		}

		try {
			const res = await fetch('https://wttr.in/?format=j1');
			const data = await res.json();
			const current = data.current_condition[0];

			const newWeather = {
				temp: current.temp_C + '°C',
				desc: current.weatherDesc[0].value
			};

			weather = newWeather;
			// Save to cache
			localStorage.setItem(
				CACHE_KEY,
				JSON.stringify({
					data: newWeather,
					timestamp: Date.now()
				})
			);
		} catch (e) {
			if (weather.temp === '--') {
				weather = { temp: '!!', desc: 'Weather Error' };
			}
		}
	}

	onMount(() => {
		// Clock Logic
		const updateTime = () => {
			const now = new Date();
			// Use the offset from your config
			const offset = buildData.settings?.offset || 0;
			const localDate = new Date(now.getTime() + offset * 3600000);

			time =
				localDate.getUTCHours().toString().padStart(2, '0') +
				':' +
				localDate.getUTCMinutes().toString().padStart(2, '0') +
				':' +
				localDate.getUTCSeconds().toString().padStart(2, '0');
		};

		updateTime();
		fetchWeather(); // Fetch weather on load

		const timer = setInterval(updateTime, 1000);
		return () => clearInterval(timer);
	});
</script>

<main
	class="theme-{currentTheme} flex min-h-screen items-center justify-center font-mono transition-colors duration-500
  {currentTheme === 'matrix' ? 'bg-black text-[#00ff41]' : 'bg-[#1e1e2e] text-white'}"
>
	<div class="relative w-full max-w-2xl px-4">
		{#if suggestions.length > 0}
			<div
				class="absolute bottom-full left-4 z-50 mb-2 w-48 overflow-hidden rounded-lg border border-purple-500/50 bg-black/80 backdrop-blur-md"
			>
				{#each suggestions as sug, i}
					<div
						class="px-4 py-2 text-xs {i === selectedIndex
							? 'bg-purple-600 text-white'
							: 'text-gray-400'}"
					>
						{sug}
					</div>
				{/each}
			</div>
		{/if}

		<div
			class="terminal rounded-2xl border border-white/10 bg-black/40 p-6 shadow-2xl backdrop-blur-xl"
		>
			<div class="mb-6 flex items-center justify-between border-b border-white/10 pb-4">
				<div class="text-[10px] tracking-widest uppercase opacity-50">
					# Dashboard | {currentTheme}
				</div>
				<div class="flex gap-4 text-xs font-bold text-cyan-400">
					<span>{weather.temp}</span>
					<span class="tabular-nums">{time}</span>
				</div>
			</div>

			<div class="custom-scrollbar mb-6 max-h-[50vh] space-y-1 overflow-y-auto pr-2">
				{#each filteredSites as site}
					<button
						onclick={() => window.open(site.url, '_self')}
						class="group flex w-full items-center gap-4 rounded border border-transparent p-2 transition-all hover:border-white/10 hover:bg-white/5"
					>
						<span class="w-16 text-left text-xs font-bold text-purple-400">
							{site.shortcuts[0] ? `!${site.shortcuts[0]}` : ''}
						</span>
						<span class="flex-grow text-left text-sm font-semibold text-emerald-400"
							>{site.name}</span
						>
						<div class="flex gap-2">
							{#each site.tags as tag}
								<span
									class="rounded border border-pink-500/20 px-2 py-0.5 text-[9px] font-bold text-pink-500/80"
									>#{tag}</span
								>
							{/each}
						</div>
					</button>
				{/each}
			</div>

			<div
				class="flex items-center gap-3 rounded-xl border border-white/10 bg-white/5 p-4 focus-within:border-purple-500/50"
			>
				<span class="font-bold text-purple-500">❯</span>
				<input
					use:focusOnInit
					bind:value={query}
					onkeydown={onKeyDown}
					placeholder="Search or :command..."
					class="w-full border-none bg-transparent text-sm outline-none placeholder:text-gray-600"
					spellcheck="false"
				/>
			</div>
		</div>
	</div>
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
