/**
 * Phase 2 — `media` table.
 *
 * Every uploaded file (or AI-generated image in Phase 2.I) is a row here.
 * Posts reference media via featured_media_id / og_image_id; categories
 * via og_image_id; the media table must exist before those tables so the
 * FKs resolve. Dedup via `hash` (sha-256 over the raw bytes).
 *
 * Phase 2.I extends this table with source/ai_prompt/ai_provider/ai_model
 * columns when AI image generation lands.
 */
component {

    function up( schema, qb ) {
        schema.create( "media", function( table ) {
            // BIGINT PK — posts.featured_media_id / posts.og_image_id
            // reference this, and those columns are BIGINT per plan; types
            // must match or InnoDB rejects the foreign key.
            table.bigIncrements( "id" );
            table.unsignedInteger( "uploader_id" ).references( "id" ).onTable( "users" );

            // Storage pointers (cbfs disk + relative path)
            table.string( "disk", 60 );                         // 'local','s3','minio'
            table.string( "path", 500 );
            table.string( "filename", 255 );
            table.string( "original_filename", 255 );

            // Content metadata
            table.string( "mime_type", 120 );
            table.bigInteger( "size_bytes" ).unsigned();
            table.integer( "width" ).unsigned().nullable();
            table.integer( "height" ).unsigned().nullable();
            table.char( "hash", 64 ).nullable();                // sha-256 over bytes
            table.decimal( "focal_x", 5, 4 ).default( "0.5" );  // 0..1 image-relative
            table.decimal( "focal_y", 5, 4 ).default( "0.5" );
            table.string( "alt_text", 500 ).nullable();
            table.string( "title", 255 ).nullable();
            table.string( "caption", 500 ).nullable();
            table.json( "thumbnails_json" ).nullable();         // {small:{path,w,h}, ...}

            table.timestamp( "deleted_at" ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.index( "uploader_id" );
            table.index( "mime_type" );
            table.index( "hash" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "media" );
    }

}
