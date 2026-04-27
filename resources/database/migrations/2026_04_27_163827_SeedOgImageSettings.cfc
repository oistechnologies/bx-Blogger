/**
 * Seed the `og.*` settings that drive the OG image generator.
 *
 * Each row is upserted via "skip if present" — running this on an
 * environment where an admin has already tuned a value via
 * /admin/settings/og-image leaves their value alone. Adding a new
 * key later is just a new migration with the same shape.
 *
 * Defaults match the constants in OgImageService.bx so a fresh
 * install looks identical to the pre-settings era; the dark navy
 * background + cyan highlight render is now the explicit default
 * rather than an implicit one.
 */
component {

    variables.seeds = [
        {
            key   : "og.qr_enabled",
            value : "true",
            type  : "bool",
            desc  : "Master switch for the QR code on generated OG images. ANDs with the per-author 'show socials/URL' preference."
        },
        {
            key   : "og.author_photo_enabled",
            value : "true",
            type  : "bool",
            desc  : "Master switch for the author photo on generated OG images. ANDs with the per-author 'show profile photo' preference."
        },
        {
            key   : "og.logo_media_id",
            value : "0",
            type  : "int",
            desc  : "Media row id of the logo shown top-left on generated OG images. 0 = use the bundled bx-Blogger default mark."
        },
        {
            key   : "og.color_background",
            value : "##1B1E2C",
            type  : "string",
            desc  : "Background fill color for generated OG images (hex)."
        },
        {
            key   : "og.color_highlight",
            value : "##00DBFF",
            type  : "string",
            desc  : "Highlight color: bottom accent bar and the 'by {author}' text (hex)."
        },
        {
            key   : "og.color_title",
            value : "##FFFFFF",
            type  : "string",
            desc  : "Title text color on generated OG images (hex)."
        },
        {
            key   : "og.color_synopsis",
            value : "##B0B6C8",
            type  : "string",
            desc  : "Synopsis / excerpt / email / URL text color on generated OG images (hex)."
        }
    ];

    function up( schema, qb ) {
        var now = dateTimeFormat( now(), "yyyy-mm-dd HH:nn:ss" );
        for ( var s in variables.seeds ) {
            var existing = qb.newQuery()
                .from( "settings" )
                .where( "setting_key", s.key )
                .count();
            if ( existing > 0 ) continue;
            qb.newQuery().from( "settings" ).insert( {
                "setting_key"   : s.key,
                "setting_value" : s.value,
                "setting_type"  : s.type,
                "description"   : s.desc,
                "updated_at"    : now
            } );
        }
    }

    function down( schema, qb ) {
        var keys = variables.seeds.map( function( s ) { return s.key; } );
        qb.newQuery()
            .from( "settings" )
            .whereIn( "setting_key", keys )
            .delete();
    }

}
