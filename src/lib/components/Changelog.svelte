<script lang="ts">
	import { fade } from 'svelte/transition';

	let { changelog = [] } = $props();
</script>

<div class="space-y-2 p-2" transition:fade>
	<div class="border-b border-emerald-400/20 pb-1 text-xs font-bold text-emerald-400">
		SYSTEM CHANGELOG
	</div>
	<div class="custom-scrollbar max-h-[40vh] space-y-2 overflow-y-auto pr-2">
		{#each changelog as entry}
			<div class="flex gap-4 border-b border-white/5 pb-1 text-[11px]">
				<span class="w-10 font-bold text-purple-400">v{entry.v}</span>
				<span class="text-gray-400">{entry.f}</span>
			</div>
		{/each}
	</div>
</div>

<style>
	.custom-scrollbar::-webkit-scrollbar {
		width: 4px;
	}
	.custom-scrollbar::-webkit-scrollbar-thumb {
		background: rgba(255, 255, 255, 0.1);
		border-radius: 10px;
	}
</style>
