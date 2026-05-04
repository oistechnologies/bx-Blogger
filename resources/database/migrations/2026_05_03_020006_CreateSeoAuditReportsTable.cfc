/**
 * SEO Phase 5.2 — `seo_audit_reports` table.
 *
 * Persists AI-generated SEO audit reports per post:
 *
 *   id                    bigint PK
 *   post_id               FK posts.id (cascade delete)
 *   generated_by_user_id  FK users.id (nullable on user delete)
 *   generated_at          timestamp
 *   model_used            varchar — captured at generation so reports
 *                         survive a model swap and remain reproducible
 *   prompt_version        bigint — references ai_prompts.id used at
 *                         generation time; lets the editor surface
 *                         "this audit was made with v3 of the prompt"
 *   deterministic_score   tinyint — SeoAuditService score at the time
 *                         the audit was run, so before/after compare
 *                         is meaningful
 *   report_markdown       mediumtext — the agent's prose report
 *   report_json           mediumtext nullable — structured data the
 *                         agent emitted alongside (rendered as a side
 *                         panel)
 *   tokens_used           int unsigned
 *   status                varchar — pending | complete | failed
 *   error_message         text nullable
 *
 * Indexed on (post_id, generated_at DESC) so the editor's history
 * panel pulls the latest in O(1).
 */
component {

    function up( schema, qb ) {
        schema.create( "seo_audit_reports", function( table ) {
            table.bigIncrements( "id" );
            table.unsignedBigInteger( "post_id" );
            table.unsignedInteger( "generated_by_user_id" ).nullable();
            table.timestamp( "generated_at" ).default( "CURRENT_TIMESTAMP" );
            table.string( "model_used", 120 ).nullable();
            table.unsignedBigInteger( "prompt_version" ).nullable();
            table.unsignedTinyInteger( "deterministic_score" ).default( 0 );
            table.mediumText( "report_markdown" ).nullable();
            table.mediumText( "report_json" ).nullable();
            table.unsignedInteger( "tokens_used" ).default( 0 );
            table.string( "status", 16 ).default( "pending" );
            table.text( "error_message" ).nullable();

            table.foreignKey( "post_id" )
                .references( "id" )
                .onTable( "posts" )
                .onDelete( "CASCADE" )
                .onUpdate( "CASCADE" );

            table.foreignKey( "generated_by_user_id" )
                .references( "id" )
                .onTable( "users" )
                .onDelete( "SET NULL" )
                .onUpdate( "CASCADE" );

            table.index( [ "post_id", "generated_at" ], "idx_audit_post_gen" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "seo_audit_reports" );
    }

}
