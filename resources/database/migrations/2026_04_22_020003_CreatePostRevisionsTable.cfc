/**
 * Phase 2 — `post_revisions` table.
 *
 * Append-only history of a post's title + body at each save. Powers the
 * revision-diff view (posts/RevisionDiff wire) and the B5 autosave
 * mechanism (Chunk 2.G) — autosaves are revisions with
 * `change_summary = 'autosave'`, pruned to the 20 most recent per post.
 */
component {

    function up( schema, qb ) {
        schema.create( "post_revisions", function( table ) {
            table.bigIncrements( "id" );
            table.unsignedBigInteger( "post_id" );
            table.unsignedInteger( "editor_id" );
            table.string( "title", 300 );
            table.longText( "body_markdown" );
            table.longText( "body_html" );
            table.string( "change_summary", 500 ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "post_id"   ).references( "id" ).onTable( "posts" ).onDelete( "CASCADE" );
            table.foreignKey( "editor_id" ).references( "id" ).onTable( "users" );
            table.index( [ "post_id", "created_at" ] );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "post_revisions" );
    }

}
