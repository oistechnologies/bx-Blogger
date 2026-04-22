/**
 * Phase 1 — `role_permissions` join table.
 * Composite PK (role_id, permission_id). Both FKs CASCADE on delete so
 * removing a role or permission cleans up assignments automatically.
 */
component {

    function up( schema, qb ) {
        schema.create( "role_permissions", function( table ) {
            table.unsignedInteger( "role_id" );
            table.unsignedInteger( "permission_id" );
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.primaryKey( [ "role_id", "permission_id" ] );

            table.foreignKey( "role_id" )
                .references( "id" )
                .onTable( "roles" )
                .onDelete( "CASCADE" );

            table.foreignKey( "permission_id" )
                .references( "id" )
                .onTable( "permissions" )
                .onDelete( "CASCADE" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "role_permissions" );
    }

}
