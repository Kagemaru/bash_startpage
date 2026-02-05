<script>
  import { stringify } from 'smol-toml';

  let sites = [
    { name: 'Google', url: 'https://google.com', shortcuts: ['g'], tags: ['search'] },
    { name: 'GitHub', url: 'https://github.com', shortcuts: ['gh'], tags: ['dev', 'work'] },
    { name: 'Svelte', url: 'https://svelte.dev', shortcuts: ['sv'], tags: ['dev'] }
  ];

  let query = '';
  let showHelp = false;
  let history = [];
  let historyIndex = -1;
  let currentTheme = 'mocha';
  let selectedIndex = 0;

  const availableCommands = ['add', 'del', 'tag', 'theme', 'export', 'save', 'help', 'clear history'];
  const themeOptions = ['mocha', 'tokyo', 'matrix', 'light'];

  const getFavicon = (url) => `https://www.google.com/s2/favicons?domain=${url}&sz=32`;

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

  function downloadTOML() {
    const tomlString = stringify({ sites });
    const blob = new Blob([tomlString], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = 'sites.toml'; a.click();
    URL.revokeObjectURL(url);
  }

  function handleKeydown(event) {
    if (suggestions.length > 0) {
      if (event.key === 'ArrowUp') {
        event.preventDefault();
        selectedIndex = (selectedIndex - 1 + suggestions.length) % suggestions.length;
        return;
      }
      if (event.key === 'ArrowDown') {
        event.preventDefault();
        selectedIndex = (selectedIndex + 1) % suggestions.length;
        return;
      }
    }

    if (event.key === 'Tab' && suggestions.length > 0) {
      event.preventDefault();
      const parts = query.split(' ');
      if (parts.length === 1) query = ':' + suggestions[selectedIndex] + ' ';
      else query = parts[0] + ' ' + suggestions[selectedIndex];
      return;
    }

    if (suggestions.length === 0 && (event.key === 'ArrowUp' || event.key === 'ArrowDown')) {
      event.preventDefault();
      if (event.key === 'ArrowUp' && historyIndex < history.length - 1) historyIndex++;
      else if (event.key === 'ArrowDown' && historyIndex > -1) historyIndex--;
      query = historyIndex === -1 ? '' : history[history.length - 1 - historyIndex];
      return;
    }

    if (event.key === 'Enter') {
      const trimmed = query.trim();
      if (!trimmed) return;
      if (history[history.length - 1] !== trimmed) history = [...history, trimmed];
      historyIndex = -1;

      if (trimmed.startsWith(':')) {
        const parts = trimmed.substring(1).split(' ');
        const cmd = parts[0].toLowerCase();
        if (cmd === 'help' || cmd === '?') { showHelp = !showHelp; query = ''; return; }
        showHelp = false;
        if (cmd === 'export' || cmd === 'save') { downloadTOML(); query = ''; return; }
        if (cmd === 'theme' && themeOptions.includes(parts[1])) { currentTheme = parts[1]; query = ''; return; }
        if (cmd === 'add' && parts.length >= 3) {
          sites = [...sites, { name: parts[1], url: parts[2].startsWith('http') ? parts[2] : `https://${parts[2]}`, shortcuts: parts[3] ? [parts[3]] : [], tags: [] }];
          query = ''; return;
        }
        if (cmd === 'del' && parts.length >= 2) {
            const id = parts[1].toLowerCase();
            sites = sites.filter(s => s.name.toLowerCase() !== id && !s.shortcuts.includes(id));
            query = ''; return;
        }
        if (cmd === 'tag' && parts.length >= 3) {
            const id = parts[1].toLowerCase();
            const newTag = parts[2].toLowerCase();
            sites = sites.map(s => (s.name.toLowerCase() === id || s.shortcuts.includes(id)) ? { ...s, tags: Array.from(new Set([...s.tags, newTag])) } : s);
            query = ''; return;
        }
        query = ''; return;
      }

      if (trimmed.startsWith('!')) {
        const key = trimmed.substring(1).toLowerCase();
        const site = sites.find(s => s.shortcuts.includes(key));
        if (site) { window.open(site.url, '_blank'); query = ''; }
      } else if (filteredSites.length > 0) {
        window.open(filteredSites[0].url, '_blank');
        query = '';
      }
    }
  }
</script>

<main class="theme-{currentTheme}">
  <div class="terminal glass">
    <div class="header">
        <div class="comment"># Svelte Launcher v4.2</div>
        <div class="comment"># Enhanced Legibility | {currentTheme} theme</div>
    </div>

    <div class="output-area">
      {#if showHelp}
        <div class="help-section">
          <div class="help-title">VIM-STYLE COMMANDS</div>
          {#each availableCommands as cmd}
            <div class="help-row"><span class="cmd">:{cmd}</span></div>
          {/each}
        </div>
      {:else}
        {#each filteredSites as site}
          <div class="row-container">
            <a href={site.url} target="_blank" rel="noreferrer" class="row">
              <div class="shortcut-group">
                {#each site.shortcuts as sc}<span class="shortcut">!{sc}</span>{/each}
              </div>
              <img src={getFavicon(site.url)} alt="" class="favicon" />
              <span class="name">{site.name}</span>
              <div class="tag-group">
                {#each site.tags as t}<span class="tag">#{t}</span>{/each}
              </div>
              <span class="url">{site.url}</span>
            </a>
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
      <div class="input-line">
        <span class="prompt">❯</span>
        <div class="input-wrapper">
          <input bind:value={query} on:keydown={handleKeydown} placeholder="Type :help or search..." autofocus spellcheck="false" />
        </div>
      </div>
    </div>
  </div>
</main>

<style>
  /* --- THEME DEFINITIONS WITH HIGHER CONTRAST --- */
  .theme-mocha {
    --bg-img: linear-gradient(135deg, #1e1e2e 0%, #11111b 100%);
    --term-rgb: 24, 24, 37;
    --text: #ffffff; /* Brightened for glass */
    --primary: #cba6f7; --secondary: #94e2d5; --accent: #f38ba8; --input-bg: rgba(49, 50, 68, 0.9); 
    --dim: #bac2de; /* Much lighter than previous for visibility */
    --glow: rgba(203, 166, 247, 0.2);
  }
  .theme-tokyo {
    --bg-img: linear-gradient(135deg, #1a1b26 0%, #16161e 100%);
    --term-rgb: 22, 22, 30;
    --text: #ffffff; --primary: #bb9af7; --secondary: #73daca; --accent: #f7768e; --input-bg: rgba(36, 40, 59, 0.9); 
    --dim: #a9b1d6; --glow: rgba(187, 154, 247, 0.2);
  }
  .theme-matrix {
    --bg-img: #000;
    --term-rgb: 5, 5, 5;
    --text: #00ff41; --primary: #00ff41; --secondary: #00ff41; --accent: #fff; --input-bg: rgba(0, 0, 0, 0.9); 
    --dim: #008f11; --glow: rgba(0, 255, 65, 0.2);
  }
  .theme-light {
    --bg-img: linear-gradient(135deg, #eff1f5 0%, #dce0e8 100%);
    --term-rgb: 230, 233, 239;
    --text: #4c4f69; --primary: #7287fd; --secondary: #179287; --accent: #d20f39; --input-bg: rgba(255, 255, 255, 0.8); 
    --dim: #6c6f85; --glow: transparent;
  }

  :global(body) { 
    background: var(--bg-img); color: var(--text); font-family: 'Fira Code', monospace;
    margin: 0; padding: 0; display: flex; align-items: center; justify-content: center; min-height: 100vh;
  }

  /* Glassmorphism Refined for Contrast */
  .glass {
    background: rgba(var(--term-rgb), 0.85) !important; /* Slightly more opaque */
    backdrop-filter: blur(16px) saturate(180%);
    -webkit-backdrop-filter: blur(16px) saturate(180%);
  }

  .terminal { 
    width: 650px; 
    max-height: 80vh; 
    padding: 1.5rem; border-radius: 16px; 
    border: 1px solid rgba(255, 255, 255, 0.2); 
    box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.8);
    display: flex; flex-direction: column;
  }
  
  .header { margin-bottom: 1rem; border-bottom: 1px solid var(--dim); padding-bottom: 0.5rem; }
  .comment { color: var(--dim); font-size: 0.85rem; font-style: italic; font-weight: 500; }

  .output-area { flex-grow: 1; overflow-y: auto; margin-bottom: 1rem; }
  
  .row-container:hover { background: var(--input-bg); border-radius: 8px; }
  .row { display: flex; gap: 0.8rem; padding: 0.6rem; text-decoration: none; align-items: center; color: inherit; }
  
  .name { 
    color: var(--secondary); 
    font-weight: 700; /* Bolder text */
    text-shadow: 0 0 10px var(--glow);
    flex-shrink: 0; width: 120px; 
  }

  .url { 
    color: var(--dim); 
    font-size: 0.75rem; 
    font-weight: 500;
    flex-grow: 1; text-align: right; 
    overflow: hidden; text-overflow: ellipsis; white-space: nowrap; 
  }

  .input-container-wrapper { position: relative; }
  .input-line { 
    display: flex; align-items: center; gap: 0.75rem; 
    background: var(--input-bg); padding: 0.8rem 1rem; 
    border-radius: 10px; border: 1px solid rgba(255,255,255,0.1); 
  }
  
  input { 
    background: transparent; border: none; color: var(--text); 
    font-family: inherit; font-size: 1rem; font-weight: 600; /* Bolder input */
    outline: none; width: 100%; 
  }

  .autocomplete-popup {
    position: absolute; bottom: 120%; left: 0; width: 220px;
    border: 1px solid var(--primary); border-radius: 10px;
    box-shadow: 0 10px 30px rgba(0,0,0,0.4); z-index: 100;
  }
  .suggestion-item { padding: 10px 14px; font-size: 0.85rem; font-weight: 600; border-bottom: 1px solid var(--dim); }
  .suggestion-item.selected { background: var(--primary); color: #1e1e2e; }

  .prompt { color: var(--accent); font-weight: 800; }
  .shortcut { 
    color: var(--primary); 
    font-weight: 800; 
    font-size: 0.8rem; 
    min-width: 45px;
    text-shadow: 0 0 8px var(--glow);
  }

  .tag { 
    color: var(--accent); 
    font-size: 0.7rem; 
    font-weight: 700;
    border: 1px solid var(--accent); 
    padding: 2px 6px; border-radius: 5px; 
    background: rgba(var(--term-rgb), 0.5); 
  }

  .favicon { width: 18px; height: 18px; border-radius: 4px; filter: saturate(1.2); }
  .cmd { color: var(--primary); font-weight: 800; }
</style>
