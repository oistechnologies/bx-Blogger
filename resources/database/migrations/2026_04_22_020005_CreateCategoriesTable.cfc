/**
 * Phase 2 — `categories` table.
 *
 * Hierarchical via `parent_id` self-FK. Stores a materialized `path`
 * (e.g. `news/politics/election-2026`) so a single indexed lookup
 * answers "find all descendants of X" — the CategoryService maintains
 * it on create/move. Uniqueness on (parent_id, slug) allows two
 * categories named "news" at different tree levels.
 */
component {

    function up( schema, qb ) {
        schema.create( "categories", function( table ) {
            table.bigIncrements( "id" );
            table.unsignedBigInteger( "parent_id" ).nullable();
            table.string( "name", 120 );
            table.string( "slug", 140 );
            table.string( "path", 500 );                    // materialized 'a/b/c'
            table.text( "description" ).nullable();
            table.string( "seo_title", 255 ).nullable();
            table.string( "seo_description", 320 ).nullable();
            table.unsignedBigInteger( "og_image_id" ).nullable();
            table.integer( "sort_order" ).default( 0 );
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "parent_id"   ).references( "id" ).onTable( "categories" );
            table.foreignKey( "og_image_id" ).references( "id" ).onTable( "media" );
            table.unique( [ "parent_id", "slug" ], "uq_categories_parent_slug" );
            table.index( "path" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "categories" );
    }

}
