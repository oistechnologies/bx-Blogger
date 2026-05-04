/**
 * SEO Phase 4 — seed the four AI prompts driving the new SEO-AI
 * editor buttons:
 *
 *   seo_title_from_post        → "Generate SEO Title"
 *   seo_description_from_post  → "Generate SEO Description"
 *   seo_title_ctr_variations   → "Suggest 5 CTR Variants"
 *   alt_text_from_image        → "Generate Alt Text"
 *
 * Admin can edit later in /admin/ai-prompts (same UI used for the
 * existing draft_from_idea / review_post / excerpt_from_body /
 * image_generation prompts). Skip-if-present so re-running the
 * migration is safe.
 *
 * Each prompt is a constant: deliberately specific length / shape
 * constraints so the model output matches Google SERP recommended
 * sizes (50-60 char titles, 140-160 char descriptions). Built-in
 * security guardrails are still appended at runtime by
 * AiAssistantService.buildSystemPrompt — those cannot be disabled.
 */
component {

    variables.prompts = [
        {
            slug         : "seo_title_from_post",
            name         : "Generate SEO Title",
            description  : "Sent as the system message when a user clicks 'Generate SEO Title' in the post editor. The model receives the post's working title + body excerpt + optional focus keyword (wrapped as data) and returns a single SEO-optimized page title. Length target is 50-60 characters so it doesn't truncate in Google's SERP. Return ONLY the title — no quotes, no preamble, no markdown.",
            prompt_text  : "You are an SEO copywriter for bx-Blogger. Given a blog post's working title, body excerpt, and optional focus keyword, return a single SEO-optimized page title. Constraints: 50-60 characters total; include the focus keyword near the start when one is provided; lead with the most search-relevant phrase; no clickbait, no all-caps, no surrounding quotes, no trailing site-name suffix. Return ONLY the title text — no preamble, no markdown, no quotation marks."
        },
        {
            slug         : "seo_description_from_post",
            name         : "Generate SEO Description",
            description  : "Sent as the system message when a user clicks 'Generate SEO Description' in the post editor. The model receives the post's title + body excerpt + optional focus keyword and returns a single meta-description sentence. Length target is 140-160 characters (Google's SERP snippet truncation). Return ONLY the description — no quotes, no preamble.",
            prompt_text  : "You are an SEO copywriter for bx-Blogger. Given a blog post's title, body excerpt, and optional focus keyword, return a single meta description suitable for the page's <meta name='description'>. Constraints: 140-160 characters total; lead with a concrete benefit or hook; include the focus keyword once, naturally; end with a call-to-read where possible; no clickbait, no surrounding quotes, no preamble. Return ONLY the description text."
        },
        {
            slug         : "seo_title_ctr_variations",
            name         : "Suggest 5 CTR Title Variations",
            description  : "Sent as the system message when a user clicks 'Suggest 5 CTR Variants' in the post editor. The model receives the post's working title + body excerpt + optional focus keyword and returns 5 alternative SEO titles optimized for search-results click-through, each on its own line, prefixed with '1. ' through '5. '. Each variant uses a different angle: curiosity gap, listicle / numbers, current-year hook, brackets / parens for clarity, question form. Return ONLY the 5 numbered lines.",
            prompt_text  : "You are an SEO copywriter testing high-CTR headlines for bx-Blogger. Given a blog post's working title, body excerpt, and optional focus keyword, return 5 alternative SEO-optimized page titles, each maximizing SERP click-through. Use a different angle for each line: (1) curiosity gap, (2) listicle / numbers, (3) current-year hook, (4) brackets / parens for clarity, (5) question form. Each line: 50-60 characters total; include the focus keyword when one is provided; no clickbait. Output format: exactly 5 lines, each prefixed '1. ' through '5. ', no other text, no headings, no preamble, no markdown."
        },
        {
            slug         : "alt_text_from_image",
            name         : "Generate Image Alt Text",
            description  : "Sent as the system message when a user clicks 'Generate Alt Text' in the editor's media picker. Receives the image filename and a context sentence (post title or surrounding paragraph) and returns a single alt-text sentence. Length target is under 125 characters (screen-reader sweet spot). Return ONLY the alt text.",
            prompt_text  : "You are an accessibility copywriter. Given an image filename and a short context sentence describing where the image appears, return a single alt-text sentence describing what the image depicts. Constraints: under 125 characters; concrete and specific; no preamble like 'an image of'; no quotation marks; no end punctuation. Return ONLY the alt text."
        }
    ];

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        for ( var p in variables.prompts ) {
            var existing = qb.newQuery()
                .from( "ai_prompts" )
                .where( "slug", p.slug )
                .count();
            if ( existing > 0 ) continue;
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
