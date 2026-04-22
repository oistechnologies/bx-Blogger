/**
 * Phase 4 Chunk 4.E — `menus` + `menu_items` tables.
 *
 * One menu per `(theme_slug, location)` pair. Each theme's manifest
 * declares which `location` keys it supports (usually `header` and
 * `footer`); the admin can populate any of them independently. Items
 * are a classic self-referential tree with a `parent_id` pointer and
 * a `sort_order` within each parent for reordering.
 *
 * Schema choices:
 *   - `menus.uq_menu_location` guarantees exactly one menu per
 *     (theme_slug, location) pair — if an admin tries to create a
 *     duplicate, the service returns the existing row instead of
 *     double-inserting.
 *   - `menu_items.url` is a plain string for Phase 4 (custom URLs
 *     only). Post / category / tag references join through a `type` +
 *     `object_id` pair in a later chunk, which keeps the menu intact
 *     when the linked content's slug changes.
 *   - `link_target` is nullable; empty treats as `_self`.
 *   - ON DELETE CASCADE from `menus` -> `menu_items` -> (self)
 *     means deleting a menu sweeps the whole tree; removing a
 *     parent item cascades down its subtree.
 */
component {

    function up( schema, qb ) {
        schema.create( "menus", function( table ) {
            table.bigIncrements( "id" );
            table.string( "theme_slug", 120 );
            table.string( "location",   60 );
            table.string( "name",       120 );
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.unique( [ "theme_slug", "location" ], "uq_menu_location" );
            table.foreignKey( "theme_slug" )
                 .references( "slug" )
                 .onTable( "themes" )
                 .onDelete( "CASCADE" );
            table.index( "theme_slug" );
        } );

        schema.create( "menu_items", function( table ) {
            table.bigIncrements( "id" );
            table.unsignedBigInteger( "menu_id" );
            table.unsignedBigInteger( "parent_id" ).nullable();
            table.integer( "sort_order" ).default( 0 );
            table.string( "label", 200 );
            table.string( "url", 500 );
            table.string( "link_target", 20 ).nullable();   // empty = _self; "_blank" for new-tab
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "menu_id"   ).references( "id" ).onTable( "menus"      ).onDelete( "CASCADE" );
            table.foreignKey( "parent_id" ).references( "id" ).onTable( "menu_items" ).onDelete( "CASCADE" );
            table.index( "menu_id" );
            table.index( "parent_id" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "menu_items" );
        schema.drop( "menus" );
    }

}
