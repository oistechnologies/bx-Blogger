/**
 * Phase 2 Chunk 2.H — `ai_usage` table.
 *
 * One row per AI request. The service aggregates by
 * `(user_id, year_month)` for monthly-budget enforcement; the raw rows
 * double as the audit trail (who asked, what action, how many tokens,
 * cost in USD-micros). `cost_usd_micro` stores cost × 1,000,000 as a
 * BIGINT — avoids fractional money arithmetic on hot paths.
 *
 * `action` is a varchar (enum-ish) so new actions — draft_from_idea,
 * review_post today; generate_image in Chunk 2.I — slot in without
 * another ALTER. A plain index on (user_id, year_month, action)
 * powers the per-user, per-month budget aggregate and the
 * Phase-8 audit UI's filters.
 */
component {

    function up( schema, qb ) {
        schema.create( "ai_usage", function( table ) {
            table.bigIncrements( "id" );
            table.unsignedInteger( "user_id" );
            table.char( "year_month", 6 );                      // "202604"
            table.string( "action", 32 );                       // "draft_from_idea", "review_post", "generate_image"
            table.integer( "prompt_tokens" ).unsigned().default( 0 );
            table.integer( "completion_tokens" ).unsigned().default( 0 );
            table.integer( "total_tokens" ).unsigned().default( 0 );
            table.bigInteger( "cost_usd_micro" ).default( 0 );  // cost × 1_000_000
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "user_id" ).references( "id" ).onTable( "users" );
            table.index( [ "user_id", "year_month" ], "idx_ai_usage_user_month" );
            table.index( [ "user_id", "year_month", "action" ], "idx_ai_usage_user_month_action" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "ai_usage" );
    }

}
