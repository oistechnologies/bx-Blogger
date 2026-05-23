/**
 * Phase 15 — `analytics_daily` table.
 *
 * One row per (date, page_path) tuple from the Google Analytics
 * Data API. Site-wide rows use page_path='' and post_id=NULL; per-
 * page rows carry the GA-reported pagePath and post_id resolved
 * via the same regex GscService.resolvePostId() uses.
 *
 * The daily sync job batched-pulls yesterday's site-wide +
 * per-page aggregates in one batchRunReports call and upserts
 * into this table. Editor "Analytics" tab + dashboard snapshot
 * + report pages aggregate from here so live page renders never
 * call out to Google for cached metrics.
 *
 * UNIQUE(date, page_path) — the sync job UPSERTs based on this
 * key so a re-run for a particular date doesn't double-count.
 *
 * `screen_page_views` / `active_users` / etc. are unsigned int
 * for a single day. `engagement_rate` / `bounce_rate` / etc. are
 * float to preserve GA's native precision.
 *
 * Indexed on (post_id, date) for the per-post tab and on (date)
 * for the dashboard rollups.
 */
component {

    function up( schema, qb ) {
        schema.create( "analytics_daily", function( table ) {
            table.bigIncrements( "id" );

            table.date( "date" );
            table.string( "page_path", 500 ).default( "" );
            table.unsignedBigInteger( "post_id" ).nullable();

            table.unsignedInteger( "screen_page_views"     ).default( 0 );
            table.unsignedInteger( "active_users"          ).default( 0 );
            table.unsignedInteger( "new_users"             ).default( 0 );
            table.unsignedInteger( "sessions"              ).default( 0 );
            table.unsignedInteger( "engaged_sessions"      ).default( 0 );
            // DECIMAL preserves fractional precision; qb's .float() emits
            // FLOAT(10,0) which truncates decimals to integers. GA's
            // engagement/bounce rates are 0.0000-1.0000 and the duration
            // is fractional seconds — both unusable as integers.
            table.decimal       ( "avg_session_duration", 10, 2 ).default( 0 );
            table.decimal       ( "engagement_rate",       5, 4 ).default( 0 );
            table.decimal       ( "bounce_rate",           5, 4 ).default( 0 );
            table.unsignedInteger( "event_count"           ).default( 0 );
            table.unsignedInteger( "key_events"            ).default( 0 );

            table.timestamp( "fetched_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "post_id" )
                 .references( "id" )
                 .onTable( "posts" )
                 .onDelete( "SET NULL" );

            table.unique( [ "date", "page_path" ], "uq_analytics_daily_dp"      );
            table.index ( [ "post_id", "date" ],   "idx_analytics_daily_post_date" );
            table.index ( "date",                  "idx_analytics_daily_date"      );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "analytics_daily" );
    }

}
