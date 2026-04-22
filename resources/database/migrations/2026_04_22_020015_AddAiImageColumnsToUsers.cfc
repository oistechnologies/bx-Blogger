/**
 * Phase 2 Chunk 2.I — per-user image-gen overrides.
 *
 *   ai_monthly_images           — NULL inherits AI_DEFAULT_MONTHLY_IMAGES,
 *                                 0 unlimited, positive integer is a cap.
 *                                 Separate from ai_monthly_tokens so ops
 *                                 can grant generous text access while
 *                                 keeping image-gen locked down (per-call
 *                                 cost is 10–50× text).
 *
 *   ai_image_variants_per_request — NULL inherits the system setting,
 *                                 positive integer overrides (service
 *                                 clamps to 1–8 regardless). Lets admins
 *                                 give power users more previews per
 *                                 click without loosening the cost cap.
 */
component {

    function up( schema, qb ) {
        schema.alter( "users", function( table ) {
            table.addColumn( table.integer( "ai_monthly_images" ).nullable() );
            table.addColumn( table.integer( "ai_image_variants_per_request" ).nullable() );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "users", function( table ) {
            table.dropColumn( "ai_image_variants_per_request" );
            table.dropColumn( "ai_monthly_images" );
        } );
    }

}
