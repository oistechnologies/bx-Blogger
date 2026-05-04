/**
 * SEO Phase 14 — seed GSC integration settings + permissions.
 *
 *   gsc.oauth_client_id      — OAuth 2.0 client id (operator-supplied).
 *   gsc.oauth_client_secret  — OAuth 2.0 client secret.
 *   gsc.property_url         — verified GSC property (e.g.
 *                              "https://example.com/" or
 *                              "sc-domain:example.com").
 *   gsc.refresh_token        — long-lived refresh token (set on
 *                              successful OAuth).
 *   gsc.access_token         — short-lived access token (refreshed
 *                              on demand from the refresh token).
 *   gsc.token_expires_at     — epoch seconds, drives refresh.
 *   gsc.last_sync_at         — diagnostic; bumped by the sync job.
 *   gsc.provider             — "live" (default) | "mock". The
 *                              mock variant lets dev environments
 *                              render the dashboard without a
 *                              real Google account.
 *
 *   seo.gsc.connect          — super_admin only; pastes secrets.
 *   seo.gsc.view             — editor + admin; reads the cached
 *                              search analytics from the editor
 *                              "Performance" tab + dashboard
 *                              scorecards.
 */
component {

    variables.settings = [
        { key : "gsc.oauth_client_id",     value : "",                                 type : "string" },
        { key : "gsc.oauth_client_secret", value : "",                                 type : "string" },
        { key : "gsc.property_url",        value : "",                                 type : "string" },
        { key : "gsc.refresh_token",       value : "",                                 type : "string" },
        { key : "gsc.access_token",        value : "",                                 type : "string" },
        { key : "gsc.token_expires_at",    value : "0",                                type : "int"    },
        { key : "gsc.last_sync_at",        value : "",                                 type : "string" },
        { key : "gsc.provider",            value : "live",                             type : "string" }
    ];

    variables.permissions = [
        { slug : "seo.gsc.connect",
          name : "Connect Google Search Console",
          description : "Paste OAuth credentials + initiate the GSC connection flow. Super-admin only because the credentials grant read access to all GSC properties on the operator's account." },
        { slug : "seo.gsc.view",
          name : "View Search Console data",
          description : "Read cached GSC search-analytics rows (per-post Performance tab + dashboard scorecards)." }
    ];

    variables.grants = {
        "seo.gsc.connect" : [ "super_admin" ],
        "seo.gsc.view"    : [ "super_admin", "admin", "editor" ]
    };

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );

        // Settings — skip-if-present so re-runs are safe.
        for ( var s in variables.settings ) {
            var existing = qb.newQuery().from( "settings" )
                .where( "setting_key", s.key )
                .count();
            if ( existing > 0 ) continue;
            qb.newQuery().from( "settings" ).insert( {
                "setting_key"   : s.key,
                "setting_value" : s.value,
                "setting_type"  : s.type,
                "description"   : "GSC integration: " & s.key,
                "updated_at"    : now
            } );
        }

        // Permissions — skip-if-present.
        var existingPerms = {};
        for ( var p in qb.newQuery().from( "permissions" ).get() ) existingPerms[ p.slug ] = p.id;

        for ( var perm in variables.permissions ) {
            if ( structKeyExists( existingPerms, perm.slug ) ) continue;
            qb.newQuery().from( "permissions" ).insert( {
                "slug"        : perm.slug,
                "name"        : perm.name,
                "description" : perm.description,
                "is_system"   : 1,
                "created_at"  : now,
                "updated_at"  : now
            } );
        }

        // Grants — re-read perm ids since we may have just inserted.
        var roleIds = {};
        for ( var r in qb.newQuery().from( "roles" ).get() ) roleIds[ r.slug ] = r.id;
        var permIds = {};
        for ( var p in qb.newQuery().from( "permissions" ).get() ) permIds[ p.slug ] = p.id;

        for ( var permSlug in variables.grants ) {
            if ( !structKeyExists( permIds, permSlug ) ) continue;
            var pid = permIds[ permSlug ];
            for ( var roleSlug in variables.grants[ permSlug ] ) {
                if ( !structKeyExists( roleIds, roleSlug ) ) continue;
                var rid = roleIds[ roleSlug ];
                var dupes = qb.newQuery().from( "role_permissions" )
                    .where( "role_id", rid )
                    .where( "permission_id", pid )
                    .count();
                if ( dupes > 0 ) continue;
                qb.newQuery().from( "role_permissions" ).insert( {
                    "role_id"       : rid,
                    "permission_id" : pid,
                    "created_at"    : now
                } );
            }
        }
    }

    function down( schema, qb ) {
        for ( var s in variables.settings ) {
            qb.newQuery().from( "settings" ).where( "setting_key", s.key ).delete();
        }
        for ( var perm in variables.permissions ) {
            var row = qb.newQuery().from( "permissions" ).where( "slug", perm.slug ).first();
            if ( !isNull( row ) && !( isStruct( row ) && structIsEmpty( row ) ) ) {
                qb.newQuery().from( "role_permissions" ).where( "permission_id", row.id ).delete();
                qb.newQuery().from( "permissions" ).where( "id", row.id ).delete();
            }
        }
    }

}
