/**
 * Phase 4 Chunk 4.E — `menus.manage` permission.
 *
 * Gates the menus.manager admin wire. Menus are a site-wide
 * navigation concern, not a content one — granted to super_admin and
 * admin only. Editors manage posts + categories; they don't
 * restructure the nav.
 */
component {

    variables.permissions = [
        { slug : "menus.manage", name : "Manage menus",
          description : "Create, edit, and reorder navigation menus for each theme location." }
    ];

    variables.grants = {
        "menus.manage" : [ "super_admin", "admin" ]
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
