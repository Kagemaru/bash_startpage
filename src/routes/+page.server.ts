import { readFileSync } from 'fs';
import { parse } from 'smol-toml';
import path from 'path';
import type { PageServerLoad } from './$types';

export interface Site {
  name: string;
  url: string;
  shortcuts: string[];
  tags: string[];
}

export interface Config {
  settings: {
    theme?: string;
    offset?: number;
    timezone?: string;
  };
  sites: Site[];
}

export const load: PageServerLoad = () => {
  const configPath = path.resolve('config.toml');
  const configSource = readFileSync(configPath, 'utf-8');
  const config = parse(configSource) as unknown as Config;

  return {
    buildData: config
  };
};
