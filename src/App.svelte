<script>
  import { stringify } from 'smol-toml';

  let sites = [
    { name: 'Google', url: 'https://google.com', shortcuts: ['g'], tags: ['search'] },
    { name: 'GitHub', url: 'https://github.com', shortcuts: ['gh'], tags: ['dev', 'work'] },
    { name: 'GitLab', url: 'https://gitlab.com', shortcuts: ['gl'], tags: ['dev', 'private'] },
    { name: 'Wikipedia', url: 'https://wikipedia.org', shortcuts: ['w'], tags: ['wiki'] },
    { name: 'Svelte', url: 'https://svelte.dev', shortcuts: ['sv'], tags: ['dev'] }
  ];

  let query = '';
  let showHelp = false;
  let history = [];
  let historyIndex = -1;
  let currentTheme = 'tokyo';

  const getFavicon = (url) => `https://www.google.com/s2/favicons?domain=${url}&sz=32`;

  // UPDATED: Strict segmentation of search domains
  $: filteredSites = sites.filter(site => {
    const q = query.toLowerCase().trim();
    if (!q) return true;
    
    const terms = q.split(/\s+/);
    
    return terms.every(term => {
      // 1. STRICT TAG SEARCH
      if (term.startsWith('#')) {
        const tagQuery = term.substring(1);
        return site.tags.some(t => t.toLowerCase().includes(tagQuery));
      }
      
      // 2. STRICT SHORTCUT SEARCH
      if (term.startsWith('!')) {
        const sq = term.substring(1);
        return site.shortcuts.some(s => s.toLowerCase().includes(sq));
      }
      
      // 3. NAME & URL SEARCH (No Shortcuts, No Tags)
      return (
        site.name.toLowerCase().includes(term) || 
        site.url.toLowerCase().includes(term)
      );
    });
  });

  function downloadTOML() {
    const tomlString = stringify({ sites });
    const blob = new Blob([tomlString], { type: 'text/plain' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url; a.download = 'sites.toml'; a.click();
    URL.revokeObjectURL(url);
  }

  function handleKeydown(event) {
    if (event.key === 'Tab') {
      event.preventDefault();
      if (filteredSites.length > 0 && query.length > 0) {
        const words = query.split(/\s+/);
        const lastWord = words[words.length - 1];
        
        if (lastWord.startsWith('#') && filteredSites[0].tags.length > 0) {
            words[words.length - 1] = '#' + filteredSites[0].tags[0];
        } else if (lastWord.startsWith('!') && filteredSites[0].shortcuts.length > 0) {
            words[words.length - 1] = '!' + filteredSites[0].shortcuts[0];
        } else {
            words[words.length - 1] = filteredSites[0].name;
        }
        query = words.join(' ');
      }
      return;
    }

    if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
      event.preventDefault();
      if (event.key === 'ArrowUp' && historyIndex < history.length - 1) historyIndex++;
      else if (event.key === 'ArrowDown' && historyIndex > -1) historyIndex--;
      query = historyIndex === -1 ? '' : history[history.length - 1 - historyIndex];
      return;
    }

    if (event.key === 'Enter') {
      const trimmedQuery = query.trim();
      if (!trimmedQuery) return;

      if (!trimmedQuery.startsWith('!') && history[history.length - 1] !== trimmedQuery) {
        history = [...history, trimmedQuery];
      }
      historyIndex = -1;

      if (trimmedQuery === 'help' || trimmedQuery === '?') { showHelp = !showHelp; query = ''; return; }
      showHelp = false;

      const commandParts = trimmedQuery.split(' ');
      const cmd = commandParts[0].toLowerCase();

      if (cmd === 'tag' && commandParts.length >= 3) {
        const target = commandParts[1].toLowerCase();
        const newTag = commandParts[2].toLowerCase();
        sites = sites.map(s => (s.name.toLowerCase() === target || s.shortcuts.includes(target)) 
          ? { ...s, tags: Array.from(new Set([...s.tags, newTag])) } : s);
        query = ''; return;
      }

      if (cmd === 'theme' && ['tokyo', 'matrix', 'light'].includes(commandParts[1])) {
        currentTheme = commandParts[1];
        query = ''; return;
      }

      if (trimmedQuery.startsWith('!')) {
        const targetKey = trimmedQuery.substring(1).toLowerCase();
        const site = sites.find(s => s.shortcuts.map(sk => sk.toLowerCase()).includes(targetKey));
        if (site) { window.open(site.url, '_blank'); query = ''; }
        return;
      }

      if (cmd === 'add' && commandParts.length >= 3) {
        sites = [...sites, { 
          name: commandParts[1], 
          url: commandParts[2].startsWith('http') ? commandParts[2] : `https://${commandParts[2]}`, 
          shortcuts: commandParts[3] ? [commandParts[3]] : [], 
          tags: [] 
        }];
        query = ''; return;
      }

      if (cmd === 'del') {
        const id = trimmedQuery.substring(4).trim().toLowerCase();
        sites = sites.filter(s => s.shortcuts.includes(id) || s.name.toLowerCase() === id);
        query = ''; return;
      }

      if (trimmedQuery === 'export' || trimmedQuery === 'save') { downloadTOML(); query = ''; return; }

      if (filteredSites.length > 0 && !trimmedQuery.includes('add') && !trimmedQuery.includes('tag')) {
        window.open(filteredSites[0].url, '_blank');
        query = '';
      }
    }
  }
</script>

<main class="theme-{currentTheme}">
  <div class="terminal">
    <div class="header">
      <div class="comment"># Svelte Launcher v2.6</div>
      <div class="comment"># Hierarchy: #tags | !shortcuts | name/url</div>
    </div>

    <div class="output-area">
      {#if showHelp}
        <div class="help-section">
          <div class="help-title">CLI USER GUIDE</div>
          <div class="help-row"><span class="cmd">#tag</span> <span class="desc">Filter tags exclusively</span></div>
          <div class="help-row"><span class="cmd">![key]</span> <span class="desc">Launch shortcut exclusively</span></div>
          <div class="help-row"><span class="cmd">[text]</span> <span class="desc">Search name or URL only</span></div>
          <div class="help-row"><span class="cmd">tag [id] [t]</span> <span class="desc">Categorize site</span></div>
          <div class="help-row"><span class="cmd">export</span> <span class="desc">Save config</span></div>
        </div>
      {:else}
        {#each filteredSites as site}
          <div class="row-container">
            <a href={site.url} target="_blank" rel="noreferrer" class="row">
              <div class="shortcut-group">
                {#each site.shortcuts as sc}
                  <span class="shortcut">!{sc}</span>
                {/each}
              </div>
              <img src={getFavicon(site.url)} alt="" class="favicon" />
              <span class="name">{site.name}</span>
              <div class="tag-group">
                {#each site.tags as tag}
                  <span class="tag">#{tag}</span>
                {/each}
              </div>
              <span class="url">{site.url}</span>
            </a>
          </div>
        {:else}
          <div class="error">!! No match for: {query} !!</div>
        {/each}
      {/if}
    </div>

    <div class="input-line">
      <span class="prompt">❯</span>
      <input bind:value={query} on:keydown={handleKeydown} placeholder="Search (#tag, !shortcut, name/url)..." autofocus spellcheck="false" />
    </div>
  </div>
</main>

<style>
  /* All styles remain identical to previous version to maintain look & feel */
  .theme-tokyo { --bg: #1a1b26; --term: #16161e; --text: #a9b1d6; --primary: #bb9af7; --secondary: #73daca; --accent: #f7768e; --input-bg: #24283b; --dim: #414868; }
  .theme-matrix { --bg: #000000; --term: #050505; --text: #00ff41; --primary: #008f11; --secondary: #00ff41; --accent: #ffffff; --input-bg: #0d0d0d; --dim: #003b00; }
  .theme-light { --bg: #f0f0f0; --term: #ffffff; --text: #333333; --primary: #005fcc; --secondary: #2e7d32; --accent: #d32f2f; --input-bg: #e0e0e0; --dim: #999999; }

  :global(body) { background-color: var(--bg); color: var(--text); font-family: 'Fira Code', monospace; margin: 0; padding: 2rem; display: flex; justify-content: center; }
  .terminal { width: 100%; max-width: 1100px; background: var(--term); padding: 2rem; border-radius: 8px; border: 1px solid var(--dim); box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
  .header { margin-bottom: 1.5rem; border-bottom: 1px dashed var(--dim); padding-bottom: 1rem; }
  .comment { color: var(--dim); font-style: italic; font-size: 0.85rem; }
  .output-area { min-height: 300px; max-height: 500px; overflow-y: auto; margin-bottom: 1.5rem; }
  .favicon { width: 16px; height: 16px; border-radius: 2px; flex-shrink: 0; }
  .shortcut-group { display: flex; gap: 0.5rem; min-width: 100px; flex-wrap: wrap; }
  .shortcut { color: var(--primary); font-weight: bold; font-size: 0.8rem; }
  .tag-group { display: flex; gap: 0.4rem; }
  .tag { color: var(--accent); font-size: 0.75rem; border: 1px solid var(--dim); padding: 1px 6px; border-radius: 4px; }
  .row-container { display: flex; align-items: center; border-radius: 4px; margin-bottom: 2px; }
  .row-container:hover { background: var(--input-bg); }
  .row { display: flex; gap: 1rem; padding: 0.6rem; text-decoration: none; flex-grow: 1; align-items: center; min-width: 0; }
  .name { color: var(--secondary); min-width: 140px; font-weight: 600; }
  .url { color: var(--dim); font-size: 0.8rem; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; flex-grow: 1; text-align: right; }
  .input-line { display: flex; align-items: center; gap: 0.75rem; background: var(--input-bg); padding: 0.8rem 1.2rem; border-radius: 4px; }
  .prompt { color: var(--accent); font-weight: bold; }
  input { background: transparent; border: none; color: var(--text); font-family: inherit; font-size: 1.1rem; outline: none; width: 100%; }
  .error { color: var(--accent); padding: 1rem; font-style: italic; }
  .help-section { padding: 1rem; border-left: 2px solid var(--accent); background: var(--bg); }
  .help-title { color: var(--accent); font-weight: bold; margin-bottom: 1rem; }
  .help-row { display: flex; margin-bottom: 0.6rem; font-size: 0.9rem; }
  .cmd { color: var(--primary); min-width: 180px; font-weight: bold; }
</style>
