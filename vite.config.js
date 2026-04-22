/**
 * bx-Blogger — Vite config (Chunk 3.C)
 *
 * Shipped as a reference for theme authors. The actual theme build runs
 * through `build-themes.mjs` (one Vite invocation per discovered theme
 * folder so each theme's assets land under its own output directory —
 * a single multi-entry Vite run forces chunk-name gymnastics to split
 * outputs per theme, and the cost is a clearer custom driver).
 *
 * If a theme author wants to wire up Vite HMR or extend the config,
 * they can `import baseConfig from "../../vite.config.js"` and extend.
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
        // Keep generated filenames stable so the layout's
        // `prc.theme.asset("css/theme.css")` URL matches what Vite emits.
        rollupOptions: {
            output: {
                entryFileNames: "js/theme.js",
                chunkFileNames: "js/[name]-[hash].js",
                assetFileNames: ( asset ) => {
                    if ( asset.name && asset.name.endsWith( ".css" ) ) return "css/theme[extname]";
                    return "[name][extname]";
                }
            }
        }
    }
});
