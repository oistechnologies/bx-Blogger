/**
 * Phase 2 — `posts` table.
 *
 * Single table covers both posts and pages via `post_type`; pages use
 * `parent_id` for hierarchy and `menu_order` for sorting. The compound
 * slug unique key includes `deleted_at` so soft-deleted rows don't block
 * a new post from taking the freed slug, while still preventing live
 * duplicates.
 *
 * content_version bumps on every save and is used downstream as a cache
 * key (Phase 5 pageCache, Phase 7 OG-image cache, etc.). reading_time +
 * word_count are computed in PostService.save() and cached here so the
 * theme can render them without re-parsing markdown on each request.
 */
component {

    function up( schema, qb ) {
        schema.create( "posts", function( table ) {
            table.bigIncrements( "id" );

            table.string( "post_type", 10 ).default( "post" );   // 'post' | 'page'
            table.unsignedBigInteger( "parent_id" ).nullable();  // pages: self-FK
            table.unsignedInteger( "author_id" );

            table.string( "title", 300 );
            table.string( "slug", 200 );
            table.text( "excerpt" ).nullable();

            table.longText( "body_markdown" );
            table.longText( "body_html" );
            table.datetime( "body_compiled_at" );
            table.integer( "content_version" ).default( 1 );

            // Enum-like status/visibility stored as strings. MySQL ENUM is
            // tempting but painful to extend later (requires ALTER TABLE);
            // varchar + app-layer validation is more forgiving.
            table.string( "status", 20 ).default( "draft" );
                // draft | pending_review | scheduled | published | archived | trashed
            table.string( "visibility", 20 ).default( "public" );
                // public | password | private
            table.string( "password_hash", 255 ).nullable();     // when visibility=password

            table.unsignedBigInteger( "featured_media_id" ).nullable();
            table.integer( "menu_order" ).default( 0 );
            table.string( "template_override", 120 ).nullable();

            // SEO
            table.string( "seo_title", 255 ).nullable();
            table.string( "seo_description", 320 ).nullable();
            table.string( "seo_canonical", 500 ).nullable();
            table.unsignedBigInteger( "og_image_id" ).nullable();
            table.boolean( "allow_indexing" ).default( 1 );

            table.bigInteger( "view_count" ).unsigned().default( 0 );
            table.smallInteger( "reading_time_minutes" ).unsigned().nullable();
            table.integer( "word_count" ).unsigned().nullable();

            table.datetime( "published_at" ).nullable();
            table.datetime( "scheduled_at" ).nullable();

            table.timestamp( "deleted_at" ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            // FK wiring — users first (exists since Phase 1), media second (020001)
            table.foreignKey( "author_id" ).references( "id" ).onTable( "users" );
            table.foreignKey( "parent_id" ).references( "id" ).onTable( "posts" );
            table.foreignKey( "featured_media_id" ).references( "id" ).onTable( "media" );
            table.foreignKey( "og_image_id" ).references( "id" ).onTable( "media" );

            // Lookup patterns — the composite status/type index powers
            // the list-by-status, latest-by-date query in the public views.
            table.index( [ "post_type", "status", "published_at" ] );
            table.index( "author_id" );
            table.index( "parent_id" );

            // Slug uniqueness scoped to (post_type, parent_id).
            table.unique( [ "post_type", "parent_id", "slug", "deleted_at" ], "uq_posts_slug" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "posts" );
    }

}
