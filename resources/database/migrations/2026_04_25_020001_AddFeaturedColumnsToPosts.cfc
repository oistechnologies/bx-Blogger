/**
 * Per-post "featured" pin for the home-page featured-posts section.
 *
 *   featured
 *     Boolean toggle controlled by an admin checkbox in the post
 *     editor sidebar ("Pin to home as featured"). When themes have
 *     `show_featured_section` = true, the home view renders the most-
 *     recently-pinned posts in their own section above the regular
 *     post grid.
 *
 *   featured_at
 *     Timestamp captured the moment `featured` flips ON. Indexed +
 *     used as the sort key on the featured listing query so the most-
 *     recently-pinned post leads the section. Cleared (set to NULL)
 *     when `featured` flips OFF so a future re-pin re-stamps the
 *     timestamp and bumps the post back to the top.
 *
 * No backfill needed — every existing post is `featured=0` by default.
 */
component {

    function up( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.addColumn(
                table.boolean( "featured" ).default( 0 )
            );
            table.addColumn(
                table.timestamp( "featured_at" ).nullable()
            );
        } );
        // Index supports the listFeatured() query path: filter by
        // featured=1, order by featured_at DESC. Composite covers both.
        schema.alter( "posts", function( table ) {
            table.addIndex(
                columns = [ "featured", "featured_at" ],
                name    = "idx_posts_featured"
            );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.dropIndex( "idx_posts_featured" );
            table.dropColumn( "featured_at" );
            table.dropColumn( "featured" );
        } );
    }

}
