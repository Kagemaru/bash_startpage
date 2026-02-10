export async function fetchWeather() {
    const CACHE_KEY = 'svelte_launcher_weather';
    const cached = localStorage.getItem(CACHE_KEY);
    if (cached) {
        const { data, timestamp } = JSON.parse(cached);
        if (Date.now() - timestamp < 900000) return data;
    }
    try {
        const res = await fetch('https://wttr.in/?format=j1');
        const data = await res.json();
        const current = data.current_condition[0];
        const newWeather = { temp: current.temp_C + '°C', desc: current.weatherDesc[0].value };
        localStorage.setItem(CACHE_KEY, JSON.stringify({ data: newWeather, timestamp: Date.now() }));
        return newWeather;
    } catch (e) {
        return { temp: '!!', desc: 'Weather Error' };
    }
}
