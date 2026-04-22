/**
 * Phase 2 — seed content permissions per PLAN §10.
 *
 * Role → permission grants pulled from the matrix (columns: super_admin,
 * admin, editor, author, contributor, subscriber). AI-authoring and
 * image-gen permissions (`posts.ai.assist`, `posts.ai.image_generate`)
 * seed separately in Chunks 2.H and 2.I so their rollouts stay reversible
 * without touching this migration.
 *
 * `pages.*` collapses to a single `pages.manage` permission; pages ARE
 * posts (via `posts.post_type='page'`), so anything post-flow-specific
 * already shares the posts.* permissions. pages.manage gates the page-
 * specific hierarchy + menu_order editing that only admins/editors do.
 */
component {

    variables.permissions = [
        // Posts
        { slug: "posts.create",             name: "Create Posts",             description: "Create new posts/pages" },
        { slug: "posts.edit.own",           name: "Edit Own Posts",           description: "Edit posts you authored" },
        { slug: "posts.edit.others",        name: "Edit Others' Posts",      description: "Edit posts authored by anyone" },
        { slug: "posts.submit_for_review",  name: "Submit for Review",        description: "Flip draft → pending_review (A7)" },
        { slug: "posts.publish.own",        name: "Publish Own Posts",        description: "Publish posts you authored" },
        { slug: "posts.publish.others",     name: "Publish Others' Posts",   description: "Publish posts authored by anyone" },
        { slug: "posts.delete.own",         name: "Delete Own Posts",         description: "Soft-delete posts you authored" },
        { slug: "posts.delete.others",      name: "Delete Others' Posts",    description: "Soft-delete posts authored by anyone" },
        { slug: "posts.preview.share",      name: "Share Draft Previews",     description: "Generate B2 preview-link URLs" },
        { slug: "posts.html.unsafe",        name: "Allow Unsafe HTML",        description: "Skip cbantisamy strip on raw HTML in the editor" },
        // Pages (a post_type variant; this covers the page-specific ops)
        { slug: "pages.manage",             name: "Manage Pages",             description: "Create/edit/publish/delete pages" },
        // Taxonomy
        { slug: "categories.manage",        name: "Manage Categories",        description: "Create/edit/delete categories" },
        { slug: "tags.manage",              name: "Manage Tags",              description: "Create/edit/delete/merge tags" },
        // Media
        { slug: "media.upload",             name: "Upload Media",             description: "Add files to the media library" },
        { slug: "media.delete.others",      name: "Delete Others' Media",    description: "Delete media uploaded by anyone" }
    ];

    // Map: permission.slug → array of role.slug that should be granted it.
    variables.grants = {
        "posts.create":            [ "super_admin", "admin", "editor", "author", "contributor" ],
        "posts.edit.own":          [ "super_admin", "admin", "editor", "author", "contributor" ],
        "posts.edit.others":       [ "super_admin", "admin", "editor" ],
        "posts.submit_for_review": [ "super_admin", "admin", "editor", "author", "contributor" ],
        "posts.publish.own":       [ "super_admin", "admin", "editor", "author" ],
        "posts.publish.others":    [ "super_admin", "admin", "editor" ],
        "posts.delete.own":        [ "super_admin", "admin", "editor", "author" ],
        "posts.delete.others":     [ "super_admin", "admin", "editor" ],
        "posts.preview.share":     [ "super_admin", "admin", "editor", "author", "contributor" ],
        "posts.html.unsafe":       [ "super_admin", "admin" ],
        "pages.manage":            [ "super_admin", "admin", "editor" ],
        "categories.manage":       [ "super_admin", "admin", "editor" ],
        "tags.manage":             [ "super_admin", "admin", "editor", "author" ],
        "media.upload":            [ "super_admin", "admin", "editor", "author", "contributor" ],
        "media.delete.others":     [ "super_admin", "admin", "editor" ]
    };

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );

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

        var roleIds = {};
        for ( var r in qb.newQuery().from( "roles" ).get() ) {
            roleIds[ r.slug ] = r.id;
        }
        var permIds = {};
        for ( var p in qb.newQuery().from( "permissions" ).get() ) {
            permIds[ p.slug ] = p.id;
        }

        for ( var permSlug in variables.grants ) {
            if ( !structKeyExists( permIds, permSlug ) ) continue;
            for ( var roleSlug in variables.grants[ permSlug ] ) {
                if ( !structKeyExists( roleIds, roleSlug ) ) continue;
                qb.newQuery().from( "role_permissions" ).insert( {
                    "role_id":       roleIds[ roleSlug ],
                    "permission_id": permIds[ permSlug ],
                    "created_at":    now
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
