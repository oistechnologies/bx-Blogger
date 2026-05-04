/**
 * Seed the `org.*` settings consumed by SeoService's
 * buildOrganizationJsonLd() (SEO Phase 3).
 *
 *   org.legal_name        — Organization "name" in JSON-LD; falls back to site.title when blank
 *   org.logo_media_id     — Media row id of the logo (0 = no logo node in JSON-LD)
 *   org.contact_email     — Used for Organization.contactPoint when set
 *   org.same_as           — JSON-encoded array of social profile URLs for sameAs[]
 *
 * Address fields are intentionally not seeded in this round —
 * they're a schema.org PostalAddress sub-shape that few blogs need
 * and adding them later via another migration is trivial.
 *
 * Each row is upserted via "skip if present" so admin-set values
 * survive re-running the migration.
 */
component {

    variables.seeds = [
        {
            key   : "org.legal_name",
            value : "",
            type  : "string",
            desc  : "Organization legal / display name. Drives Organization JSON-LD 'name'. Falls back to site.title when blank."
        },
        {
            key   : "org.logo_media_id",
            value : "0",
            type  : "int",
            desc  : "Media row id of the Organization logo. 0 = no logo emitted in JSON-LD."
        },
        {
            key   : "org.contact_email",
            value : "",
            type  : "string",
            desc  : "Organization contact email. Drives Organization.contactPoint when set. Stored as string so blank is a valid 'unset' state (SettingService.email rejects blank)."
        },
        {
            key   : "org.same_as",
            value : "[]",
            type  : "string",
            desc  : "JSON-encoded array of social profile URLs for Organization.sameAs[] (LinkedIn, Twitter, Facebook, etc)."
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
