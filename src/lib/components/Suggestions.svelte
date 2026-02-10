<script lang="ts">
	let { list = [], selectedIndex = 0 } = $props();
</script>

{#if list.length > 0}
	<div class="absolute bottom-full left-4 z-50 mb-2 w-48 overflow-hidden rounded-lg border border-purple-500/50 bg-black/80 backdrop-blur-md">
		{#each list as sug, i}
			<div class="px-4 py-2 text-xs {i === selectedIndex ? 'bg-purple-600 text-white' : 'text-gray-400'}">
				{sug}
			</div>
		{/each}
	</div>
{/if}
