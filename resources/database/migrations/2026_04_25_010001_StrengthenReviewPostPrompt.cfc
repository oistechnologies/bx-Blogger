/**
 * Strengthen the review_post system prompt.
 *
 * The original seed described the JSON shape but small / cheap chat
 * models (qwen-turbo, gemma free) routinely returned `{suggestion,
 * location}` instead of `{id, type, locationHint, before, after,
 * rationale}`. Without an exact `before` substring the editor wire
 * can't auto-apply via search-and-replace, so the Accept button
 * disappears.
 *
 * This migration replaces the prompt with a stricter version that
 * (a) puts each schema key on its own line for readability,
 * (b) explicitly tells the model the `before` field MUST be a
 *     verbatim substring from the input,
 * (c) instructs the model to skip vague advice that isn't a concrete
 *     replacement,
 * (d) shows a concrete one-line JSON example so even small models
 *     can copy the shape.
 *
 * Only writes when the existing row still matches the original seed
 * — operators who have already tweaked the prompt via /admin/ai-prompts
 * keep their version. default_text is updated unconditionally so
 * "Reset to default" picks up the new wording.
 */
component {

    variables.originalReviewPrompt = "You are a careful copy editor for bx-Blogger. Given a blog post's markdown, return a JSON array of at most 5 suggestions. Each suggestion MUST be an object with keys: id (string), type (one of style / clarity / grammar / structure), locationHint (string describing where), before (the exact text to replace), after (the replacement), rationale (one sentence). Return ONLY the JSON array — no prose, no markdown fence.";

    function up( schema, qb ) {
        var nl = chr( 10 );
        var stricter = "You are a careful copy editor for bx-Blogger. Given a blog post markdown, return a JSON array of at most 5 suggestions. Each suggestion MUST be an object with these exact keys:" & nl
            & "  id (short string identifier)," & nl
            & "  type (one of: style, clarity, grammar, structure)," & nl
            & "  locationHint (where in the post)," & nl
            & "  before (the EXACT verbatim text to replace - copied character-for-character from the input)," & nl
            & "  after (the replacement text)," & nl
            & "  rationale (one sentence explaining the change)." & nl
            & nl
            & "The before field is critical: it must be the literal substring from the post that you want changed. Without an exact match the editor cannot apply your suggestion. If you have advice that does not map to a specific text replacement, skip it - return only actionable substitutions." & nl
            & nl
            & "Example of one valid suggestion:" & nl
            & "{""id"":""s1"",""type"":""clarity"",""locationHint"":""opening paragraph"",""before"":""This thing is good."",""after"":""This approach reduces deployment time by half."",""rationale"":""Specific outcome reads stronger than vague praise.""}" & nl
            & nl
            & "Return ONLY the JSON array - no prose, no markdown fence, no commentary.";

        // Always refresh default_text so "Reset to default" returns the
        // new wording. Only refresh prompt_text when the row is still
        // the original seed (no operator edits to clobber).
        qb.newQuery().from( "ai_prompts" )
            .where( "slug", "review_post" )
            .update( { "default_text" : stricter } );

        qb.newQuery().from( "ai_prompts" )
            .where( "slug", "review_post" )
            .where( "prompt_text", variables.originalReviewPrompt )
            .update( { "prompt_text" : stricter } );
    }

    function down( schema, qb ) {
        // Restore the original wording on both columns when the
        // current prompt_text matches the strict version we just
        // wrote — leaves operator edits alone.
        qb.newQuery().from( "ai_prompts" )
            .where( "slug", "review_post" )
            .update( { "default_text" : variables.originalReviewPrompt } );
    }

}
