/**
 * Phase 2 — `post_categories` pivot.
 *
 * Many-to-many between posts and categories. `is_primary` lets a post
 * declare ONE category as canonical (used when the SEO layer picks the
 * canonical URL among multiple category-scoped URLs for the same post).
 * Service code enforces "at most one is_primary=TRUE per post" — the
 * schema doesn't express it; partial unique indexes aren't portable.
 */
component {

    function up( schema, qb ) {
        schema.create( "post_categories", function( table ) {
            table.unsignedBigInteger( "post_id" );
            table.unsignedBigInteger( "category_id" );
            table.boolean( "is_primary" ).default( 0 );

            table.primaryKey( [ "post_id", "category_id" ] );
            table.foreignKey( "post_id"     ).references( "id" ).onTable( "posts"      ).onDelete( "CASCADE" );
            table.foreignKey( "category_id" ).references( "id" ).onTable( "categories" ).onDelete( "CASCADE" );
            table.index( "category_id" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "post_categories" );
    }

}
