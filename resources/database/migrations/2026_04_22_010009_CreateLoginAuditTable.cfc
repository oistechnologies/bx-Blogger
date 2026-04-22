/**
 * Phase 1 — `login_audit` table.
 *
 * Records every login attempt (success or failure) for:
 *   - A6 rate limiting (query window for recent attempts per email/IP)
 *   - Security audit (who logged in from where, when)
 *
 * Intentionally NO foreign key to users — we want to keep the audit row
 * even if the user account is later deleted. `email` is stored as-typed
 * (not normalized to user_id) so failed-login attempts with bogus emails
 * are also captured.
 */
component {

    function up( schema, qb ) {
        schema.create( "login_audit", function( table ) {
            table.increments( "id" );
            table.string( "email", 255 );                        // as typed on login form
            table.unsignedInteger( "user_id" ).nullable();       // resolved user (null on bad email)
            table.string( "ip", 45 );                            // IPv6-safe
            table.string( "user_agent", 512 ).nullable();
            table.boolean( "success" ).default( 0 );
            table.string( "failure_reason", 60 ).nullable();     // "bad_password", "user_inactive", "rate_limited"
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "email" );
            table.index( "ip" );
            table.index( "created_at" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "login_audit" );
    }

}
