/**
 * SEO Phase 5 — `focus_keyword` column on `posts`.
 *
 * Drives:
 *   - SeoAuditService deterministic checks (in-title / in-first-paragraph
 *     / in-url / density)
 *   - The four AI generate* methods on AiAssistantService accept it as
 *     an optional input — the live audit panel populates the value as
 *     the user types in the new sidebar field
 *   - The AI SEO Audit Agent uses it as a get_focus_keyword_metrics
 *     tool input
 *
 * VARCHAR(120) — long enough for multi-word keyword phrases ("BoxLang
 * adoption in CFML shops") without bleeding into title territory.
 * Nullable + NOT-NULL-default-false so existing posts roll forward
 * with no audit-score penalty until the user opts in.
 *
 * No backfill needed — every existing post is focus_keyword=NULL.
 */
component {

    function up( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.addColumn(
                table.string( "focus_keyword", 120 ).nullable()
            );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.dropColumn( "focus_keyword" );
        } );
    }

}
