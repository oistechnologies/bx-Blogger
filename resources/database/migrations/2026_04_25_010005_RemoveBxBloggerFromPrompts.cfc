/**
 * Drop the project name from the seeded prompts.
 *
 * Three rows shipped with "for bx-Blogger" baked into their persona
 * line ("You are a careful editorial assistant for bx-Blogger.").
 * The phrase couples the prompts to one specific app, which is
 * pointless — the model doesn't need to know what the host is
 * called and the prompts work just as well in any installation.
 *
 * Strategy: surgical REPLACE on prompt_text + default_text.
 *   - When the row still contains the phrase, strip it (with the
 *     leading space so we don't leave "assistant ." with a stray
 *     space before the period).
 *   - When an operator already removed it (custom rewrite, or
 *     replaced with their own brand name), the REPLACE is a no-op.
 *   - default_text always refreshes so "Reset to default" picks up
 *     the cleaner wording even on rows the operator has tweaked.
 *
 * Affected rows: draft_from_idea, review_post, excerpt_from_body.
 * The image_generation row never carried the phrase. system_directives
 * is operator content from day one.
 */
component {

    variables.target = " for bx-Blogger";
    variables.slugs  = [ "draft_from_idea", "review_post", "excerpt_from_body" ];

    function up( schema, qb ) {
        for ( var slug in variables.slugs ) {
            queryExecute(
                "UPDATE ai_prompts
                    SET prompt_text  = REPLACE(prompt_text,  ?, ''),
                        default_text = REPLACE(default_text, ?, '')
                  WHERE slug = ?",
                [ variables.target, variables.target, slug ]
            );
        }
    }

    function down( schema, qb ) {
        // Best-effort revert. We can't know exactly where the phrase
        // sat in any operator-customized prompt, so put it back at
        // the most likely position (after "assistant" / "editor")
        // by string-matching on the resulting clean phrases.
        var restorations = [
            { "find" : "careful editorial assistant.", "replace" : "careful editorial assistant for bx-Blogger." },
            { "find" : "careful copy editor.",         "replace" : "careful copy editor for bx-Blogger." },
            { "find" : "an editorial assistant.",      "replace" : "an editorial assistant for bx-Blogger." }
        ];
        for ( var slug in variables.slugs ) {
            for ( var r in restorations ) {
                queryExecute(
                    "UPDATE ai_prompts
                        SET prompt_text  = REPLACE(prompt_text,  ?, ?),
                            default_text = REPLACE(default_text, ?, ?)
                      WHERE slug = ?",
                    [ r.find, r.replace, r.find, r.replace, slug ]
                );
            }
        }
    }

}
