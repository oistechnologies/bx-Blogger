/**
 * Phase 15 — seed Google Analytics integration settings + permissions.
 *
 *   ga.oauth_client_id        — OAuth 2.0 client id (operator-supplied).
 *   ga.oauth_client_secret    — OAuth 2.0 client secret.
 *   ga.property_id            — numeric GA4 property id, e.g. "123456789".
 *                               NOT the G-XXXX measurement id.
 *   ga.measurement_id         — G-XXXXXXXX for gtag.js auto-emission.
 *   ga.refresh_token          — long-lived refresh token (set on
 *                               successful OAuth).
 *   ga.access_token           — short-lived access token (refreshed
 *                               on demand from the refresh token).
 *   ga.token_expires_at       — epoch seconds, drives refresh.
 *   ga.last_sync_at           — diagnostic; bumped by the sync job.
 *   ga.provider               — "live" (default) | "mock". Mock lets
 *                               dev environments render the dashboard
 *                               without a real Google account.
 *   ga.emit_gtag              — bool; auto-emit gtag.js on public site
 *                               when measurement_id is set. Default true.
 *   ga.connected_account_email — display-only; which Google account
 *                                owns the connection.
 *   ga.connected_at           — ISO timestamp of successful connect.
 *   ga.consent_mode           — "none" (default) | "basic_eu" | "strict";
 *                               controls Consent Mode v2 stub in gtag.
 *
 *   ga.connect                — super_admin only; pastes secrets.
 *   ga.view                   — editor + admin; reads reports + dashboard.
 */
component {

    variables.settings = [
        { key : "ga.oauth_client_id",         value : "",       type : "string" },
        { key : "ga.oauth_client_secret",     value : "",       type : "string" },
        { key : "ga.property_id",             value : "",       type : "string" },
        { key : "ga.measurement_id",          value : "",       type : "string" },
        { key : "ga.refresh_token",           value : "",       type : "string" },
        { key : "ga.access_token",            value : "",       type : "string" },
        { key : "ga.token_expires_at",        value : "0",      type : "int"    },
        { key : "ga.last_sync_at",            value : "",       type : "string" },
        { key : "ga.provider",                value : "live",   type : "string" },
        { key : "ga.emit_gtag",               value : "true",   type : "bool"   },
        { key : "ga.connected_account_email", value : "",       type : "string" },
        { key : "ga.connected_at",            value : "",       type : "string" },
        { key : "ga.consent_mode",            value : "none",   type : "string" }
    ];

    variables.permissions = [
        { slug : "ga.connect",
          name : "Connect Google Analytics",
          description : "Paste OAuth credentials + initiate the GA connection flow. Super-admin only because the credentials grant read access to all GA properties on the operator's account." },
        { slug : "ga.view",
          name : "View Google Analytics data",
          description : "Read GA reports (dashboard snapshot, per-post Analytics tab, full report pages)." }
    ];

    variables.grants = {
        "ga.connect" : [ "super_admin" ],
        "ga.view"    : [ "super_admin", "admin", "editor" ]
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
                "description"   : "GA integration: " & s.key,
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
