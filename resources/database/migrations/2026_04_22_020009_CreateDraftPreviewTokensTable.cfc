/**
 * Phase 2 — `draft_preview_tokens` table (B2).
 *
 * Signed-URL previews for unpublished posts. Only the SHA-256 hash of
 * the token is stored; the plaintext lives in the URL we copied to the
 * user's clipboard. Default 7-day expiry (PLAN §23); a scheduler task
 * in Phase 6 prunes rows where `expires_at < now()`.
 */
component {

    function up( schema, qb ) {
        schema.create( "draft_preview_tokens", function( table ) {
            table.bigIncrements( "id" );
            table.unsignedBigInteger( "post_id" );
            table.char( "token_hash", 64 ).unique();
            table.unsignedInteger( "created_by" );
            table.datetime( "expires_at" );
            table.datetime( "last_used_at" ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "post_id"    ).references( "id" ).onTable( "posts" ).onDelete( "CASCADE" );
            table.foreignKey( "created_by" ).references( "id" ).onTable( "users" );
            table.index( "expires_at" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "draft_preview_tokens" );
    }

}
