/**
 * bx-Blogger — bx-blogger-magazine theme entry (Chunk 4.B).
 *
 * Vite build entry. Imports the SCSS (materialised as a sibling
 * `theme.css` by Vite) and hooks up the dark-mode toggle in the
 * header — same contract the default theme uses, so a theme switch
 * doesn't flash or double-toggle.
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
    const sun  = "☀";
    const moon = "☾";
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
