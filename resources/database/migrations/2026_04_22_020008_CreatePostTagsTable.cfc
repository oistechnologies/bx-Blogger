/**
 * Phase 2 — `post_tags` pivot.
 *
 * Many-to-many between posts and tags. Composite PK prevents dupes;
 * index on tag_id makes "all posts with tag X" a single index scan.
 */
component {

    function up( schema, qb ) {
        schema.create( "post_tags", function( table ) {
            table.unsignedBigInteger( "post_id" );
            table.unsignedBigInteger( "tag_id"  );

            table.primaryKey( [ "post_id", "tag_id" ] );
            table.foreignKey( "post_id" ).references( "id" ).onTable( "posts" ).onDelete( "CASCADE" );
            table.foreignKey( "tag_id"  ).references( "id" ).onTable( "tags"  ).onDelete( "CASCADE" );
            table.index( "tag_id" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "post_tags" );
    }

}
