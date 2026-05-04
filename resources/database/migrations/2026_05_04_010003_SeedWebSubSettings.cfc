/**
 * SEO Phase 11 — seed WebSub (PubSubHubbub) settings driving the
 * <link rel="hub"> declaration in JSON Feeds + the post-publish
 * push notification job.
 *
 *   seo.websub_enabled   — master toggle (default false; opt-in).
 *   seo.websub_hub_url   — hub endpoint to ping. Defaults to
 *                          Google's free public hub.
 *
 * Skip-if-present so re-running the migration is safe.
 */
component {

    variables.seeds = [
        {
            key   : "seo.websub_enabled",
            value : "false",
            type  : "bool",
            desc  : "Master toggle for WebSub (PubSubHubbub). Off by default; flip on to ping the hub on every post publish + advertise the hub URL in feeds."
        },
        {
            key   : "seo.websub_hub_url",
            value : "https://pubsubhubbub.appspot.com/",
            type  : "string",
            desc  : "WebSub hub URL. Defaults to Google's free public hub. Operators with their own hub (or a regional alternative) can override."
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
