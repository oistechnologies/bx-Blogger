/**
 * SEO Phase 13 — seed the editable system prompt for the AI
 * post-refresh auditor. Drives the "AI suggest refresh" button
 * on the SEO dashboard's Stale content tab.
 *
 * The prompt receives the post title + body and returns a
 * JSON array of "things this post probably needs updated"
 * suggestions — outdated year mentions, version numbers,
 * stat claims that may no longer hold, references to
 * deprecated tools, etc.
 *
 * Skip-if-present so re-running the migration is safe.
 */
component {

    variables.prompt = {
        slug         : "post_refresh_audit",
        name         : "Post Refresh Audit",
        description  : "Sent as the system message when an editor clicks 'AI suggest refresh' on a stale post in /admin/seo. The model returns 3-7 specific items the post probably needs updated (outdated years, versions, stats, deprecated tools). Output must be strict JSON of shape { suggestions: [ { type, snippet, reason } ] } so the dashboard can render structured rows.",
        prompt_text  : "You are an editor auditing an older blog post for content that has likely gone stale. The user message contains the post title + body. Identify 3-7 SPECIFIC items the post needs to update — quoted snippets where year mentions are outdated, version numbers that have moved on, statistics that may no longer hold, references to tools/companies that are deprecated or rebranded, and links/snippets that imply 'recently' but were written years ago. Return ONLY strict JSON of shape { ""suggestions"": [ { ""type"": ""year|version|stat|tool|tone|link|other"", ""snippet"": ""quoted text from the post (under 200 chars)"", ""reason"": ""one short sentence on what to update and why"" } ] }. No preamble, no markdown fence, no trailing prose. If the post genuinely needs no updates, return { ""suggestions"": [] }."
    };

    function up( schema, qb ) {
        var existing = qb.newQuery()
            .from( "ai_prompts" )
            .where( "slug", variables.prompt.slug )
            .count();
        if ( existing > 0 ) return;

        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        qb.newQuery().from( "ai_prompts" ).insert( {
            "slug"         : variables.prompt.slug,
            "name"         : variables.prompt.name,
            "description"  : variables.prompt.description,
            "prompt_text"  : variables.prompt.prompt_text,
            "default_text" : variables.prompt.prompt_text,
            "is_active"    : 1,
            "is_system"    : 1,
            "created_at"   : now,
            "updated_at"   : now
        } );
    }

    function down( schema, qb ) {
        qb.newQuery().from( "ai_prompts" ).where( "slug", variables.prompt.slug ).delete();
    }

}
