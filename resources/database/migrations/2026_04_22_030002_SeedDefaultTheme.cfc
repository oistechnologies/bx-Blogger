/**
 * Phase 3 Chunk 3.C — seed `bx-blogger-default` + activate it.
 *
 * 3.A seeded `bx-blogger-fallback` (always-present, always-available,
 * never rendered in the happy path). 3.C installs the polished default
 * theme on top and flips `is_active` to it. The fallback stays in the
 * themes table but loses its `is_active` flag.
 *
 * The manifest JSON is cached here rather than re-read from disk on
 * every boot. A future admin action (`themes.discover` in Phase 4) can
 * re-parse `theme.json` and rewrite this column if a theme author
 * changes the file.
 *
 * up() uses an INSERT IGNORE pattern (via pre-select) so a re-run after
 * a rollback-then-reapply doesn't duplicate the slug.
 */
component {

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );

        // `manifest_json` is left empty here and lazily populated by
        // ThemeService.buildTheme() which re-reads `theme.json` off disk
        // when the column is blank. Phase 4's `themes.discover` admin
        // action will eventually cache the parsed JSON into this column
        // on install. Avoiding `fileRead()` here keeps the migration
        // runnable from the `cfmigrations` CLI context, where
        // `expandPath()` doesn't point at the ColdBox app root.
        var existing = qb.newQuery().from( "themes" ).where( "slug", "bx-blogger-default" ).first();
        if ( isNull( existing ) || ( isStruct( existing ) && structIsEmpty( existing ) ) ) {
            qb.newQuery().from( "themes" ).insert( {
                "slug"          : "bx-blogger-default",
                "name"          : "bx-Blogger Default",
                "version"       : "1.0.0",
                "author"        : "bx-Blogger Team",
                "description"   : "Clean, responsive default theme. Bootstrap 5 via CDN, custom styles compiled from SCSS via Vite.",
                "manifest_json" : "",
                "is_active"     : 0,   // flipped in the update below
                "is_system"     : 1,
                "directory"     : "themes/bx-blogger-default",
                "created_at"    : now,
                "updated_at"    : now
            } );
        }

        qb.newQuery().from( "themes" ).update( { "is_active" : 0 } );
        qb.newQuery().from( "themes" )
            .where( "slug", "bx-blogger-default" )
            .update( { "is_active" : 1, "updated_at" : now } );
    }

    function down( schema, qb ) {
        // Reverting this migration leaves the site back on the fallback.
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        qb.newQuery().from( "themes" ).where( "slug", "bx-blogger-default" ).delete();
        qb.newQuery().from( "themes" ).update( { "is_active" : 0 } );
        qb.newQuery().from( "themes" )
            .where( "slug", "bx-blogger-fallback" )
            .update( { "is_active" : 1, "updated_at" : now } );
    }

}
