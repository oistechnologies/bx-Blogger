import { defineConfig } from 'vite';
import { fileURLToPath, URL } from 'node:url';
import { readdirSync } from 'node:fs';
import { resolve } from 'node:path';

/**
 * bx-Blogger theme asset pipeline.
 *
 * Discovers app/themes/<slug>/src/ and emits compiled JS + SCSS to
 * public/themes/<slug>/assets/. Runs during the Dockerfile asset-builder
 * stage (node:lts-alpine) via `npm run build`.
 *
 * Phase 0 ships with no themes. The wrapper script resources/node/build-themes.sh
 * detects an empty app/themes/ and exits 0 without invoking Vite, so the Docker
 * build succeeds. Phase 3 adds bx-blogger-fallback and bx-blogger-default under
 * app/themes/ and Vite picks them up automatically from that point.
 *
 * Convention — theme source layout:
 *   app/themes/<slug>/src/
 *     main.js          -> public/themes/<slug>/assets/main.js
 *     theme.scss       -> public/themes/<slug>/assets/theme.css
 *     admin.js         -> public/themes/<slug>/assets/admin.js
 */
function discoverThemeEntries() {
  const themesDir = fileURLToPath(new URL('./app/themes', import.meta.url));
  const entries = {};

  let themes = [];
  try {
    themes = readdirSync(themesDir, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => d.name);
  } catch {
    return entries;
  }

  for (const theme of themes) {
    const srcDir = resolve(themesDir, theme, 'src');
    try {
      for (const file of readdirSync(srcDir)) {
        if (!/\.(js|scss|css)$/.test(file)) continue;
        const name = file.replace(/\.(js|scss|css)$/, '');
        entries[`${theme}__${name}`] = resolve(srcDir, file);
      }
    } catch {
      /* theme has no src/ — skip */
    }
  }

  return entries;
}

export default defineConfig({
  build: {
    outDir: fileURLToPath(new URL('./public/themes', import.meta.url)),
    emptyOutDir: false,
    rollupOptions: {
      input: discoverThemeEntries(),
      output: {
        entryFileNames: (chunk) => {
          const [theme, name] = chunk.name.split('__');
          return `${theme}/assets/${name}.js`;
        },
        chunkFileNames: 'shared/[name]-[hash].js',
        assetFileNames: (asset) => {
          const match = (asset.name || '').match(/^([^.]+)__(.+)$/);
          if (!match) return 'shared/[name][extname]';
          const [, theme, name] = match;
          return `${theme}/assets/${name}[extname]`;
        },
      },
    },
  },
});
