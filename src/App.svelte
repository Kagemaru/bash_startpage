<script>
  import { stringify } from 'smol-toml';
  import { fade } from 'svelte/transition';

  // INITIALIZE FROM BUILD-TIME INJECTION
  const buildData = typeof __BUILD_CONFIG__ !== 'undefined' ? __BUILD_CONFIG__ : { sites: [], settings: {} };

  let sites = buildData.sites || [];
  let currentTheme = buildData.settings?.theme || 'mocha';
  
  // UI STATE
  let query = '';
  let inputRef; // Reference to the input element
  let showHelp = false;
  let showChangelog = false;
  let history = [];
  let historyIndex = -1;
  let selectedIndex = 0;
  let tooltip = { visible: false, text: '', x: 0, y: 0 };

  const availableCommands = ['add', 'del', 'tag', 'theme', 'export', 'help', 'changelog'];
  const themeOptions = ['mocha', 'tokyo', 'matrix', 'light'];

  const changelog = [
    { v: "5.6", f: "Internal link launching (_self) & clickable input field." },
    { v: "5.5", f: "Static Build-Time Injection via Vite; config.toml is master." },
    { v: "4.5", f: "Interactive URL tooltips on hover & mouse tracking." },
    { v: "4.4", f: "Removed URL text for 'Zen' look & refined tag spacing." },
    { v: "4.1", f: "Glassmorphism & floating palette layout." },
    { v: "2.8", f: "Vim-style ':' prefix for system commands." }
  ];

  const getFavicon = (url) => `https://www.google.com/s2/favicons?domain=${url}&sz=32`;

  // Focus helper
  const focusInput = () => inputRef.focus();

  // Filtering Logic
  $: filteredSites = sites.filter(site => {
    const q = query.toLowerCase().trim();
    if (!q || q.startsWith(':')) return true;
    const terms = q.split(/\s+/);
    return terms.every(term => {
      if (term.startsWith('#')) return site.tags.some(t => t.toLowerCase().includes(term.substring(1)));
      if (term.startsWith('!')) return site.shortcuts.some(s => s.toLowerCase().includes(term.substring(1)));
      return site.name.toLowerCase().includes(term) || site.url.toLowerCase().includes(term);
    });
  });

  // Popup Logic
  let suggestions = [];
  $: {
    const q = query.toLowerCase();
    if (q.startsWith(':')) {
      const parts = q.substring(1).split(' ');
      if (parts.length === 1) suggestions = availableCommands.filter(c => c.startsWith(parts[0]));
      else if (parts[0] === 'theme' && parts.length === 2) suggestions = themeOptions.filter(t => t.startsWith(parts[1]));
      else suggestions = [];
    } else suggestions = [];
    selectedIndex = 0;
  }

  function handleKeydown(event) {
    if (suggestions.length > 0) {
      if (event.key === 'ArrowUp') { event.preventDefault(); selectedIndex = (selectedIndex - 1 + suggestions.length) % suggestions.length; return; }
      if (event.key === 'ArrowDown') { event.preventDefault(); selectedIndex = (selectedIndex + 1) % suggestions.length; return; }
    }

    if (event.key === 'Tab' && suggestions.length > 0) {
      event.preventDefault();
      const parts = query.split(' ');
      query = parts.length === 1 ? ':' + suggestions[selectedIndex] + ' ' : parts[0] + ' ' + suggestions[selectedIndex];
      return;
    }

    if (event.key === 'Enter') {
      const trimmed = query.trim();
      if (!trimmed) return;
      if (history[history.length - 1] !== trimmed) history = [...history, trimmed];
      historyIndex = -1;

      if (trimmed.startsWith(':')) {
        const parts = trimmed.substring(1).split(/\s+/);
        const cmd = parts[0].toLowerCase();
        showHelp = false; showChangelog = false;

        if (cmd === 'help') { showHelp = true; query = ''; return; }
        if (cmd === 'changelog') { showChangelog = true; query = ''; return; }
        if (cmd === 'theme' && themeOptions.includes(parts[1])) { currentTheme = parts[1]; query = ''; return; }
        if (cmd === 'export') {
           const config = { settings: { theme: currentTheme }, sites: sites };
           const blob = new Blob([stringify(config)], { type: 'text/plain' });
           const url = URL.createObjectURL(blob);
           const a = document.createElement('a'); a.href = url; a.download = 'config.toml'; a.click();
           query = ''; return;
        }
        
        if (cmd === 'add' && parts.length >= 3) {
          sites = [...sites, { name: parts[1], url: parts[2], shortcuts: parts[3] ? [parts[3]] : [], tags: [] }];
          query = ''; return;
        }
        if (cmd === 'del' && parts.length >= 2) {
          sites = sites.filter(s => s.name.toLowerCase() !== parts[1].toLowerCase() && !s.shortcuts.includes(parts[1].toLowerCase()));
          query = ''; return;
        }
        query = ''; return;
      }

      if (trimmed.startsWith('!')) {
        const key = trimmed.substring(1).toLowerCase();
        const site = sites.find(s => s.shortcuts.includes(key));
        if (site) window.open(site.url, '_self');
        query = ''; return;
      }

      if (filteredSites.length > 0) {
        window.open(filteredSites[0].url, '_self');
        query = '';
      }
    }
  }
