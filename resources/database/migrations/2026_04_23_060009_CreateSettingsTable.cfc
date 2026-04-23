/**
 * Phase 6 Chunk 6.B-prep — `settings` table.
 *
 * Generic key/value store for app-level configuration that a site
 * operator can change at runtime (vs. build-time config in
 * config/Coldbox.bx). Pulled forward from Post-UX Addition #1
 * (System Settings admin area) as a dependency of the 6.C
 * NotificationService work — notifications need a "where do email
 * alerts go" setting, and building a second bespoke table just for
 * that would be wasteful.
 *
 * Key convention: dot-namespaced — `notifications.email_to`,
 * `site.name`, `site.tagline`, `site.default_og_image_id`, etc.
 * Flat table keeps the admin UI trivial (one form, group rows by
 * left-of-dot prefix).
 *
 * Typed values: `setting_type` is VARCHAR (not MySQL ENUM) so we
 * can add types later without a schema change. Current types:
 *   - string  — free text
 *   - int     — coerced via `int()` on read/write
 *   - bool    — stored as "true"/"false" strings
 *   - email   — string + `isValid("email", ...)` normalization
 * SettingService enforces the type on write; callers that hand
 * the service a mismatched value get a typed exception.
 *
 * Description column exists so the future admin UI (Post-UX #1)
 * can render a per-setting help text without a separate i18n file.
 * Populated by the seeder for seed-time settings, left empty for
 * runtime-added ones.
 */
component {

    function up( schema, qb ) {
        schema.create( "settings", function( table ) {
            table.string( "setting_key", 120 );
            table.text( "setting_value" ).nullable();
            table.string( "setting_type", 20 ).default( "string" );
            table.text( "description" ).nullable();
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.primaryKey( "setting_key" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "settings" );
    }

}
