/**
 * Phase 2 Chunk 2.H — `users.ai_monthly_tokens` column.
 *
 * Per-user override for the AI text-authoring monthly cap. The
 * three-valued semantics:
 *
 *   NULL → inherit `settings.ai.default_monthly_tokens`
 *   0    → unlimited (escape hatch for super_admins / internal bots)
 *   N    → hard cap at N tokens/month
 *
 * Chunk 2.I extends this pattern with `ai_monthly_images` for image
 * generation (separate cap — image-gen cost per call is 10–50× text,
 * so ops want independent knobs).
 */
component {

    function up( schema, qb ) {
        schema.alter( "users", function( table ) {
            table.addColumn( table.integer( "ai_monthly_tokens" ).nullable() );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "users", function( table ) {
            table.dropColumn( "ai_monthly_tokens" );
        } );
    }

}
