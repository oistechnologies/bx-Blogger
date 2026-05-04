/**
 * SEO Phase 7 — seed the editable system prompt for the schema-type
 * classifier. Driven by the AI suggest button next to the schema
 * picker in the post editor + the auto-suggest toast that fires
 * on save when schema_type is null.
 *
 * The classifier returns a single type name (Article, FAQPage,
 * HowTo, Recipe, Product, VideoObject, NewsArticle, BlogPosting)
 * which the wire validates before applying.
 *
 * Skip-if-present so re-running the migration is safe.
 */
component {

    variables.prompt = {
        slug         : "schema_type_classifier",
        name         : "Schema.org Type Classifier",
        description  : "Sent as the system message when a user clicks 'Suggest schema type' or saves a post with schema_type unset. The model receives the post title + body excerpt and returns the single best schema.org type. Output is parsed strictly — keep the response a single type name on one line so the parser picks the right value.",
        prompt_text  : "You are a schema.org classifier for a blog post. Given the post title and body excerpt, choose the SINGLE best schema.org type from this exact list: Article, NewsArticle, BlogPosting, FAQPage, HowTo, Recipe, Product, VideoObject. Heuristics: pick FAQPage when the post is dominated by Q&A pairs; HowTo when it has numbered steps to accomplish a task; Recipe when it lists ingredients + cooking instructions; Product when it reviews or sells a single item with price/SKU; VideoObject when the primary content is an embedded video; NewsArticle when it reports breaking news with a dateline; otherwise Article. Return ONLY the type name on a single line. No explanation, no surrounding text."
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
