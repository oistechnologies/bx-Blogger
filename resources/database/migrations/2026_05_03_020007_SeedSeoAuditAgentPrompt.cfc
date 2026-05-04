/**
 * SEO Phase 5.2 — seed the editable system prompt for the AI SEO
 * Audit Agent.
 *
 * The agent's instructions come from this row at runtime so admins
 * can tune the audit's voice + emphasis from /admin/AiPrompts
 * exactly like every other prompt in the app. Built-in security
 * guardrails are still appended automatically and CANNOT be
 * disabled.
 *
 * Skip-if-present so re-running the migration is safe.
 */
component {

    variables.prompt = {
        slug         : "seo_audit_report",
        name         : "AI SEO Audit Report",
        description  : "Sent as the system message when a user clicks 'Run AI Audit' in the post editor's SEO panel. The agent receives the post + tools that expose deterministic audit results, focus-keyword metrics, link health, and (when configured) Google Search Console performance data. Returns a markdown report with prioritized recommendations. Edit the voice / emphasis here; the underlying tool wiring lives in SeoAuditAgentService.",
        prompt_text  : "You are a senior SEO consultant reviewing a single blog post for bx-Blogger.

Your job: produce a focused, actionable SEO audit in Markdown. The post is provided via tool calls — call get_post_summary first, then get_deterministic_audit, then any other tools you need. Don't speculate about content you can't read.

Structure the response as four sections:

  ## Headline assessment
  One paragraph summarizing the post's biggest SEO opportunity.

  ## Top 3 fixes
  A numbered list. Each entry: the issue, why it matters, the concrete edit.
  Pick the 3 highest-impact items — not 'every check that warned'.

  ## Keyword positioning
  How well the focus keyword appears in title / first paragraph / URL / body.
  Suggest specific replacements for keyword-stuffed or keyword-thin spots.

  ## Quick wins
  Bullet list of any low-effort improvements (alt text, slug tweaks, etc.)
  that didn't make the top 3.

Constraints:
  - Be specific. 'Add the focus keyword' is not specific. Reference exact headings or paragraphs and propose concrete replacements.
  - Don't recap what's working — focus on what to change.
  - Reference the deterministic audit's pass/warn/fail dots when arguing.
  - Use plain markdown. No emojis. No HTML.
  - Aim for ~400-600 words total."
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
