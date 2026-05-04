/**
 * SEO Phase 4 — seed `posts.ai.seo` permission + `ai.seo.enabled`
 * setting that gate the new SEO-AI editor buttons (Generate SEO
 * Title, Suggest 5 CTR Variants, Generate SEO Description, Generate
 * Alt Text).
 *
 * The permission is granted to every role that already has
 * `posts.ai.assist` (super_admin / admin / editor / author) so any
 * user who can use AI authoring today can also use AI SEO meta
 * generation. Operators can revoke per-role from /admin/Roles.
 *
 * `ai.seo.enabled` is a master switch alongside the existing
 * `ai.enabled` and `ai.image.enabled` Coldbox settings. Default ON
 * so the buttons surface immediately when an operator finishes
 * configuring AI; can be flipped OFF to disable SEO-AI without
 * disabling drafting.
 *
 * Skip-if-present so re-running this migration is safe.
 */
component {

    variables.permission = {
        slug        : "posts.ai.seo",
        name        : "Use AI SEO Meta Generation",
        description : "Access Generate SEO Title, Suggest CTR Variants, Generate SEO Description, and Generate Alt Text in the editor"
    };

    variables.parentPermSlug = "posts.ai.assist";

    variables.setting = {
        key   : "ai.seo.enabled",
        value : "true",
        type  : "bool",
        desc  : "Master switch for the SEO-AI editor buttons (Generate SEO Title, Description, Alt Text, CTR Variants). ANDs with ai.enabled."
    };

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );

        // 1. Insert the permission if missing. qb's .count() is the
        //    safe existence check (.first() returns an empty struct
        //    on no-match rather than null, so isNull() doesn't work).
        var permExists = qb.newQuery()
            .from( "permissions" )
            .where( "slug", variables.permission.slug )
            .count();
        if ( permExists == 0 ) {
            qb.newQuery().from( "permissions" ).insert( {
                "slug"        : variables.permission.slug,
                "name"        : variables.permission.name,
                "description" : variables.permission.description,
                "is_system"   : 1,
                "created_at"  : now,
                "updated_at"  : now
            } );
        }

        // 2. Resolve permission ids via .get() — accessed by lowercase
        //    keys like every other working seed migration does.
        var permIds = {};
        for ( var p in qb.newQuery().from( "permissions" ).get() ) {
            permIds[ p.slug ] = p.id;
        }
        if ( !structKeyExists( permIds, variables.permission.slug )
             || !structKeyExists( permIds, variables.parentPermSlug ) ) {
            return; // parent perm missing — nothing to mirror grants from
        }

        // 3. Grant the new permission to every role that has the
        //    parent permission. Skip role_ids already wired up.
        var parentRolePerms = qb.newQuery()
            .from( "role_permissions" )
            .where( "permission_id", permIds[ variables.parentPermSlug ] )
            .get();

        for ( var rp in parentRolePerms ) {
            var alreadyGranted = qb.newQuery()
                .from( "role_permissions" )
                .where( "permission_id", permIds[ variables.permission.slug ] )
                .where( "role_id",       rp.role_id )
                .count();
            if ( alreadyGranted > 0 ) continue;
            qb.newQuery().from( "role_permissions" ).insert( {
                "role_id"       : rp.role_id,
                "permission_id" : permIds[ variables.permission.slug ],
                "created_at"    : now
            } );
        }

        // 4. Seed the master toggle setting if missing.
        var settingExists = qb.newQuery()
            .from( "settings" )
            .where( "setting_key", variables.setting.key )
            .count();
        if ( settingExists == 0 ) {
            qb.newQuery().from( "settings" ).insert( {
                "setting_key"   : variables.setting.key,
                "setting_value" : variables.setting.value,
                "setting_type"  : variables.setting.type,
                "description"   : variables.setting.desc,
                "updated_at"    : now
            } );
        }
    }

    function down( schema, qb ) {
        var permIds = {};
        for ( var p in qb.newQuery().from( "permissions" ).get() ) {
            permIds[ p.slug ] = p.id;
        }
        if ( structKeyExists( permIds, variables.permission.slug ) ) {
            qb.newQuery().from( "role_permissions" ).where( "permission_id", permIds[ variables.permission.slug ] ).delete();
            qb.newQuery().from( "permissions"      ).where( "id",            permIds[ variables.permission.slug ] ).delete();
        }
        qb.newQuery().from( "settings" ).where( "setting_key", variables.setting.key ).delete();
    }

}
