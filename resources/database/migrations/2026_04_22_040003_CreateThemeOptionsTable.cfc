/**
 * Phase 4 Chunk 4.D — `theme_options` table.
 *
 * Per-theme key/value store. Admins override a theme's manifest
 * `options[]` defaults from the Theme Options admin form; the
 * overridden values land here scoped by `theme_slug`, so switching
 * themes back and forth keeps each theme's last-saved configuration.
 *
 * Values are stored as JSON strings in a TEXT column — keeps the
 * schema generic across option types (color / int / bool / string /
 * textarea) without needing per-type columns. ThemeOptionsService
 * serializes on write and deserializes on read.
 *
 * CASCADE on theme delete is deliberate: if an admin removes a
 * non-system theme via the themes.manager wire, its options rows go
 * with it. Since the `themes` table uses `slug` as the user-facing
 * identity (not the BIGINT id), we FK on slug — MySQL allows FKs
 * against a column that's indexed + unique, and `themes.slug` already
 * has a unique index from the 3.A migration.
 *
 * Composite PK on (theme_slug, option_key) prevents duplicate values
 * for the same option from coexisting; setOption() writes via
 * insert-or-update keyed by that PK.
 */
component {

    function up( schema, qb ) {
        schema.create( "theme_options", function( table ) {
            table.string( "theme_slug", 120 );
            table.string( "option_key", 120 );
            // TEXT covers everything up through the plan's `textarea`
            // type; JSON-encoded regardless of the declared type so
            // `true` and `"true"` don't round-trip the same.
            table.text( "option_value" ).nullable();
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.primaryKey( [ "theme_slug", "option_key" ] );
            table.foreignKey( "theme_slug" )
                 .references( "slug" )
                 .onTable( "themes" )
                 .onDelete( "CASCADE" );
            table.index( "theme_slug" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "theme_options" );
    }

}
