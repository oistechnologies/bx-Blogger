/**
 * SEO Phase 9 — seed the verification.* settings keys driving the
 * <meta name="...verification" content="..."> tags every theme
 * head-assets emits.
 *
 *   verification.google_search_console — google-site-verification
 *   verification.bing                  — msvalidate.01
 *   verification.yandex                — yandex-verification
 *   verification.pinterest             — p:domain_verify
 *   verification.facebook              — facebook-domain-verification
 *
 * Each starts blank — meta tag only emits when admin pastes a code
 * from the relevant search console.
 *
 * Skip-if-present so re-running this migration is safe.
 */
component {

    variables.seeds = [
        { key : "verification.google_search_console", value : "", type : "string", desc : "Google Search Console verification token (just the content value, not the full meta tag)." },
        { key : "verification.bing",                  value : "", type : "string", desc : "Bing Webmaster Tools verification token." },
        { key : "verification.yandex",                value : "", type : "string", desc : "Yandex Webmaster verification token." },
        { key : "verification.pinterest",             value : "", type : "string", desc : "Pinterest domain verification token." },
        { key : "verification.facebook",              value : "", type : "string", desc : "Facebook domain verification token (Business Manager → Brand Safety → Domains)." }
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
