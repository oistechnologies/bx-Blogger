/**
 * AI Prompts admin-editable system prompts.
 *
 * Stores the system-role messages the app sends to the LLM for each
 * AI feature (draft_from_idea, review_post, image_generation). Seeded
 * by the next migration with the same text the app currently has
 * hardcoded — behavior is byte-identical out of the box. Admins can
 * later edit the body via /admin/ai-prompts and reset to the seeded
 * default at any time (default_text is preserved separately and is
 * never written by the admin UI).
 *
 * Security guardrails (the jailbreak-protection block in
 * AiAssistantService.bx) stay in code and are appended AFTER the
 * editable body — admins cannot remove them.
 */
component {

    function up( schema, qb ) {
        schema.create( "ai_prompts", function( table ) {
            table.bigIncrements( "id" );
            table.string( "slug", 64 ).unique();
            table.string( "name", 120 );
            table.text( "description" ).nullable();
            table.mediumText( "prompt_text" );
            table.mediumText( "default_text" );
            table.tinyInteger( "is_active" ).default( 1 );
            table.tinyInteger( "is_system" ).default( 1 );
            table.unsignedInteger( "updated_by" ).nullable();
            table.timestamp( "updated_at" ).default( "CURRENT_TIMESTAMP" );
            table.timestamp( "created_at" ).default( "CURRENT_TIMESTAMP" );

            table.foreignKey( "updated_by" )
                .references( "id" ).onTable( "users" )
                .onDelete( "SET NULL" );
        } );
    }

    function down( schema, qb ) {
        schema.drop( "ai_prompts" );
    }

}
