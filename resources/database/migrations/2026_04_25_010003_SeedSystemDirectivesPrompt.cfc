/**
 * Seed the `system_directives` ai_prompts row.
 *
 * Global behavior directives appended to EVERY text-generation
 * system prompt (draft_from_idea, review_post, excerpt_from_body)
 * — the operator's "house rules" that should hold across every
 * AI-authored output. Image generation is intentionally NOT
 * affected (different code path, different semantics).
 *
 * Layering inside AiAssistantService.buildSystemPrompt():
 *   1. base prompt (slug-specific, from DB w/ in-code fallback)
 *   2. AI_SYSTEM_PROMPT_TONE env var (deprecated; appended if set)
 *   3. system_directives (THIS row, appended when is_active + body)
 *   4. immutable security guardrails (in-code, ALWAYS appended last
 *      so a directive can never accidentally turn them off)
 *
 * Default is active=1 with an EMPTY body — the row exists so the
 * append code path is wired and ready, but operators see "no
 * directives in effect" until they type something into the textarea
 * at /admin/ai-prompts. An active row with an empty body is treated
 * as "no append" by getActiveBody's fallback rules.
 *
 * Idempotent: count() guard skips when the slug already exists.
 */
component {

    variables.slug = "system_directives";
    // Single space rather than empty string — qb's JDBC bindings
    // coerce "" to NULL on the wire, but prompt_text / default_text
    // are NOT NULL columns. getActiveBody() trims before checking
    // emptiness, so " " behaves identically to "" downstream: the
    // append code path skips when the trimmed body is zero-length.
    variables.prompt = " ";

    function up( schema, qb ) {
        var hits = qb.newQuery().from( "ai_prompts" )
            .where( "slug", variables.slug )
            .count();
        if ( val( hits ) > 0 ) return;

        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        qb.newQuery().from( "ai_prompts" ).insert( {
            "slug"         : variables.slug,
            "name"         : "System Directives (global)",
            "description"  : "Appended to every text-generation system prompt (draft, review, excerpt). Use this for cross-cutting rules you want enforced everywhere — ""NEVER use em dashes"", ""prefer the Oxford comma"", ""avoid AI-cliché phrases like 'in today's fast-paced world'"", brand voice notes, etc. Image generation is NOT affected. Empty body = no directives appended; uncheck Active to disable without clearing the body.",
            "prompt_text"  : variables.prompt,
            "default_text" : variables.prompt,
            "is_active"    : 1,
            "is_system"    : 1,
            "created_at"   : now,
            "updated_at"   : now
        } );
    }

    function down( schema, qb ) {
        qb.newQuery().from( "ai_prompts" )
            .where( "slug", variables.slug )
            .delete();
    }

}
