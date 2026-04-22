/**
 * Phase 4 Chunk 4.B — seed `bx-blogger-magazine`.
 *
 * Installs the row for the second example theme. `is_active` stays 0
 * — the default theme keeps the active slot until an admin activates
 * magazine from the themes.manager wire. Mirrors the seed pattern
 * used for `bx-blogger-default` in Chunk 3.C so the themes table
 * stays consistent across fresh installs.
 *
 * Idempotent: if the row already exists (e.g. the admin already ran
 * "Scan folder"), we leave it alone so local-only metadata tweaks
 * stick.
 */
component {

    function up( schema, qb ) {
        var existing = qb.newQuery().from( "themes" ).where( "slug", "bx-blogger-magazine" ).first();
        if ( !isNull( existing ) && !( isStruct( existing ) && structIsEmpty( existing ) ) ) return;

        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        qb.newQuery().from( "themes" ).insert( {
            "slug"          : "bx-blogger-magazine",
            "name"          : "bx-Blogger Magazine",
            "version"       : "1.0.0",
            "author"        : "bx-Blogger Team",
            "description"   : "Second example theme — warmer palette, serif headings, hero-card home layout. Proves the theme seam next to bx-blogger-default.",
            "manifest_json" : "",
            "is_active"     : 0,
            "is_system"     : 1,
            "directory"     : "themes/bx-blogger-magazine",
            "created_at"    : now,
            "updated_at"    : now
        } );
    }

    function down( schema, qb ) {
        // Don't wipe the row if it's currently active — an admin may
        // have switched to magazine since install. A down() is already
        // a destructive operation; refuse rather than silently switching
        // them back to default.
        var row = qb.newQuery().from( "themes" ).where( "slug", "bx-blogger-magazine" ).first();
        if ( isNull( row ) || ( isStruct( row ) && structIsEmpty( row ) ) ) return;
        if ( row.is_active ) {
            throw(
                type    = "bxBlogger.ThemeActive",
                message = "Refusing to remove bx-blogger-magazine — it's currently active. Switch to another theme first."
            );
        }
        qb.newQuery().from( "themes" ).where( "slug", "bx-blogger-magazine" ).delete();
    }

}
