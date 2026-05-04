/**
 * Seed the site-wide default settings consumed by SeoService and the
 * /admin/settings/defaults wire (SEO Phase 2).
 *
 * Each row is upserted via "skip if present" — running on an
 * environment where an admin has already tuned a value via the new
 * defaults wire leaves their value alone. Adding a new key later is
 * just a new migration with the same shape.
 *
 *   site.title              — site name driving <title> on home + og:site_name everywhere
 *   site.tagline            — short one-line marketing line
 *   site.description        — meta description for the home page (140-160 chars)
 *   site.default_author_id  — fallback author for posts that have none (rare)
 *   social.twitter_handle   — drives <meta name="twitter:site"> (e.g. "@bxblogger")
 *   social.facebook_app_id  — drives <meta property="fb:app_id">
 *   social.facebook_publisher — Facebook page URL for og:article:publisher
 *
 * site.title defaults to the existing AppName so /admin doesn't see
 * a blank header on first paint after migrate-up; everything else
 * starts empty and the wire shows placeholder copy.
 */
component {

    variables.seeds = [
        {
            key   : "site.title",
            value : "bx-Blogger",
            type  : "string",
            desc  : "Site name. Drives the home page <title>, og:site_name on every page, and the WebSite JSON-LD on home."
        },
        {
            key   : "site.tagline",
            value : "",
            type  : "string",
            desc  : "Short one-line tagline (e.g. 'Modern publishing for BoxLang.'). Optional; renders below the site title in supported themes."
        },
        {
            key   : "site.description",
            value : "",
            type  : "string",
            desc  : "Meta description for the home page (140-160 characters). Falls back to the tagline when blank."
        },
        {
            key   : "site.default_author_id",
            value : "0",
            type  : "int",
            desc  : "Default author user id for posts without an explicit author. 0 = no default."
        },
        {
            key   : "social.twitter_handle",
            value : "",
            type  : "string",
            desc  : "Site Twitter / X handle (with the leading @). Drives <meta name='twitter:site'> on every public page."
        },
        {
            key   : "social.facebook_app_id",
            value : "",
            type  : "string",
            desc  : "Facebook App ID. Drives <meta property='fb:app_id'> for FB Insights integration."
        },
        {
            key   : "social.facebook_publisher",
            value : "",
            type  : "string",
            desc  : "Facebook publisher page URL. Drives og:article:publisher on Article schema."
        }
    ];

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        for ( var s in variables.seeds ) {
            var existing = qb.newQuery()
                .from( "settings" )
                .where( "setting_key", s.key )
                .count();
            if ( existing > 0 ) continue;
            qb.newQuery().from( "settings" ).insert( {
                "setting_key"   : s.key,
                "setting_value" : s.value,
                "setting_type"  : s.type,
                "description"   : s.desc,
                "updated_at"    : now
            } );
        }
    }

    function down( schema, qb ) {
        var keys = variables.seeds.map( function( s ) { return s.key; } );
        qb.newQuery()
            .from( "settings" )
            .whereIn( "setting_key", keys )
            .delete();
    }

}
