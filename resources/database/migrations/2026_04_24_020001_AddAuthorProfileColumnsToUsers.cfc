/**
 * Author-profile columns on `users` for the OG-image + public-author-page
 * feature set.
 *
 * Three logical groups:
 *
 *   Content
 *     bio_short   — one-line line-of-text used on author cards in post
 *                   headers, feed cards, etc. Short enough to never wrap.
 *     bio         — long-form markdown body rendered on the public author
 *                   page. Runs through the same pipeline as post bodies.
 *     author_slug — URL segment for /author/{slug}. Nullable because a
 *                   fresh install doesn't need one generated until the
 *                   first user opts into a public page; unique so two
 *                   users can't collide on the same URL.
 *
 *   Social profile URLs — stored as individual columns (not a JSON blob)
 *                         so validation / queries / migrations stay typed.
 *     website_url, twitter_url, linkedin_url, github_url, gitlab_url,
 *     mastodon_url, bluesky_url, facebook_url.
 *
 *   Profile photo (stored on the `media` cbfs disk under
 *   `profile_images/{user_id}/{uuid}.ext` so paths are namespaced per
 *   user and one user can never reach another's file from the disk API)
 *     profile_photo_path / _mime / _width / _height.
 *
 *   Preferences (all drive OG-image composition; three also govern
 *   what renders on the optional public author page)
 *     og_include_profile_photo        — default ON
 *     og_include_email                — default OFF (privacy)
 *     og_include_socials_and_url      — default ON; covers URL+QR and
 *                                       the social icon row
 *     public_author_page_enabled      — default OFF (opt-in)
 */
component {

    function up( schema, qb ) {
        schema.alter( "users", function( table ) {
            // Content
            table.addColumn( table.string( "bio_short", 255 ).nullable() );
            table.addColumn( table.text( "bio" ).nullable() );
            table.addColumn( table.string( "author_slug", 120 ).nullable() );

            // Social profile URLs
            table.addColumn( table.string( "website_url",  500 ).nullable() );
            table.addColumn( table.string( "twitter_url",  500 ).nullable() );
            table.addColumn( table.string( "linkedin_url", 500 ).nullable() );
            table.addColumn( table.string( "github_url",   500 ).nullable() );
            table.addColumn( table.string( "gitlab_url",   500 ).nullable() );
            table.addColumn( table.string( "mastodon_url", 500 ).nullable() );
            table.addColumn( table.string( "bluesky_url",  500 ).nullable() );
            table.addColumn( table.string( "facebook_url", 500 ).nullable() );

            // Profile photo
            table.addColumn( table.string( "profile_photo_path",  500 ).nullable() );
            table.addColumn( table.string( "profile_photo_mime",   60 ).nullable() );
            table.addColumn( table.unsignedSmallInteger( "profile_photo_width"  ).nullable() );
            table.addColumn( table.unsignedSmallInteger( "profile_photo_height" ).nullable() );

            // Preferences
            table.addColumn( table.boolean( "og_include_profile_photo"   ).default( 1 ) );
            table.addColumn( table.boolean( "og_include_email"           ).default( 0 ) );
            table.addColumn( table.boolean( "og_include_socials_and_url" ).default( 1 ) );
            table.addColumn( table.boolean( "public_author_page_enabled" ).default( 0 ) );
        } );

        // Unique index on author_slug in a separate ALTER — qb's
        // column-level .unique() on addColumn doesn't always fire on
        // MySQL 8.4 when the column is nullable. A named index makes
        // the constraint explicit and gives us a drop target in down().
        schema.alter( "users", function( table ) {
            table.unique( "author_slug", "uq_users_author_slug" );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "users", function( table ) {
            table.dropIndex( "uq_users_author_slug" );
        } );

        schema.alter( "users", function( table ) {
            table.dropColumn( "public_author_page_enabled" );
            table.dropColumn( "og_include_socials_and_url" );
            table.dropColumn( "og_include_email" );
            table.dropColumn( "og_include_profile_photo" );

            table.dropColumn( "profile_photo_height" );
            table.dropColumn( "profile_photo_width" );
            table.dropColumn( "profile_photo_mime" );
            table.dropColumn( "profile_photo_path" );

            table.dropColumn( "facebook_url" );
            table.dropColumn( "bluesky_url" );
            table.dropColumn( "mastodon_url" );
            table.dropColumn( "gitlab_url" );
            table.dropColumn( "github_url" );
            table.dropColumn( "linkedin_url" );
            table.dropColumn( "twitter_url" );
            table.dropColumn( "website_url" );

            table.dropColumn( "author_slug" );
            table.dropColumn( "bio" );
            table.dropColumn( "bio_short" );
        } );
    }

}
