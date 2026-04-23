/**
 * Phase 8.C.1 — `audit_log` table.
 *
 * General-purpose event log for the admin audit viewer.
 * Complements the existing `login_audit` (which stays as the
 * specific surface for login/logout/failed-login events with
 * their `fail_reason` field); `audit_log` captures everything
 * else the admin might need a history of — post publishes,
 * trashes, restores, redirect edits, user role changes, setting
 * edits, etc.
 *
 * Column notes:
 *   - `user_id` nullable because system-triggered events (cron
 *     jobs, scheduled digests) don't have an acting user.
 *   - `action` is a dot-namespaced slug ("post.publish",
 *     "redirect.delete", "user.deactivate"). Grep-able.
 *   - `entity_type` + `entity_id` scope the event to its target
 *     row (post 42, redirect 7, etc.) so "show me everything
 *     that happened to post 42" is a single indexed range scan.
 *   - `metadata` is JSON — free-form context (old/new values,
 *     affected slug, etc.). Schema by convention, not DB.
 *   - `ip_address` + `user_agent` are captured for audit-trail
 *     integrity + Phase-10 B15 trusted-proxy IP extraction; the
 *     Phase-8.D GDPR purge path will redact these for a
 *     right-to-be-forgotten user without nuking the whole row
 *     (otherwise we'd lose the "some admin did X to this
 *     content" trail that compliance still needs).
 *
 * Indexes:
 *   - `created_at` DESC — default list order
 *   - `(user_id, created_at)` — "show me this user's actions"
 *   - `(entity_type, entity_id, created_at)` — "show me this
 *     object's history"
 *   - `action` — filter by action kind
 */
component {

    function up( schema, qb ) {
        schema.create( "audit_log", function( table ) {
            table.bigIncrements( "id" );
            // users.id is `int unsigned` — match exactly.
            table.unsignedInteger( "user_id" ).nullable();
            table.string( "action", 60 );
            table.string( "entity_type", 40 ).nullable();
            table.unsignedBigInteger( "entity_id" ).nullable();
            table.longText( "metadata" ).nullable();
            table.string( "ip_address", 45 ).nullable();
            table.string( "user_agent", 512 ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "user_id" )
                 .references( "id" )
                 .onTable( "users" )
                 .onDelete( "SET NULL" );

            table.index( "created_at",                                    "idx_audit_created_at"   );
            table.index( [ "user_id",      "created_at" ],                "idx_audit_user_time"    );
            table.index( [ "entity_type",  "entity_id",  "created_at" ], "idx_audit_entity_time"  );
            table.index( "action",                                        "idx_audit_action"       );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "audit_log" );
    }

}
