/**
 * Phase 7.G — permissions for the Redirects + Broken Links admin.
 *
 * Per PLAN §12 permissions matrix:
 *   redirects.manage    — super_admin, admin
 *   broken_links.view   — super_admin, admin, editor
 *
 * `redirects.manage` is the write permission — today only used to
 * gate the "Add Redirect" button on the broken-links report
 * (Phase 7.G); the Phase-8 Redirects Manager UI will use it for
 * the full CRUD surface. Editors intentionally can't create
 * redirects (a bad redirect is site-wide; keep the write edge
 * narrow).
 *
 * `broken_links.view` is read-only and expands to editors so
 * non-admin content folks can see which of their legacy URLs
 * are still getting hit and raise it with an admin who holds
 * `redirects.manage`.
 */
component {

    variables.permissions = [
        { slug : "redirects.manage",
          name : "Manage redirects",
          description : "Create / edit / delete URL redirects (7.G + Phase 8 manager)." },
        { slug : "broken_links.view",
          name : "View broken links report",
          description : "Read-only access to the 404 report. Promotion to a redirect still needs redirects.manage." }
    ];

    variables.grants = {
        "redirects.manage"  : [ "super_admin", "admin" ],
        "broken_links.view" : [ "super_admin", "admin", "editor" ]
    };

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        for ( var perm in variables.permissions ) {
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
            for ( var roleSlug in variables.grants[ permSlug ] ) {
                if ( !structKeyExists( roleIds, roleSlug ) ) continue;
                qb.newQuery().from( "role_permissions" ).insert( {
                    "role_id"       : roleIds[ roleSlug ],
                    "permission_id" : permIds[ permSlug ],
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
