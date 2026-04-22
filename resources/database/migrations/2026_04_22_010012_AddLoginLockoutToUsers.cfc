/**
 * Phase 1 Chunk 1.H — login lockout columns on `users`.
 *
 * Complements the cache-backed rate limiter (A6) with a durable per-user
 * lock. The interceptor smooths bursty hits; these columns remember that
 * this specific account tripped the threshold so the lock survives a
 * CacheBox eviction or app restart.
 *
 *   failed_login_count : running count since last successful login.
 *                        Resets to 0 on success or after locked_until passes.
 *   locked_until       : when populated, login is rejected until now() > this.
 *                        NULL means "not locked".
 */
component {

    function up( schema, qb ) {
        schema.alter( "users", function( table ) {
            table.addColumn( table.unsignedInteger( "failed_login_count" ).default( 0 ) );
            table.addColumn( table.timestamp( "locked_until" ).nullable() );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "users", function( table ) {
            table.dropColumn( "locked_until" );
            table.dropColumn( "failed_login_count" );
        } );
    }

}
