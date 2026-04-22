/**
 * Phase 2 — `tags` table.
 *
 * Flat list (no hierarchy). Global slug/name uniqueness — merging two
 * tags is a separate admin action that moves pivot rows from one tag id
 * to another and deletes the source (tags.manager wire ships Chunk 2.E).
 */
component {

    function up( schema, qb ) {
        schema.create( "tags", function( table ) {
            table.bigIncrements( "id" );
            table.string( "name", 120 ).unique();
            table.string( "slug", 140 ).unique();
            table.string( "description", 500 ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "tags" );
    }

}
