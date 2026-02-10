<script lang="ts">
	import { onMount } from 'svelte';

	let { offset = 0 } = $props();
	let time = $state('');

	onMount(() => {
		const updateTime = () => {
			const now = new Date();
			const localDate = new Date(now.getTime() + offset * 3600000);
			time = localDate.getUTCHours().toString().padStart(2, '0') + ':' +
				   localDate.getUTCMinutes().toString().padStart(2, '0') + ':' +
				   localDate.getUTCSeconds().toString().padStart(2, '0');
		};
		updateTime();
		const timer = setInterval(updateTime, 1000);
		return () => clearInterval(timer);
	});
</script>

<span class="tabular-nums">{time}</span>
