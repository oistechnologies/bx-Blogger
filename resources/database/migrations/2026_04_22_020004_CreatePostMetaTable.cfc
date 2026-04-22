/**
 * Phase 2 — `post_meta` table (B1).
 *
 * Extensible key/value attached to a post. Lets third-party modules (and
 * our own Phase 2+ code) stash data against a post without ever running
 * a schema migration. `value_type` hints at deserialization; `meta_value`
 * is LONGTEXT so both short strings and serialized JSON blobs fit.
 *
 * Unique (post_id, meta_key) — one row per key per post. If a caller
 * needs to store multiple values per key, they serialize an array into
 * a single row (value_type='json') rather than duplicating rows.
 */
component {

    function up( schema, qb ) {
        schema.create( "post_meta", function( table ) {
            table.bigIncrements( "id" );
            table.unsignedBigInteger( "post_id" );
            table.string( "meta_key", 120 );
            table.longText( "meta_value" ).nullable();
            table.string( "value_type", 10 ).default( "string" );   // string|int|bool|json|text
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "post_id" ).references( "id" ).onTable( "posts" ).onDelete( "CASCADE" );
            table.index( [ "post_id", "meta_key" ] );
            table.index( "meta_key" );
            table.unique( [ "post_id", "meta_key" ], "uq_post_meta" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "post_meta" );
    }

}
