/**
 * Phase 1 — `permissions` table.
 * Permission slugs follow `entity.action[.scope]` per PLAN §10
 * (e.g., posts.edit.own, users.purge, system.admin).
 */
component {

    function up( schema, qb ) {
        schema.create( "permissions", function( table ) {
            table.increments( "id" );
            table.string( "slug", 80 ).unique();              // e.g., "posts.edit.own"
            table.string( "name", 120 );                      // e.g., "Edit Own Posts"
            table.string( "description", 255 ).nullable();
            table.boolean( "is_system" ).default( 0 );
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "permissions" );
    }

}
