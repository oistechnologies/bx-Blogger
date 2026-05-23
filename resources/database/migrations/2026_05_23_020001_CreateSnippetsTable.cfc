/**
 * `snippets` — admin-authored HTML / JS / CSS fragments injected at
 * one of four positions on rendered public pages.
 *
 *   location:
 *     head                 → just before </head>             (global)
 *     before_closing_body  → just before </body>             (global)
 *     before_body          → just before the post/page body  (post and/or page,
 *                                                             gated by applies_to_*)
 *     above_taxonomy       → just above the post-taxonomy
 *                            partial on the single-post page (post-only by nature)
 *
 *   applies_to_posts / applies_to_pages
 *     Only consulted when location = 'before_body'. The other slots
 *     are inherently scoped (global on every page, or post-only).
 *
 *   sort_order
 *     Render order when multiple snippets share a location. Lowest
 *     first; stable, no ties broken by id so we can re-order via
 *     the admin UI without rewriting ids.
 *
 *   enabled
 *     Per-snippet kill-switch. The admin UI can toggle without
 *     deleting the row.
 *
 *   content
 *     LONGTEXT — rendered RAW (no escaping) by SnippetService.
 *     The feature is intentional raw injection for analytics, A/B
 *     tags, etc., and is gated by `snippets.manage`.
 */
component {

    function up( schema, qb ) {
        schema.create( "snippets", function( table ) {
            table.bigIncrements( "id" );
            table.string( "name", 150 );
            table.string( "description", 500 ).nullable();
            table.string( "location", 40 );
            table.longText( "content" ).nullable();
            table.boolean( "enabled" ).default( 1 );
            table.boolean( "applies_to_posts" ).default( 1 );
            table.boolean( "applies_to_pages" ).default( 1 );
            table.integer( "sort_order" ).default( 0 );
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( [ "location", "enabled", "sort_order" ], "ix_snippets_location" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "snippets" );
    }

}
