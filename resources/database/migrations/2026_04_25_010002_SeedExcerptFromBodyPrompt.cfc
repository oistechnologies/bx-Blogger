/**
 * Seed the `excerpt_from_body` ai_prompts row.
 *
 * Powers the new "Generate excerpt" button next to the Excerpt label
 * in the post editor. The model is fed the post's markdown body and
 * asked for a 1-2 sentence synopsis suitable for use as a public-
 * facing short description / meta description.
 *
 * Constraint reminders embedded in the prompt:
 *   - PLAIN PROSE only — no markdown, no quotes, no preamble. The
 *     output drops straight into the excerpt textarea where it shows
 *     verbatim on archive pages and in OG cards.
 *   - 150-200 chars total. Long enough to be informative, short
 *     enough to fit a Twitter card / search-result snippet.
 *
 * Seed-only migration: the table + ai.prompts.manage permission are
 * already in place from migrations 020003 / 020005. Idempotent guard
 * (skips on duplicate slug) handles the case where this gets re-run
 * after a manual UI edit.
 */
component {

    variables.slug = "excerpt_from_body";
    variables.prompt = "You are an editorial assistant for bx-Blogger. Given the markdown body of a blog post, return a single 1-to-2 sentence synopsis suitable for use as a public excerpt or short meta description. Plain prose only - no markdown, no surrounding quotes, no preamble like ""Here is your excerpt"". Write in third person, present tense, focused on what the post actually delivers to a reader. Aim for 150-200 characters total. Return ONLY the synopsis text.";

    function up( schema, qb ) {
        // Idempotent: only insert when the slug doesn't already exist.
        // qb's .first() returns an empty struct on no-match (NOT null)
        // — both cases mean "row missing" and we should proceed.
        var hits = qb.newQuery().from( "ai_prompts" )
            .where( "slug", variables.slug )
            .count();
        if ( val( hits ) > 0 ) return;

        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        qb.newQuery().from( "ai_prompts" ).insert( {
            "slug"         : variables.slug,
            "name"         : "Excerpt From Body",
            "description"  : "Sent as the system message when an editor clicks the Generate Excerpt button next to the Excerpt field. The model receives the post body and is expected to return a 1-2 sentence plain-prose synopsis (no markdown, no quotes). Output drops directly into the Excerpt textarea.",
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
