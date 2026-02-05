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
  let currentTheme = 'tokyo';
  
  // Selection index for the popup
  let selectedIndex = 0;

  const availableCommands = ['add', 'del', 'tag', 'theme', 'export', 'save', 'help', 'clear history'];
  const themeOptions = ['tokyo', 'matrix', 'light'];

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
      if (parts.length === 1) {
        suggestions = availableCommands.filter(c => c.startsWith(parts[0]));
      } else if (parts[0] === 'theme' && parts.length === 2) {
        suggestions = themeOptions.filter(t => t.startsWith(parts[1]));
      } else {
        suggestions = [];
      }
    } else {
      suggestions = [];
    }
    // Reset selection when suggestions change
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
    // Navigate Popup with Arrow keys if it's open
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
      if (parts.length === 1) {
        query = ':' + suggestions[selectedIndex] + ' ';
      } else {
        query = parts[0] + ' ' + suggestions[selectedIndex];
      }
      return;
    }

    // Standard History (only if popup is closed)
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
        if (cmd === 'theme' && themeOptions.includes(parts[1])) {
          currentTheme = parts[1]; query = ''; return;
        }
        if (trimmed === ':clear history') { history = []; query = ''; return; }
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
  <div class="terminal">
    <div class="header">
      <div class="comment"># Svelte Launcher v3.2</div>
      <div class="comment"># Firefox Compatibility Fix | ↑/↓ to Select Popup</div>
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

    <div class="input-line">
      {#if suggestions.length > 0}
        <div class="autocomplete-popup">
          {#each suggestions as sug, i}
            <div class="suggestion-item" class:selected={i === selectedIndex}>
              {sug}
            </div>
          {/each}
        </div>
      {/if}

      <span class="prompt">❯</span>
      <div class="input-wrapper">
        <input 
          bind:value={query} 
          on:keydown={handleKeydown} 
          placeholder="Search or :command..." 
          autofocus 
          spellcheck="false" 
        />
      </div>
    </div>
  </div>
</main>

<style>
  /* Tokyo Night, Matrix, and Light variables */
  .theme-tokyo { --bg: #1a1b26; --term: #16161e; --text: #a9b1d6; --primary: #bb9af7; --secondary: #73daca; --accent: #f7768e; --input-bg: #24283b; --dim: #414868; }
  .theme-matrix { --bg: #000000; --term: #050505; --text: #00ff41; --primary: #008f11; --secondary: #00ff41; --accent: #ffffff; --input-bg: #0d0d0d; --dim: #003b00; }
  .theme-light { --bg: #f0f0f0; --term: #ffffff; --text: #333333; --primary: #005fcc; --secondary: #2e7d32; --accent: #d32f2f; --input-bg: #e0e0e0; --dim: #999999; }

  :global(body) { 
    background-color: var(--bg); 
    color: var(--text); 
    font-family: 'Fira Code', monospace; 
    margin: 0; 
    padding: 2rem; 
    display: flex; 
    justify-content: center;
    min-height: 100vh;
  }

  .terminal { 
    width: 100%; 
    max-width: 1100px; 
    background: var(--term); 
    padding: 2rem; 
    border-radius: 8px; 
    border: 1px solid var(--dim); 
    box-shadow: 0 10px 30px rgba(0,0,0,0.5); 
    height: fit-content;
  }
  
  .output-area { min-height: 300px; max-height: 500px; overflow-y: auto; margin-bottom: 1.5rem; }
  .row-container:hover { background: var(--input-bg); border-radius: 4px; }
  .row { display: flex; gap: 1rem; padding: 0.6rem; text-decoration: none; align-items: center; }
  .name { color: var(--secondary); min-width: 140px; font-weight: 600; }
  .url { color: var(--dim); font-size: 0.8rem; flex-grow: 1; text-align: right; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }

  /* FIX FOR FIREFOX: Ensure input-line is relative and allows absolute children to overflow */
  .input-line { 
    display: flex; 
    align-items: center; 
    gap: 0.75rem; 
    background: var(--input-bg); 
    padding: 0.8rem 1.2rem; 
    border-radius: 4px; 
    position: relative; 
    overflow: visible; 
  }

  .input-wrapper { flex-grow: 1; }
  input { background: transparent; border: none; color: var(--text); font-family: inherit; font-size: 1.1rem; outline: none; width: 100%; }

  .autocomplete-popup {
    position: absolute;
    bottom: 110%; /* Lifted slightly more for visibility */
    left: 0;
    width: 220px;
    background: var(--term);
    border: 1px solid var(--primary);
    border-radius: 4px;
    box-shadow: 0 -10px 20px rgba(0,0,0,0.4);
    z-index: 9999;
  }

  .suggestion-item {
    padding: 10px 14px;
    font-size: 0.9rem;
    color: var(--text);
    border-bottom: 1px solid var(--dim);
  }
  .suggestion-item:last-child { border-bottom: none; }
  .suggestion-item.selected { 
    background: var(--primary); 
    color: var(--term); 
    font-weight: bold;
  }

  .prompt { color: var(--accent); font-weight: bold; }
  .shortcut { color: var(--primary); font-weight: bold; font-size: 0.8rem; }
  .tag { color: var(--accent); font-size: 0.75rem; border: 1px solid var(--dim); padding: 1px 6px; border-radius: 4px; }
  .help-section { padding: 1rem; border-left: 2px solid var(--accent); background: var(--bg); }
  .cmd { color: var(--primary); font-weight: bold; }
</style>
