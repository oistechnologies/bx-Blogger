/**
 * Phase 6 Chunk 6.H — `page_views` table.
 *
 * One row per public post view. Populated async via
 * RecordPostViewJob — the interceptor that fires on the render
 * path dispatches the job with a small payload and returns; the
 * worker writes the row, so the request isn't blocked by an
 * extra INSERT.
 *
 * `ip_hash` + `ua_hash` store salted SHA-256 hashes of the
 * visitor IP + user agent — enough to deduplicate views from the
 * same visitor within a short window without persisting PII.
 * The salt rotates daily (derived from a server secret + the
 * current date), so the same visitor on different days produces
 * different hashes, naturally anonymizing the data over time.
 *
 * Retention: Phase 6 scheduler prunes rows older than 90 days
 * (PLAN daily-03:00 task). Index on (post_id, viewed_at) covers
 * the "top posts over the last N days" analytics query the
 * future admin dashboard will want.
 */
component {

    function up( schema, qb ) {
        schema.create( "page_views", function( table ) {
            table.bigIncrements( "id" );
            table.unsignedBigInteger( "post_id" );
            table.timestamp( "viewed_at" ).default( "CURRENT_TIMESTAMP" );
            table.string( "ip_hash", 64 ).nullable();
            table.string( "ua_hash", 64 ).nullable();

            table.foreignKey( "post_id" )
                 .references( "id" )
                 .onTable( "posts" )
                 .onDelete( "CASCADE" );
            table.index( [ "post_id", "viewed_at" ] );
            table.index( "viewed_at" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "page_views" );
    }

}
