/**
 * Phase 1 — `remember_me_tokens` table.
 * Persistent-login tokens for "Remember Me" checkbox on login form.
 * cbauth generates + validates these; we just provide storage.
 */
component {

    function up( schema, qb ) {
        schema.create( "remember_me_tokens", function( table ) {
            table.increments( "id" );
            table.unsignedInteger( "user_id" );
            table.string( "token_hash", 64 );                    // sha-256 hex
            table.string( "ip", 45 ).nullable();
            table.string( "user_agent", 512 ).nullable();
            table.timestamp( "expires_at" );
            table.timestamp( "last_used_at" ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "token_hash" );
            table.index( "user_id" );

            table.foreignKey( "user_id" )
                .references( "id" )
                .onTable( "users" )
                .onDelete( "CASCADE" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "remember_me_tokens" );
    }

}
