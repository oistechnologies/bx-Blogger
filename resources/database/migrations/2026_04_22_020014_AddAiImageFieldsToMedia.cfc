/**
 * Phase 2 Chunk 2.I — extend `media` for AI-generated images.
 *
 * Adds `source` (provenance — upload / url_import / ai_generated) and
 * three columns that are only populated when `source = ai_generated`:
 *   ai_prompt   — the full user description passed to the generator
 *   ai_provider — e.g. "openrouter"
 *   ai_model    — the vendor/model slug that produced the image
 *
 * Lets the admin media library surface "ai-generated" filters, the
 * audit UI trace a rendered image back to its prompt, and a future
 * moderation module (Phase 11) scan just the generated subset.
 */
component {

    function up( schema, qb ) {
        schema.alter( "media", function( table ) {
            // Stored as a plain VARCHAR rather than a true ENUM — lets
            // later chunks add new provenance values without another
            // ALTER. Service-layer validation is authoritative.
            table.addColumn( table.string( "source", 20 ).default( "upload" ) );
            table.addColumn( table.text( "ai_prompt" ).nullable() );
            table.addColumn( table.string( "ai_provider", 64 ).nullable() );
            table.addColumn( table.string( "ai_model", 128 ).nullable() );
        } );
        // cfmigrations rejects mixing addColumn + index in one alter()
        // callback, so the index lands in a follow-up ALTER.
        schema.alter( "media", function( table ) {
            table.addConstraint( table.index( "source", "idx_media_source" ) );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "media", function( table ) {
            table.dropConstraint( "idx_media_source" );
        } );
        schema.alter( "media", function( table ) {
            table.dropColumn( "ai_model" );
            table.dropColumn( "ai_provider" );
            table.dropColumn( "ai_prompt" );
            table.dropColumn( "source" );
        } );
    }

}
