/**
 * SEO Phase 13 — `last_seo_review_at` column on `posts`.
 *
 * Tracks when an editor last marked the post as "reviewed for
 * freshness" via the SEO health dashboard's Stale content tab.
 *
 * Why this is distinct from `updated_at`:
 *   - `updated_at` flips on any column write (typo fix, taxonomy
 *     reshuffle, OG-image regen, status change). It's noisy.
 *   - `last_seo_review_at` is a deliberate "I read this whole
 *     post and confirmed it's still accurate" signal. The
 *     freshness service uses it for the staleness ladder
 *     (fresh / aging / stale / critical) so a post nudged once
 *     a quarter doesn't appear stale just because the post body
 *     hasn't been touched in 18 months.
 *
 * Nullable — existing posts have never been reviewed; the
 * dashboard treats NULL as "fall back to updated_at" so the
 * roll-forward isn't disruptive.
 */
component {

    function up( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.addColumn(
                table.timestamp( "last_seo_review_at" ).nullable()
            );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.dropColumn( "last_seo_review_at" );
        } );
    }

}
