/**
 * Phase 2 Chunk 2.H — seed `posts.ai.assist`.
 *
 * Gates the Create-from-Idea + Review-and-Suggest editor buttons.
 * Per PLAN §10 matrix: granted to super_admin / admin / editor /
 * author; denied to contributor (their content is already gated by
 * editor review via A7, and AI-generated drafts would skip that
 * review layer if we let contributors publish straight through —
 * cleanest policy is to deny by default and let admins grant
 * per-user exceptions once the settings UI lands).
 *
 * Image-gen permission (`posts.ai.image_generate`) seeds separately
 * in Chunk 2.I — deliberate split because image costs are
 * 10-50× text costs and ops want independent revocation.
 */
component {

    variables.permissions = [
        { slug : "posts.ai.assist", name : "Use AI Authoring Assist",
          description : "Access Create-from-Idea + Review-and-Suggest in the editor" }
    ];

    variables.grants = {
        "posts.ai.assist" : [ "super_admin", "admin", "editor", "author" ]
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
