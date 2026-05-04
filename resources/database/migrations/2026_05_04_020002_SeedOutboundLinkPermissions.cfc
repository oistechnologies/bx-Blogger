/**
 * SEO Phase 12 — permissions for the outbound-link health checker.
 *
 *   seo.outbound_links.view   — read-only access to the broken-link
 *                               report + the editor badge. Editors+
 *                               so authors see when their own posts
 *                               carry dead links.
 *   seo.outbound_links.audit  — trigger an on-demand audit + per-row
 *                               re-check. Admin-only because audits
 *                               make outbound HTTP traffic.
 *
 * Skip-if-present so re-runs are safe.
 */
component {

    variables.permissions = [
        { slug : "seo.outbound_links.view",
          name : "View outbound link health",
          description : "Read the broken-outbound-links report and the per-post badge." },
        { slug : "seo.outbound_links.audit",
          name : "Run outbound link audits",
          description : "Trigger on-demand site-wide or per-post outbound link audits." }
    ];

    variables.grants = {
        "seo.outbound_links.view"  : [ "super_admin", "admin", "editor" ],
        "seo.outbound_links.audit" : [ "super_admin", "admin" ]
    };

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );

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
        for ( var perm in variables.permissions ) {
            var row = qb.newQuery().from( "permissions" ).where( "slug", perm.slug ).first();
            if ( !isNull( row ) && !( isStruct( row ) && structIsEmpty( row ) ) ) {
                qb.newQuery().from( "role_permissions" ).where( "permission_id", row.id ).delete();
                qb.newQuery().from( "permissions" ).where( "id", row.id ).delete();
            }
        }
    }

}
