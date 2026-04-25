/**
 * Seed the three default AI prompts.
 *
 * - draft_from_idea + review_post: identical to the constants in
 *   models/services/AiAssistantService.bx so behavior is unchanged.
 * - image_generation: NEW — image gen had no system prompt before.
 *   Empty/inactive in the DB means "no system message added", which
 *   matches the previous behavior. The seeded default is editorial-
 *   blog flavored; admins can change it in /admin/ai-prompts.
 *
 * Both `prompt_text` (the live, editable body) and `default_text`
 * (the immutable seed) are written here. Reset-to-default in the
 * admin UI copies default_text back into prompt_text.
 */
component {

    variables.prompts = [
        {
            slug         : "draft_from_idea",
            name         : "Draft From Idea",
            description  : "Sent as the system message when a user clicks ""Generate Draft"" in the post editor. The model receives this prompt plus the user's idea (wrapped as data, not instructions) and is expected to return a Markdown document with an H1 title, a one-line excerpt, and 2–5 sections. Built-in security guardrails are appended automatically — you cannot disable them.",
            prompt_text  : "You are a careful editorial assistant for bx-Blogger. Given a short user idea, produce a publishable first draft in Markdown: a clear title as an H1, a one-line excerpt, and 2-5 sections. Keep the tone conversational and concrete. Do not invent facts — if something requires research, leave a TODO comment in the markdown."
        },
        {
            slug         : "review_post",
            name         : "Review Post",
            description  : "Sent as the system message when a user clicks ""Review & Suggest"" in the post editor. The model MUST return a JSON array of suggestion objects — the wire parses that JSON to populate the suggestions panel. Editing this prompt is fine, but if you change the required output shape (id / type / locationHint / before / after / rationale) the suggestions panel will stop working.",
            prompt_text  : "You are a careful copy editor for bx-Blogger. Given a blog post's markdown, return a JSON array of at most 5 suggestions. Each suggestion MUST be an object with keys: id (string), type (one of style / clarity / grammar / structure), locationHint (string describing where), before (the exact text to replace), after (the replacement), rationale (one sentence). Return ONLY the JSON array — no prose, no markdown fence."
        },
        {
            slug         : "image_generation",
            name         : "Image Generation Style",
            description  : "Optional system message prepended to every AI image-generation request. Use this to enforce a house style (composition, color, what to avoid). Leave the body empty or toggle Active off to send the user's prompt with no system message — that matches the original behavior.",
            prompt_text  : "You are an editorial illustration generator for a blog. Produce clean, web-friendly images with clear focal points and high contrast. Avoid text in the image, busy backgrounds, and watermarks. Compose for a 3:2 aspect ratio when the prompt is ambiguous."
        }
    ];

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        for ( var p in variables.prompts ) {
            qb.newQuery().from( "ai_prompts" ).insert( {
                "slug"         : p.slug,
                "name"         : p.name,
                "description"  : p.description,
                "prompt_text"  : p.prompt_text,
                "default_text" : p.prompt_text,
                "is_active"    : 1,
                "is_system"    : 1,
                "created_at"   : now,
                "updated_at"   : now
            } );
        }
    }

    function down( schema, qb ) {
        for ( var p in variables.prompts ) {
            qb.newQuery().from( "ai_prompts" ).where( "slug", p.slug ).delete();
        }
    }

}
