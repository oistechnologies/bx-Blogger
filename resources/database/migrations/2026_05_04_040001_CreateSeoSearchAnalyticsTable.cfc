/**
 * SEO Phase 14 — `seo_search_analytics` table.
 *
 * One row per (date, page_path, query) tuple from Google
 * Search Console's searchanalytics/query API. The daily sync
 * job appends yesterday's rows; the editor "Performance" tab
 * + dashboard scorecards aggregate from this table so live
 * page renders never call out to Google.
 *
 * `post_id` is nullable — pages outside the bx-Blogger post
 * surface (theme demos, /search, /admin/login leaks, etc.)
 * still get recorded but with NULL `post_id`. The editor tab
 * filters on post_id; the site-wide overview reads everything.
 *
 * UNIQUE(date, page_path, query) — the sync job UPSERTs based on
 * this key so a re-run for a particular date doesn't double-
 * count. `query` can be empty when a page_path row arrives
 * without dimension=query (rare, but defensive).
 *
 * `clicks` / `impressions` are unsigned int — ample for a
 * single day. `ctr` and `position` are float so we can store
 * GSC's native precision rather than rounding.
 *
 * Indexed on (post_id, date) for the editor performance tab
 * and on (date) for the dashboard 28-day rollup.
 */
component {

    function up( schema, qb ) {
        schema.create( "seo_search_analytics", function( table ) {
            table.bigIncrements( "id" );

            table.date( "date" );
            table.string( "page_path", 500 );
            table.string( "query", 255 ).default( "" );
            table.unsignedBigInteger( "post_id" ).nullable();

            table.unsignedInteger( "clicks" ).default( 0 );
            table.unsignedInteger( "impressions" ).default( 0 );
            table.float( "ctr" ).default( 0 );
            table.float( "position" ).default( 0 );

            table.timestamp( "fetched_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "post_id" )
                 .references( "id" )
                 .onTable( "posts" )
                 .onDelete( "SET NULL" );

            table.unique( [ "date", "page_path", "query" ], "uq_seo_search_analytics_dpq" );
            table.index( [ "post_id", "date" ], "idx_seo_search_analytics_post_date" );
            table.index( "date",                "idx_seo_search_analytics_date"      );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "seo_search_analytics" );
    }

}
