/**
 * Phase 4 Chunk 4.A — `themes.manage` permission.
 *
 * Gates the themes.manager admin wire. Activating a theme mid-request
 * is a site-wide effect (everyone's next page load goes through the
 * new theme resolver), so the permission is granted to super_admin
 * and admin only — editors can manage content but not swap the site's
 * visual shell.
 *
 * Phase 4.D adds `themes.options` (per-theme settings) and Phase 4.E
 * adds `menus.manage`, each via their own seed migration so a Phase
 * X rollback leaves the right subset of roles in place.
 */
component {

    variables.permissions = [
        { slug : "themes.manage", name : "Manage themes",
          description : "Install / activate / remove themes; edit a theme's options." }
    ];

    variables.grants = {
        "themes.manage" : [ "super_admin", "admin" ]
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
