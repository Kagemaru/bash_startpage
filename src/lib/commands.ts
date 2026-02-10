import { stringify } from 'smol-toml';

export const availableCommands = ['add', 'del', 'theme', 'export', 'help', 'changelog'];
export const themeOptions = ['mocha', 'tokyo', 'matrix', 'light'];

export function processCommand(input: string, currentSites: any[], currentTheme: string) {
    const parts = input.trim().substring(1).split(/\s+/);
    const cmd = parts[0].toLowerCase();
    let updatedSites = [...currentSites];
    let updatedTheme = currentTheme;
    let view = { help: false, changelog: false };

    if (cmd === 'help') view.help = true;
    if (cmd === 'changelog') view.changelog = true;

    if (cmd === 'theme' && themeOptions.includes(parts[1])) {
        updatedTheme = parts[1];
    } else if (cmd === 'add' && parts.length >= 3) {
        const url = parts[2].startsWith('http') ? parts[2] : `https://${parts[2]}`;
        updatedSites.push({ name: parts[1], url, shortcuts: parts[3] ? [parts[3]] : [], tags: [] });
    } else if (cmd === 'del' && parts.length >= 2) {
        const id = parts[1].toLowerCase();
        updatedSites = updatedSites.filter(s => s.name.toLowerCase() !== id && !s.shortcuts.includes(id));
    }

    return { updatedSites, updatedTheme, view };
}
