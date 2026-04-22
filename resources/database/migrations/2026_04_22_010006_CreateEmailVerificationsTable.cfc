/**
 * Phase 1 — `email_verifications` table (A2).
 * Token-hash-only storage (never plaintext). 7-day expiry per PLAN.
 * CASCADE on user delete so tokens don't outlive their owner.
 */
component {

    function up( schema, qb ) {
        schema.create( "email_verifications", function( table ) {
            table.increments( "id" );
            table.unsignedInteger( "user_id" );
            table.string( "token_hash", 64 );                     // sha-256 hex
            table.string( "email", 255 );                         // verify-THIS-email (supports email change)
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
        schema.drop( "email_verifications" );
    }

}
