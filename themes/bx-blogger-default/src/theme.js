/**
 * bx-Blogger — bx-blogger-default theme entry (Chunks 3.C + 3.D)
 *
 * Vite build entry: imports the SCSS (which becomes a sibling
 * `theme.css` asset) and wires up any theme-scoped JavaScript.
 *
 * Currently:
 *   - Dark-mode toggle: swaps `data-bs-theme` on <html> and persists
 *     the choice in localStorage. The initial attribute is set by an
 *     inline no-flash script in partials/head-assets.bxm; this module
 *     only has to own the click handler.
 *
 * Future:
 *   - Prism autoloader tweaks, share-link handlers, etc.
 */
import "./theme.scss";

const STORAGE_KEY = "bx-blogger-theme";

function currentTheme() {
    return document.documentElement.getAttribute( "data-bs-theme" ) || "light";
}

function applyTheme( theme ) {
    document.documentElement.setAttribute( "data-bs-theme", theme );
    updateToggleIcons( theme );
}

function updateToggleIcons( theme ) {
    // Literal unicode characters — avoids HTML-entity shenanigans in
    // a JS file that doesn't run through BoxLang's output filter.
    const sun  = "☀";   // ☀ — shown in dark mode (click to go light)
    const moon = "☾";   // ☾ — shown in light mode (click to go dark)
    document.querySelectorAll( "[data-theme-toggle-icon]" ).forEach( ( el ) => {
        el.textContent = theme === "dark" ? sun : moon;
    } );
    document.querySelectorAll( "[data-theme-toggle]" ).forEach( ( el ) => {
        el.setAttribute( "aria-pressed", theme === "dark" ? "true" : "false" );
    } );
}

function initToggle() {
    const buttons = document.querySelectorAll( "[data-theme-toggle]" );
    if ( !buttons.length ) return;

    updateToggleIcons( currentTheme() );

    buttons.forEach( ( btn ) => {
        btn.addEventListener( "click", () => {
            const next = currentTheme() === "dark" ? "light" : "dark";
            try { localStorage.setItem( STORAGE_KEY, next ); } catch ( e ) { /* private mode */ }
            applyTheme( next );
        } );
    } );
}

if ( document.readyState === "loading" ) {
    document.addEventListener( "DOMContentLoaded", initToggle );
} else {
    initToggle();
}
