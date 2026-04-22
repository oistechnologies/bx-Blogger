/**
 * Phase 2 Chunk 2.I — seed `posts.ai.image_generate`.
 *
 * Separate permission from `posts.ai.assist` deliberately: image-gen
 * costs per call are 10–50× text costs, so ops often want to revoke
 * image-gen independently while leaving text AI active. Default
 * grants: super_admin / admin / editor / author (same as text AI);
 * contributor denied (matches §10 matrix).
 */
component {

    variables.permissions = [
        { slug : "posts.ai.image_generate", name : "Generate AI Images",
          description : "Access the Generate Image modal + Featured Image AI button in the editor" }
    ];

    variables.grants = {
        "posts.ai.image_generate" : [ "super_admin", "admin", "editor", "author" ]
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
            if ( !isNull( row ) ) {
                qb.newQuery().from( "role_permissions" ).where( "permission_id", row.id ).delete();
                qb.newQuery().from( "permissions" ).where( "id", row.id ).delete();
            }
        }
    }

}
