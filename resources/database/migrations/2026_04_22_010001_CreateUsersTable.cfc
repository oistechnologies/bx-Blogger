/**
 * Phase 1 — `users` table.
 * Core account record. FK target for user_roles, email_verifications,
 * password_resets, user_two_factor, remember_me_tokens.
 */
component {

    function up( schema, qb ) {
        schema.create( "users", function( table ) {
            table.increments( "id" );

            // Identity
            table.string( "email", 255 ).unique();
            table.string( "password_hash", 60 );                    // bcrypt output length
            table.string( "display_name", 120 );
            table.string( "username", 80 ).nullable().unique();     // optional handle

            // Status
            table.boolean( "is_active" ).default( 1 );
            table.boolean( "two_factor_enabled" ).default( 0 );

            // Email verification (A2) + change-email flow
            table.timestamp( "email_verified_at" ).nullable();
            table.string( "pending_email", 255 ).nullable();

            // Password lifecycle (B17)
            table.timestamp( "password_changed_at" ).nullable();
            table.boolean( "must_change_password" ).default( 0 );

            // Audit of last login
            table.timestamp( "last_login_at" ).nullable();
            table.string( "last_login_ip", 45 ).nullable();         // IPv6-safe

            // Soft delete + timestamps (explicit names — qb.timestamps() uses
            // createdDate/modifiedDate which we don't want)
            table.timestamp( "deleted_at" ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "users" );
    }

}
