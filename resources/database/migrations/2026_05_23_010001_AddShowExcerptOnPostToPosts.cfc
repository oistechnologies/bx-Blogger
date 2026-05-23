/**
 * Per-post toggle for "show the excerpt above the body on the single
 * post page". Default OFF — excerpts now appear only in listings/cards
 * by default. The author can opt back in per post via the editor.
 *
 * Backfill: existing posts that already have a non-empty excerpt flip
 * to ON so live content doesn't visibly change at deploy time.
 */
component {

    function up( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.addColumn( table.boolean( "show_excerpt_on_post" ).default( 0 ) );
        } );

        // Preserve current behavior for posts that already have an excerpt.
        // queryExecute is the established pattern for data work inside
        // migrations on this project (see 2026_04_25_010005); the injected
        // `qb` arg from cfmigrations doesn't reliably run UPDATEs here.
        queryExecute(
            "UPDATE posts SET show_excerpt_on_post = 1 WHERE excerpt IS NOT NULL AND excerpt <> ''",
            []
        );
    }

    function down( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.dropColumn( "show_excerpt_on_post" );
        } );
    }

}
