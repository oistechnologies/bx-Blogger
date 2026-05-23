/**
 * `snippets.manage` permission for the Snippets admin CRUD.
 *
 * Granted to super_admin + admin only — snippet content is rendered
 * RAW on every public page (no HTML escaping), so this is functionally
 * "edit anything that ends up in the live page chrome". Editor and
 * author roles deliberately don't get it.
 *
 * Skip-if-present so re-runs are safe.
 */
component {

    variables.permissions = [
        { slug : "snippets.manage",
          name : "Manage code snippets",
          description : "Create / edit / delete HTML / JS / CSS snippets injected on public pages." }
    ];

    variables.grants = {
        "snippets.manage" : [ "super_admin", "admin" ]
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
