/**
 * Per-author opt-in for the "About the Author" block at the bottom of every
 * post. Default OFF so existing authors aren't surprised by a new block
 * appearing under their posts after deploy. Photo / email / socials inside
 * the block continue to honor the existing og_include_* preferences.
 */
component {

    function up( schema, qb ) {
        schema.alter( "users", function( table ) {
            table.addColumn( table.boolean( "show_author_block_on_posts" ).default( 0 ) );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "users", function( table ) {
            table.dropColumn( "show_author_block_on_posts" );
        } );
    }

}
