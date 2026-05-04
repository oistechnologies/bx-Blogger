/**
 * SEO Phase 12 — `outbound_links` table.
 *
 * One row per (post, external URL) pair. Populated by
 * OutboundLinkAuditJob: extracts every external href from a
 * post's body_html, performs a HEAD (falls back to GET on 405
 * Method Not Allowed) for each, and UPSERTs the result.
 *
 * `status_code` is the last observed response. 0 = network /
 * timeout / DNS failure (`error_message` carries the reason).
 *
 * `last_status_change_at` only updates when status_code flips
 * across the 2xx vs 3xx vs 4xx vs 5xx vs 0 buckets, so an
 * always-200 link doesn't touch the row past its first check.
 * Useful when the admin UI wants to highlight "newly broken"
 * vs "broken-since-forever" links.
 *
 * UNIQUE(post_id, url_hash) — full URL strings can run hundreds
 * of chars. SHA-256 hash of the normalized URL gives a stable
 * dedupe key without bloating the index. `url` itself is stored
 * as TEXT so the admin view + editor badge can show the raw URL.
 *
 * Cascading delete on post_id: when a post is hard-deleted,
 * its outbound-link history goes with it. Soft-delete (status
 * change) preserves the rows so a future restore inherits the
 * audit history.
 */
component {

    function up( schema, qb ) {
        schema.create( "outbound_links", function( table ) {
            table.bigIncrements( "id" );

            table.unsignedBigInteger( "post_id" );
            table.text( "url" );
            table.string( "url_hash", 64 );

            table.integer( "status_code" ).default( 0 );
            table.string( "error_message", 500 ).nullable();
            table.text( "redirect_target" ).nullable();

            table.timestamp( "last_checked_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "last_status_change_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "first_seen_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "post_id" )
                 .references( "id" )
                 .onTable( "posts" )
                 .onDelete( "CASCADE" );

            table.unique( [ "post_id", "url_hash" ], "uq_outbound_links_post_url" );
            table.index( "post_id",         "idx_outbound_links_post"     );
            table.index( "status_code",     "idx_outbound_links_status"   );
            table.index( "last_checked_at", "idx_outbound_links_last_chk" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "outbound_links" );
    }

}
