/**
 * Phase 3 Chunk 3.A — `themes` table + seed the fallback theme row.
 *
 * The application always has a theme to render through. A theme is a
 * folder under `themes/{slug}/` plus this row telling `ThemeService`
 * which slug is currently active. One row per theme; exactly one row
 * has `is_active = 1` at any time.
 *
 * `bx-blogger-fallback` is pre-seeded here and marked `is_system = 1`
 * so later admin UIs (Phase 4) can refuse to delete it. It's the
 * last-resort theme that renders vanilla Bootstrap via CDN whenever
 * the configured active theme can't be resolved from disk.
 *
 * `manifest_json` mirrors `theme.json` on disk so the admin can show
 * a theme's metadata (name, options, supports[]) without re-reading
 * the file every request. Cached on install; re-read on reinstall.
 */
component {

    function up( schema, qb ) {
        schema.create( "themes", function( table ) {
            table.bigIncrements( "id" );
            table.string( "slug", 120 ).unique();
            table.string( "name", 200 );
            table.string( "version", 60 );
            table.string( "author", 200 ).nullable();
            table.text( "description" ).nullable();
            table.text( "manifest_json" ).nullable();
            // MySQL has no native BOOLEAN — qb emits TINYINT(1).
            table.tinyInteger( "is_active" ).unsigned().default( 0 );
            table.tinyInteger( "is_system" ).unsigned().default( 0 );
            // Filesystem path relative to the app root (e.g. "themes/bx-blogger-fallback").
            // Stored rather than inferred so the resolver can point at an
            // operator-placed theme outside the conventional folder.
            table.string( "directory", 255 );
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
            table.index( "is_active" );
            table.index( "is_system" );
        } );

        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        qb.newQuery().from( "themes" ).insert( {
            "slug"          : "bx-blogger-fallback",
            "name"          : "bx-Blogger Fallback",
            "version"       : "1.0.0",
            "author"        : "bx-Blogger Team",
            "description"   : "Vanilla Bootstrap 5 fallback. Always installed; cannot be uninstalled. Activates automatically when the configured active theme can't be resolved.",
            "manifest_json" : "",
            "is_active"     : 1,
            "is_system"     : 1,
            "directory"     : "themes/bx-blogger-fallback",
            "created_at"    : now,
            "updated_at"    : now
        } );
    }

    function down( schema, qb ) {
        schema.drop( "themes" );
    }

}
