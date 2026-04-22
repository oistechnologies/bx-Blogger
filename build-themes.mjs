/**
 * bx-Blogger — theme build driver (Chunk 3.C)
 *
 * Discovers every `themes/{slug}/src/theme.js` entry, runs one Vite
 * build per theme, and writes the output into
 * `public/themes/{slug}/assets/`. Runs inside the `node` docker-compose
 * service so every contributor builds against the same Node runtime.
 *
 * Usage (from the host):
 *   docker compose run --rm node npm run build
 *   docker compose run --rm node npm run watch:themes
 *
 * Options (CLI flags):
 *   --watch    Keep the process running and rebuild on file change
 *   --theme X  Build only the matching theme slug
 */
import { build }       from "vite";
import { globSync }    from "glob";
import viteBaseConfig  from "./vite.config.js";
import path            from "node:path";
import { pathToFileURL } from "node:url";

const projectRoot = process.cwd();
const argv        = process.argv.slice( 2 );
const watchMode   = argv.includes( "--watch" );
const themeFilter = ( () => {
    const i = argv.indexOf( "--theme" );
    return i >= 0 ? argv[ i + 1 ] : null;
} )();

const entries = globSync( "themes/*/src/theme.js", { cwd: projectRoot } )
    .map( relPath => {
        const slug = path.basename( path.dirname( path.dirname( relPath ) ) );
        return { slug, entry: relPath };
    } )
    .filter( e => !themeFilter || e.slug === themeFilter );

if ( !entries.length ) {
    console.error( themeFilter
        ? `[build-themes] no theme matched --theme=${ themeFilter }`
        : "[build-themes] no themes found at themes/*/src/theme.js"
    );
    process.exit( 1 );
}

for ( const { slug, entry } of entries ) {
    // Emit directly into the theme's own folder — the flat ColdBox
    // layout uses the project root as the web root, so
    // `/themes/{slug}/assets/...` URLs resolve to `themes/{slug}/assets/...`
    // on disk. A separate `public/` staging directory would need
    // server-side rewrites that the CommandBox MiniServer doesn't
    // currently have.
    const outDir = `themes/${ slug }/assets`;
    console.log( `[build-themes] ${ watchMode ? "watching" : "building" } ${ slug } -> ${ outDir }` );

    await build( {
        ...viteBaseConfig,
        configFile: false,
        root:       projectRoot,
        logLevel:   "warn",
        build: {
            ...( viteBaseConfig.build ?? {} ),
            outDir:      path.resolve( projectRoot, outDir ),
            emptyOutDir: true,
            watch:       watchMode ? {} : null,
            // `assetsDir: ""` keeps Rollup from prepending `assets/` to
            // every emitted filename. Combined with `entryFileNames` +
            // `assetFileNames` in vite.config.js that pin the names to
            // `js/theme.js` and `css/theme.css`, the output layout is:
            //   themes/{slug}/assets/js/theme.js
            //   themes/{slug}/assets/css/theme.css
            assetsDir: "",
            rollupOptions: {
                ...( viteBaseConfig.build?.rollupOptions ?? {} ),
                input: { theme: path.resolve( projectRoot, entry ) }
            }
        }
    } );
}

if ( !watchMode ) {
    console.log( `[build-themes] built ${ entries.length } theme${ entries.length === 1 ? "" : "s" }.` );
}
