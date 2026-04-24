/**
 * Per-post OG-image fields for the eager-generation feature set.
 *
 *   og_version
 *     Monotonically increasing counter, bumped on every render
 *     (post save, manual regenerate-button click, author-pref-change
 *     bulk regen). Drives the rendered file's URL: the disk key is
 *     `{post_id}-v{og_version}.png` so the URL itself changes after
 *     each render — gives free cache-busting for browsers + the
 *     CDN fronting the og disk.
 *
 *   og_as_featured_image
 *     When ON, every theme surface that would otherwise render the
 *     post's `featured_media_id` (home cards, post header, related-
 *     post tiles, archive pages) substitutes the auto-rendered OG
 *     image instead. When OFF, the OG render is still produced and
 *     used as the `<meta og:image>` for social previews — but the
 *     featured image stays in place on-site.
 *
 * Doesn't touch the existing `og_image_id` column — that's the
 * manual override for an admin who explicitly picks a media-library
 * item as the OG. New columns work alongside it: og_image_id beats
 * everything when set; otherwise we render an OG keyed by og_version
 * and respect og_as_featured_image for in-site display.
 */
component {

    function up( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.addColumn(
                table.unsignedInteger( "og_version" ).default( 0 )
            );
            table.addColumn(
                table.boolean( "og_as_featured_image" ).default( 0 )
            );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.dropColumn( "og_as_featured_image" );
            table.dropColumn( "og_version" );
        } );
    }

}
