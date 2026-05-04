/**
 * SEO Phase 8 — per-tag and per-author SEO overrides.
 *
 * Categories already have seo_title / seo_description / og_image_id
 * (Phase 1 migration). This brings tags + users to parity so:
 *
 *   /tag/{slug}     — uses tag.seo_title / seo_description /
 *                     og_image_id when set, else falls back to the
 *                     archive's generic title + tag description.
 *   /author/{slug}  — uses user.seo_title / seo_description /
 *                     og_image_id when set, else falls back to the
 *                     author's display name + bio.
 *
 * No FK constraint on og_image_id (matches the existing categories
 * pattern) — SeoService falls back to "no image" if the media row
 * has been deleted.
 *
 * No backfill — every existing row has the new columns NULL and
 * gets the same generic archive output it has today.
 */
component {

    function up( schema, qb ) {
        schema.alter( "tags", function( table ) {
            table.addColumn(
                table.string( "seo_title", 255 ).nullable()
            );
            table.addColumn(
                table.string( "seo_description", 320 ).nullable()
            );
            table.addColumn(
                table.unsignedBigInteger( "og_image_id" ).nullable()
            );
        } );

        schema.alter( "users", function( table ) {
            table.addColumn(
                table.string( "seo_title", 255 ).nullable()
            );
            table.addColumn(
                table.string( "seo_description", 320 ).nullable()
            );
            table.addColumn(
                table.unsignedBigInteger( "og_image_id" ).nullable()
            );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "tags", function( table ) {
            table.dropColumn( "og_image_id" );
            table.dropColumn( "seo_description" );
            table.dropColumn( "seo_title" );
        } );
        schema.alter( "users", function( table ) {
            table.dropColumn( "og_image_id" );
            table.dropColumn( "seo_description" );
            table.dropColumn( "seo_title" );
        } );
    }

}
