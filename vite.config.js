/**
 * bx-Blogger — Vite config (Chunks 3.C + 5.C)
 *
 * Shipped as a reference for theme authors. The actual theme build
 * runs through `build-themes.mjs` (one Vite invocation per discovered
 * theme folder so each theme's assets land under its own output
 * directory — a single multi-entry Vite run forces chunk-name
 * gymnastics to split outputs per theme, and the cost is a clearer
 * custom driver).
 *
 * 5.C — asset fingerprinting.
 *   - Output files carry a content hash in their filename:
 *       js/theme-a3f91b.js, css/theme-d82c14.css
 *     A new build with changed bytes produces a new filename; the old
 *     filename remains cacheable forever. NGINX in prod stamps
 *     Cache-Control: public, max-age=31536000, immutable on any
 *     hashed asset under /themes/{slug}/assets/ (Phase 10 B14).
 *   - build.manifest writes a manifest.json alongside the build
 *     output mapping logical names (theme.js / theme.css) to their
 *     hashed counterparts. Theme.asset() reads it at render time;
 *     when the manifest is missing (freshly-cloned tree, fallback
 *     theme, prod image not yet built) the helper falls back to
 *     the unhashed path plus a version-query string.
 */
import { defineConfig } from "vite";

export default defineConfig({
    css: {
        preprocessorOptions: {
            scss: {
                // Bootstrap lives under node_modules/bootstrap/scss — the
                // loadPath makes `@use "bootstrap/scss/bootstrap"` resolve
                // without a relative path prefix.
                loadPaths: [ "node_modules" ]
            }
        }
    },
    build: {
        sourcemap: false,
        manifest: true,   // writes `{outDir}/.vite/manifest.json`
        rollupOptions: {
            output: {
                entryFileNames: "js/theme-[hash].js",
                chunkFileNames: "js/[name]-[hash].js",
                assetFileNames: ( asset ) => {
                    if ( asset.name && asset.name.endsWith( ".css" ) ) return "css/theme-[hash][extname]";
                    return "[name]-[hash][extname]";
                }
            }
        }
    }
});
