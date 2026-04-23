/**
 * Phase 6 Chunk 6.C — `notifications` table (B7).
 *
 * Per-user in-app notifications. The admin's bell-icon dropdown
 * reads from this table; a future email channel (6.D) + digest
 * job will also pull from it. DB is the source of truth — any
 * channel downstream is either a fan-out notification of a write
 * (via the `bxBlogger.notificationCreated` interception event)
 * or a periodic reader (the daily digest job).
 *
 * Row semantics:
 *   - `user_id` — target recipient. Nullable because future
 *     notifications may target a *role* (e.g., "all admins") via
 *     fan-out in NotificationService.notifyAllAdmins(); the fan-out
 *     writes one row per user, so leaving this nullable isn't for
 *     broadcasts — it's for "system-level" notifications that
 *     should appear to any admin who logs in (hasn't shipped yet).
 *   - `type` — stable slug like "post_published", "login_failed",
 *     "job_failed". Code never parses `title`/`body`; the `type`
 *     is the programmatic handle.
 *   - `severity` — info | warning | error. Drives icon + color in
 *     the bell-icon dropdown.
 *   - `link` — optional deep-link URL (usually `/admin/...`) that
 *     clicking the notification navigates to. Stored as-is; callers
 *     are responsible for building it.
 *   - `read_at` — null when unread; the bell's unread count is
 *     `COUNT(*) WHERE read_at IS NULL`.
 *
 * FK on `user_id` with CASCADE so purging a user also nukes their
 * notification history — matches the GDPR-delete path that
 * Phase 8 ships (`UserService.purge`).
 */
component {

    function up( schema, qb ) {
        schema.create( "notifications", function( table ) {
            table.bigIncrements( "id" );
            // users.id is `int unsigned` (not bigint) — match the source
            // column type exactly, otherwise MySQL rejects the FK.
            table.unsignedInteger( "user_id" ).nullable();
            table.string( "type", 60 );
            table.string( "title", 255 );
            table.text( "body" ).nullable();
            table.string( "link", 500 ).nullable();
            table.string( "severity", 20 ).default( "info" );
            table.timestamp( "read_at" ).nullable();
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "user_id" )
                 .references( "id" )
                 .onTable( "users" )
                 .onDelete( "CASCADE" );
            // Bell-dropdown query: `WHERE user_id = ? AND read_at IS NULL`
            // ordered by created_at desc — two-column index covers it.
            table.index( [ "user_id", "read_at" ] );
            table.index( "created_at" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "notifications" );
    }

}
