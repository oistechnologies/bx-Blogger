/**
 * Phase 1 — `user_roles` join table.
 * Multi-role users supported even though most users have one role
 * (per PLAN §9 "the seam costs nothing now and unlocks later").
 */
component {

    function up( schema, qb ) {
        schema.create( "user_roles", function( table ) {
            table.unsignedInteger( "user_id" );
            table.unsignedInteger( "role_id" );
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.primaryKey( [ "user_id", "role_id" ] );

            table.foreignKey( "user_id" )
                .references( "id" )
                .onTable( "users" )
                .onDelete( "CASCADE" );

            table.foreignKey( "role_id" )
                .references( "id" )
                .onTable( "roles" )
                .onDelete( "CASCADE" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "user_roles" );
    }

}
