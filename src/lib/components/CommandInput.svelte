<script lang="ts">
	let { query = $bindable(), onKeyDown } = $props();
	let inputRef: HTMLInputElement;

	function focusInput() {
		inputRef.focus();
	}
</script>

<div 
	class="flex items-center gap-3 rounded-xl border border-white/10 bg-white/5 p-4 focus-within:border-purple-500/50 cursor-text"
	onclick={focusInput}
	onkeydown={(e) => e.key === 'Enter' && focusInput()}
	role="button"
	tabindex="0"
>
	<span class="font-bold text-purple-500">❯</span>
	<input
		bind:this={inputRef}
		bind:value={query}
		onkeydown={onKeyDown}
		placeholder="Search or :command..."
		class="w-full border-none bg-transparent text-sm outline-none placeholder:text-gray-600"
		spellcheck="false"
		autofocus
	/>
</div>
