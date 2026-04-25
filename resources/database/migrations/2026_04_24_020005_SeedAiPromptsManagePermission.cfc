/**
 * Seed `ai.prompts.manage` permission.
 *
 * Gates /admin/ai-prompts. Granted to super_admin + admin only —
 * AI prompt edits affect the system message for every editor on the
 * site, so it sits behind the same authority as users.manage.
 */
component {

    variables.permissions = [
        { slug : "ai.prompts.manage", name : "Manage AI Prompts",
          description : "Edit the system prompts that bx-Blogger sends to the LLM for draft / review / image features." }
    ];

    variables.grants = {
        "ai.prompts.manage" : [ "super_admin", "admin" ]
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
