/**
 * Phase 1 — seed the six default roles, Phase-1 permissions, and the
 * role→permission matrix from PLAN §10.
 *
 * Idempotent-ish: on up() we insert. on down() we delete by slug for roles
 * and permissions, and delete all role_permissions rows (CASCADE would also
 * handle this when the roles/permissions tables are dropped).
 *
 * ONLY Phase-1-relevant permissions are seeded here. Later phases add
 * their own permissions via their own migrations (e.g., Phase 2 adds
 * posts.* permissions in its own seed).
 */
component {

    variables.roles = [
        { slug: "super_admin",  name: "Super Admin",  description: "Unrestricted — system operations + GDPR purge" },
        { slug: "admin",        name: "Admin",        description: "Full admin access excluding system.admin" },
        { slug: "editor",       name: "Editor",       description: "Publishes own + others' content; manages categories, tags, users up to author" },
        { slug: "author",       name: "Author",       description: "Publishes own content" },
        { slug: "contributor",  name: "Contributor",  description: "Drafts own content; submits for editor review" },
        { slug: "subscriber",   name: "Subscriber",   description: "Reader account — read-only public site" }
    ];

    // Phase-1 permissions ONLY. posts.* / media.* / themes.* etc. seed
    // in their respective feature phases.
    variables.permissions = [
        // Self profile (B6)
        { slug: "users.profile.self",  name: "Manage Own Profile",  description: "View/update own profile" },
        // User admin
        { slug: "users.list",          name: "List Users",           description: "View user list" },
        { slug: "users.create",        name: "Create Users",         description: "Invite new users" },
        { slug: "users.edit",          name: "Edit Users",           description: "Edit other users' profiles" },
        { slug: "users.deactivate",    name: "Deactivate Users",     description: "Flip is_active off" },
        { slug: "users.export_data",   name: "Export User Data",     description: "GDPR export (B11 — Phase 8)" },
        { slug: "users.purge",         name: "Purge Users",          description: "GDPR right-to-be-forgotten (B11 — Phase 8)" },
        // Roles + permissions management
        { slug: "roles.manage",        name: "Manage Roles",         description: "Create/edit/delete roles + assignments" },
        // System
        { slug: "system.admin",        name: "System Admin",         description: "Dangerous ops — cache wipe, recompile, schema reset" },
        { slug: "system.health",       name: "System Health",        description: "Access /__health/full diagnostic endpoint (Phase 10 B24)" },
        // Settings
        { slug: "settings.manage",     name: "Manage Settings",      description: "Edit app settings (Phase 1+)" }
    ];

    // role_slug → array of permission_slug
    variables.assignments = {
        "super_admin":  [ "users.profile.self", "users.list", "users.create", "users.edit", "users.deactivate", "users.export_data", "users.purge", "roles.manage", "system.admin", "system.health", "settings.manage" ],
        "admin":        [ "users.profile.self", "users.list", "users.create", "users.edit", "users.deactivate", "users.export_data",                "roles.manage",                  "system.health", "settings.manage" ],
        "editor":       [ "users.profile.self", "users.list", "users.create", "users.edit" ],
        "author":       [ "users.profile.self" ],
        "contributor":  [ "users.profile.self" ],
        "subscriber":   [ "users.profile.self" ]
    };

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );

        // Insert roles
        for ( var role in variables.roles ) {
            qb.newQuery().from( "roles" ).insert( {
                "slug":        role.slug,
                "name":        role.name,
                "description": role.description,
                "is_system":   1,
                "created_at":  now,
                "updated_at":  now
            } );
        }

        // Insert permissions
        for ( var perm in variables.permissions ) {
            qb.newQuery().from( "permissions" ).insert( {
                "slug":        perm.slug,
                "name":        perm.name,
                "description": perm.description,
                "is_system":   1,
                "created_at":  now,
                "updated_at":  now
            } );
        }

        // Build role_permissions using a slug-to-id lookup
        var roleIds = {};
        for ( var r in qb.newQuery().from( "roles" ).get() ) {
            roleIds[ r.slug ] = r.id;
        }
        var permIds = {};
        for ( var p in qb.newQuery().from( "permissions" ).get() ) {
            permIds[ p.slug ] = p.id;
        }

        for ( var roleSlug in variables.assignments ) {
            var roleId = roleIds[ roleSlug ];
            for ( var permSlug in variables.assignments[ roleSlug ] ) {
                if ( !structKeyExists( permIds, permSlug ) ) continue;
                qb.newQuery().from( "role_permissions" ).insert( {
                    "role_id":       roleId,
                    "permission_id": permIds[ permSlug ],
                    "created_at":    now
                } );
            }
        }
    }

    function down( schema, qb ) {
        // CASCADE on the role/permission FK would clean role_permissions,
        // but on a bare `migrate down` (reverse this migration only) the
        // tables persist — so we delete rows explicitly.
        qb.newQuery().from( "role_permissions" ).delete();

        for ( var role in variables.roles ) {
            qb.newQuery().from( "roles" ).where( "slug", role.slug ).delete();
        }
        for ( var perm in variables.permissions ) {
            qb.newQuery().from( "permissions" ).where( "slug", perm.slug ).delete();
        }
    }

}
