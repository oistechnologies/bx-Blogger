/**
 * Refresh system_directives row:
 *   1. Replace the placeholder " " body with a meaningful default
 *      so the feature ships with a useful out-of-the-box rule.
 *   2. Tighten the description text — the original wording mentioned
 *      "uncheck Active to disable without clearing the body" which
 *      implied the toggle and the body work differently. They don't:
 *      the row is skipped completely whenever it's inactive OR the
 *      body is empty/whitespace.
 *
 * Conservative on prompt_text: only overwrite when the row still
 * matches the original placeholder — operators who have already
 * typed their own rules in /admin/ai-prompts keep their version.
 * default_text + description always refresh so "Reset to default"
 * picks up the new wording and the admin card explains the new
 * behavior.
 */
component {

    variables.slug = "system_directives";
    variables.placeholder = " ";   // what the original seed inserted
    variables.newDefault  = "Do not use em dashes (—) in generated content. Use commas, parentheses, or restructure into shorter sentences instead.";
    variables.newDescription = "Cross-cutting house rules appended to every text-generation system prompt (draft, review, excerpt). Image generation is not affected. Skipped completely whenever the row is inactive OR the body is empty / whitespace — toggle Active off when you want a temporary pause, clear the body when the rule no longer applies. Add as many rules as you like, one per line.";

    function up( schema, qb ) {
        // default_text + description always refresh.
        qb.newQuery().from( "ai_prompts" )
            .where( "slug", variables.slug )
            .update( {
                "default_text" : variables.newDefault,
                "description"  : variables.newDescription
            } );

        // prompt_text only when the operator hasn't already customized.
        qb.newQuery().from( "ai_prompts" )
            .where( "slug", variables.slug )
            .where( "prompt_text", variables.placeholder )
            .update( { "prompt_text" : variables.newDefault } );
    }

    function down( schema, qb ) {
        // Best-effort revert: restore the original empty-ish placeholder
        // + a short description fallback. Operator edits stay intact.
        qb.newQuery().from( "ai_prompts" )
            .where( "slug", variables.slug )
            .update( {
                "default_text" : variables.placeholder,
                "description"  : "Appended to every text-generation system prompt."
            } );
        qb.newQuery().from( "ai_prompts" )
            .where( "slug", variables.slug )
            .where( "prompt_text", variables.newDefault )
            .update( { "prompt_text" : variables.placeholder } );
    }

}
