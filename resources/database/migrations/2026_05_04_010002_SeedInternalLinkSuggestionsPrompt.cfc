/**
 * SEO Phase 10 — seed the editable system prompt for the AI
 * internal-link suggester. Powered by the "Suggest internal links"
 * button in the post editor.
 *
 * The prompt receives the current draft body + a compact list of
 * { id, title, slug, excerpt } for the most-recent 200 published
 * posts and returns a JSON array of slug recommendations. The
 * editor parses that JSON to populate the suggestion list.
 *
 * Skip-if-present so re-running the migration is safe.
 */
component {

    variables.prompt = {
        slug         : "internal_link_suggestions",
        name         : "Internal Link Suggestions",
        description  : "Sent as the system message when a user clicks 'Suggest internal links' in the post editor. The model receives the current draft body + a compact JSON array of candidate posts (most-recent 200) and returns 3-5 slug recommendations. The wire parses the JSON output to populate the Insert-link panel — keep the response a strict JSON array or the parser will fall back to an empty list.",
        prompt_text  : "You are an editor recommending internal links for a blog post. The user message contains the current draft body followed by a JSON array of candidate posts with shape { id, title, slug, excerpt }. Pick 3-5 candidates whose topic genuinely supports the draft and return ONLY a JSON array of objects with shape { slug, title, reason }. The reason field is one short sentence (under 120 chars) explaining why this link helps the reader. Do not invent slugs or titles; only recommend posts from the provided candidate list. Output strict JSON — no preamble, no markdown fence, no trailing prose."
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
