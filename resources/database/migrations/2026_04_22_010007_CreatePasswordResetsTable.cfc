/**
 * Phase 1 — `password_resets` table (A1).
 * Parallel structure to email_verifications — token-hash-only, short
 * expiry (default 1 hour per PLAN), consumed_at marks single-use.
 */
component {

    function up( schema, qb ) {
        schema.create( "password_resets", function( table ) {
            table.increments( "id" );
            table.unsignedInteger( "user_id" );
            table.string( "token_hash", 64 );                     // sha-256 hex
            table.timestamp( "expires_at" );
            table.timestamp( "consumed_at" ).nullable();
            table.string( "request_ip", 45 ).nullable();
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
        schema.drop( "password_resets" );
    }

}
