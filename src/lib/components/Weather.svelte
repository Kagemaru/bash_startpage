<script lang="ts">
	import { onMount } from 'svelte';
	import { fetchWeather } from '$lib/weather';

	let weather = $state({ temp: '--', desc: 'Loading...' });

	onMount(async () => {
		weather = await fetchWeather();
	});
</script>

<span>{weather.temp}</span>
