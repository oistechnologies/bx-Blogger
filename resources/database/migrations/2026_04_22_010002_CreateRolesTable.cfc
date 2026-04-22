/**
 * Phase 1 — `roles` table.
 * Six default roles per PLAN §10: super_admin, admin, editor, author,
 * contributor, subscriber (seeded in migration 010011).
 */
component {

    function up( schema, qb ) {
        schema.create( "roles", function( table ) {
            table.increments( "id" );
            table.string( "slug", 60 ).unique();              // e.g., "super_admin"
            table.string( "name", 120 );                      // e.g., "Super Admin"
            table.string( "description", 255 ).nullable();
            table.boolean( "is_system" ).default( 0 );        // prevent deletion of seeded roles
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "roles" );
    }

}