</script>

<main class="theme-{currentTheme}">
  {#if tooltip.visible}
    <div class="tooltip glass" transition:fade={{duration: 100}} style="left: {tooltip.x}px; top: {tooltip.y}px;">
      {tooltip.text}
    </div>
  {/if}

  <div class="terminal glass">
    <div class="header">
        <div class="comment"># Static Build v5.6 | Mode: {currentTheme}</div>
    </div>

    <div class="output-area">
      {#if showHelp}
        <div class="special-view">
          <div class="view-title">COMMAND DOCUMENTATION</div>
          <div class="help-row"><span class="cmd">:add</span> <span class="desc">name url key?</span></div>
          <div class="help-row"><span class="cmd">:del</span> <span class="desc">name_or_shortcut</span></div>
          <div class="help-row hint"><span class="desc">Note: UI edits are session-only. Update config.toml for permanent changes.</span></div>
          <div class="help-row"><span class="cmd">:export</span> <span class="desc">Download current config</span></div>
          <div class="help-row"><span class="cmd">:changelog</span> <span class="desc">Full history</span></div>
        </div>
      {:else if showChangelog}
        <div class="special-view">
          <div class="view-title">SYSTEM CHANGELOG</div>
          <div class="changelog-scroll">
            {#each changelog as entry}
              <div class="view-row">
                <span class="version">v{entry.v}</span>
                <span class="feature">{entry.f}</span>
              </div>
            {/each}
          </div>
        </div>
      {:else}
        {#each filteredSites as site}
          <div class="row-container" 
               on:mouseenter={(e) => { tooltip.visible = true; tooltip.text = site.url; tooltip.x = e.clientX; tooltip.y = e.clientY + 20; }} 
               on:mousemove={(e) => { tooltip.x = e.clientX; tooltip.y = e.clientY + 20; }} 
               on:mouseleave={() => tooltip.visible = false}
               on:click={() => window.open(site.url, '_self')}>
            <div class="row">
              <div class="shortcut-group">
                {#each site.shortcuts as sc}<span class="shortcut">!{sc}</span>{/each}
              </div>
              <img src={getFavicon(site.url)} alt="" class="favicon" />
              <span class="name">{site.name}</span>
              <div class="tag-group">
                {#each site.tags as t}<span class="tag">#{t}</span>{/each}
              </div>
            </div>
          </div>
        {/each}
      {/if}
    </div>

    <div class="input-container-wrapper">
      {#if suggestions.length > 0}
        <div class="autocomplete-popup glass">
          {#each suggestions as sug, i}
            <div class="suggestion-item" class:selected={i === selectedIndex}>{sug}</div>
          {/each}
        </div>
      {/if}

      <div class="input-line clickable" on:click={focusInput}>
        <span class="prompt">❯</span>
        <div class="input-wrapper">
          <input 
            bind:this={inputRef}
            bind:value={query} 
            on:keydown={handleKeydown} 
            placeholder="Search or :command..." 
            autofocus 
            spellcheck="false" 
          />
        </div>
      </div>
    </div>
  </div>
</main>

<style>
  /* --- STYLES REMAIN CONSISTENT --- */
  .theme-mocha { --bg-img: linear-gradient(135deg, #1e1e2e 0%, #11111b 100%); --term-rgb: 24, 24, 37; --text: #ffffff; --primary: #cba6f7; --secondary: #94e2d5; --accent: #f38ba8; --input-bg: rgba(49, 50, 68, 0.9); --dim: #bac2de; --glow: rgba(203, 166, 247, 0.2); }
  .theme-tokyo { --bg-img: linear-gradient(135deg, #1a1b26 0%, #16161e 100%); --term-rgb: 22, 22, 30; --text: #ffffff; --primary: #bb9af7; --secondary: #73daca; --accent: #f7768e; --input-bg: rgba(36, 40, 59, 0.9); --dim: #a9b1d6; --glow: rgba(187, 154, 247, 0.2); }
  .theme-matrix { --bg-img: #000; --term-rgb: 5, 5, 5; --text: #00ff41; --primary: #00ff41; --secondary: #00ff41; --accent: #fff; --input-bg: rgba(0, 0, 0, 0.9); --dim: #008f11; --glow: rgba(0, 255, 65, 0.2); }
  .theme-light { --bg-img: linear-gradient(135deg, #eff1f5 0%, #dce0e8 100%); --term-rgb: 230, 233, 239; --text: #4c4f69; --primary: #7287fd; --secondary: #179287; --accent: #d20f39; --input-bg: rgba(255, 255, 255, 0.8); --dim: #6c6f85; --glow: transparent; }

  :global(body) { background: var(--bg-img); color: var(--text); font-family: 'Fira Code', monospace; margin: 0; padding: 0; display: flex; align-items: center; justify-content: center; min-height: 100vh; overflow: hidden; }
  .glass { background: rgba(var(--term-rgb), 0.85) !important; backdrop-filter: blur(16px) saturate(180%); -webkit-backdrop-filter: blur(16px) saturate(180%); }
  .terminal { width: 600px; max-height: 80vh; padding: 1.5rem; border-radius: 16px; border: 1px solid rgba(255, 255, 255, 0.2); box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.8); display: flex; flex-direction: column; }
  .header { margin-bottom: 1rem; border-bottom: 1px solid var(--dim); padding-bottom: 0.5rem; }
  .comment { color: var(--dim); font-size: 0.85rem; font-style: italic; font-weight: 500; }
  .output-area { flex-grow: 1; overflow-y: auto; margin-bottom: 1rem; }
  .row-container { transition: background 0.2s; cursor: pointer; }
  .row-container:hover { background: var(--input-bg); border-radius: 8px; }
  .row { display: flex; gap: 1.2rem; padding: 0.7rem; align-items: center; }
  .name { color: var(--secondary); font-weight: 700; text-shadow: 0 0 10px var(--glow); flex-grow: 1; }
  .tag-group { display: flex; gap: 0.6rem; }
  .tag { color: var(--accent); font-size: 0.7rem; font-weight: 700; border: 1px solid var(--accent); padding: 2px 8px; border-radius: 6px; background: rgba(var(--term-rgb), 0.5); }
  .shortcut-group { display: flex; gap: 0.5rem; width: 80px; }
  .shortcut { color: var(--primary); font-weight: 800; font-size: 0.8rem; text-shadow: 0 0 8px var(--glow); }
  .tooltip { position: fixed; pointer-events: none; padding: 6px 12px; border-radius: 8px; font-size: 0.75rem; font-weight: 600; color: var(--text); border: 1px solid rgba(255,255,255,0.2); box-shadow: 0 10px 20px rgba(0,0,0,0.4); z-index: 1000; white-space: nowrap; }

  /* Clickable class for input area */
  .clickable { cursor: text; }
  .input-line { display: flex; align-items: center; gap: 0.75rem; background: var(--input-bg); padding: 0.8rem 1rem; border-radius: 10px; border: 1px solid rgba(255,255,255,0.1); }
  input { background: transparent; border: none; color: var(--text); font-family: inherit; font-size: 1rem; font-weight: 600; outline: none; width: 100%; }

  .autocomplete-popup { position: absolute; bottom: 120%; left: 0; width: 220px; border: 1px solid var(--primary); border-radius: 10px; box-shadow: 0 10px 30px rgba(0,0,0,0.4); z-index: 100; }
  .suggestion-item { padding: 10px 14px; font-size: 0.85rem; font-weight: 600; border-bottom: 1px solid var(--dim); }
  .suggestion-item.selected { background: var(--primary); color: #1e1e2e; }

  .special-view { padding: 0.5rem; }
  .view-title { color: var(--accent); font-weight: 800; margin-bottom: 1rem; font-size: 1.1rem; }
  .view-row { display: flex; margin-bottom: 0.6rem; font-size: 0.9rem; border-bottom: 1px solid rgba(255,255,255,0.05); padding-bottom: 0.4rem; }
  .hint { margin-top: -0.5rem; margin-bottom: 1.5rem; }
  .version { color: var(--primary); font-weight: 800; width: 60px; flex-shrink: 0; }
  .cmd { color: var(--primary); font-weight: 800; width: 100px; }
  .desc { color: var(--dim); font-size: 0.9rem; }
  .favicon { width: 18px; height: 18px; border-radius: 4px; }
</style>
