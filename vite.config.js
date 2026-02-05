import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import { readFileSync } from 'fs';
import { parse } from 'smol-toml';

// Read and parse your local config at build time
const configSource = readFileSync('./config.toml', 'utf-8');
const config = parse(configSource);

export default defineConfig({
  plugins: [svelte()],
  define: {
    // This injects the TOML data into your Svelte code
    __BUILD_CONFIG__: JSON.stringify(config)
  }
});
