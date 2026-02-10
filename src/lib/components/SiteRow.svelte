<script lang="ts">
    let { site, onHover } = $props();
    const getFavicon = (url: string) => `https://www.google.com/s2/favicons?domain=${url}&sz=32`;
</script>

<button
    onclick={() => window.open(site.url, '_self')}
    onmouseenter={(e) => onHover(true, site.url, e.clientX, e.clientY)}
    onmousemove={(e) => onHover(true, site.url, e.clientX, e.clientY)}
    onmouseleave={() => onHover(false)}
    class="group flex w-full items-center gap-4 rounded border border-transparent p-2 transition-all hover:border-white/10 hover:bg-white/5"
>
    <span class="w-16 text-left text-xs font-bold text-purple-400">
        {site.shortcuts[0] ? `!${site.shortcuts[0]}` : ''}
    </span>
    <img src={getFavicon(site.url)} alt="" class="w-4 h-4 rounded-sm opacity-80" />
    <span class="flex-grow text-left text-sm font-semibold text-emerald-400">{site.name}</span>
    <div class="flex gap-2 text-right">
        {#each site.tags as tag}
            <span class="rounded border border-pink-500/20 px-2 py-0.5 text-[9px] font-bold text-pink-500/80">#{tag}</span>
        {/each}
    </div>
</button>
