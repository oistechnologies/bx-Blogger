/**
 * Phase 8.C.1 — audit log permissions.
 *
 * Two-level split so a read-only audit reviewer (compliance,
 * ops) can inspect the log without also being able to bulk-
 * export it:
 *
 *   audit.view     — super_admin, admin
 *   audit.export   — super_admin only
 *
 * `audit.export` is narrower because a CSV dump of the audit
 * log is a privacy-sensitive document (contains ip_address +
 * user_agent on rows that haven't been GDPR-redacted yet); an
 * admin sees the rows in-UI but can't exfil the whole thing in
 * one click.
 */
component {

    variables.permissions = [
        { slug : "audit.view",
          name : "View audit log",
          description : "Read-only access to the audit log viewer." },
        { slug : "audit.export",
          name : "Export audit log",
          description : "Download the audit log (or a filtered slice) as CSV." }
    ];

    variables.grants = {
        "audit.view"   : [ "super_admin", "admin" ],
        "audit.export" : [ "super_admin" ]
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
