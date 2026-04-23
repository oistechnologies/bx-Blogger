/**
 * Phase 7.G — `broken_links` table (B22).
 *
 * 404 tracker. BrokenLinkInterceptor / Blog.renderNotFound /
 * Page.renderNotFound UPSERT a row per hit path: first hit
 * inserts, subsequent hits increment `hits` and bump
 * `last_seen_at`. The admin "404 Report" view sorts by hits to
 * surface the legacy URLs worth promoting to a `redirects` row —
 * a one-click "Add Redirect" button writes to `redirects` and
 * back-fills `created_redirect_id` + `resolved_at` so the entry
 * drops off the unresolved list.
 *
 * `path` is UNIQUE — per-path atomic UPSERT. A path matches the
 * normalized form stored in the `redirects` table (leading slash,
 * no trailing slash, no query string) so admin resolution
 * lookups join cleanly.
 *
 * `referer` is optional — captured from the `Referer` header
 * when present; nullable so 404s from direct typing or address-
 * bar nav still record. Length matches `redirects.from_path` /
 * `to_path` at 500 chars.
 *
 * FK on `created_redirect_id` → redirects.id with SET NULL so
 * the broken-link history survives a redirects-row delete.
 */
component {

    function up( schema, qb ) {
        schema.create( "broken_links", function( table ) {
            table.bigIncrements( "id" );
            table.string( "path",    500 );
            table.string( "referer", 500 ).nullable();
            table.unsignedBigInteger( "hits" ).default( 1 );
            table.timestamp( "first_seen_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "last_seen_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "resolved_at" ).nullable();
            table.unsignedBigInteger( "created_redirect_id" ).nullable();

            table.foreignKey( "created_redirect_id" )
                 .references( "id" )
                 .onTable( "redirects" )
                 .onDelete( "SET NULL" );

            table.unique( "path",          "uq_broken_links_path"        );
            table.index( "resolved_at",    "idx_broken_links_resolved"   );
            table.index( "last_seen_at",   "idx_broken_links_last_seen"  );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "broken_links" );
    }

}
