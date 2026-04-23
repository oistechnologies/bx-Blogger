/**
 * Phase 7.C — `redirects` table.
 *
 * 301/302 redirects for renamed slugs (and later, admin-promoted
 * entries from the B22 broken-links report). A single `from_path →
 * to_path` mapping with a hit counter so an admin can see which
 * legacy URLs crawlers and humans still hit.
 *
 * `from_path` is UNIQUE — one authoritative redirect per legacy URL.
 * When a slug changes twice (old1 → old2 → new), PostService's hook
 * collapses the chain by rewriting any existing row pointing *to*
 * old2 so it points to `new`, then inserting `old2 → new`. No
 * transitive lookup at serve time; the interceptor does a single
 * indexed SELECT per incoming path.
 *
 * `status_code` defaults to 301 (permanent) — the right signal for
 * slug-rename redirects since search engines should forget the old
 * URL. Admin UI in Phase 8 will let an operator pick 302 for
 * intentionally-temporary redirects.
 *
 * `created_by` → users.id is nullable: slug-change auto-redirects
 * have no specific user when written from a job/scheduled context,
 * and admin-created entries carry the editor's id for the audit
 * trail the Phase-8 Redirects Manager shows.
 */
component {

    function up( schema, qb ) {
        schema.create( "redirects", function( table ) {
            table.bigIncrements( "id" );
            table.string( "from_path", 500 );
            table.string( "to_path",   500 );
            table.unsignedSmallInteger( "status_code" ).default( 301 );
            table.unsignedBigInteger( "hits" ).default( 0 );
            table.timestamp( "last_hit_at" ).nullable();
            // users.id is `int unsigned` — match exactly.
            table.unsignedInteger( "created_by" ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "created_by" )
                 .references( "id" )
                 .onTable( "users" )
                 .onDelete( "SET NULL" );

            // Single authoritative source per legacy URL.
            table.unique( "from_path", "uq_redirects_from_path" );
            // Sort admin list by most-recently-hit.
            table.index( "last_hit_at", "idx_redirects_last_hit_at" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "redirects" );
    }

}
