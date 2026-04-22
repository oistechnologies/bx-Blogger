/**
 * Phase 1 — `user_two_factor` table.
 * 2FA schema ships at MVP (Phase 1); full TOTP flow ships Phase 11 (B16).
 * Keeping this row per-user avoids migrating a populated `users` table later.
 */
component {

    function up( schema, qb ) {
        schema.create( "user_two_factor", function( table ) {
            table.unsignedInteger( "user_id" ).primaryKey();
            table.text( "secret_encrypted" ).nullable();          // encrypted TOTP shared secret
            table.text( "recovery_codes_json" ).nullable();       // JSON array of hashed recovery codes
            table.timestamp( "enabled_at" ).nullable();
            table.timestamp( "last_used_at" ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "user_id" )
                .references( "id" )
                .onTable( "users" )
                .onDelete( "CASCADE" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "user_two_factor" );
    }

}
