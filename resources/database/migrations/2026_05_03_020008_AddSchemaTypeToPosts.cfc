/**
 * SEO Phase 7 — schema.org type picker on posts.
 *
 *   schema_type
 *     Override of the default Article-class schema. NULL means
 *     "use the default" (BlogPosting / WebPage based on post_type).
 *     Allowed values are validated at the wire layer rather than
 *     a column constraint so we can add new types via prompts +
 *     code without a migration: Article, NewsArticle, BlogPosting,
 *     FAQPage, HowTo, Recipe, Product, VideoObject.
 *
 *   schema_data
 *     JSON payload holding type-specific fields:
 *
 *       FAQPage:    { items: [ { question, answer }, ... ] }
 *       HowTo:      { totalTime, steps: [ { name, text, image? }, ... ] }
 *       Product:    { sku, brand, price, priceCurrency, availability, rating? }
 *       VideoObject:{ contentUrl, embedUrl, duration, uploadDate, thumbnailUrl }
 *       NewsArticle:{ section, dateline, location? }
 *       Recipe:     { prepTime, cookTime, recipeYield, ingredients[], instructions[] }
 *
 *     Stored as TEXT (not native JSON column type) so the column
 *     stays portable across MySQL / Postgres / SQLite. SeoService
 *     parses on read.
 *
 * No backfill — every existing post is schema_type=NULL and renders
 * the same Article schema it always did.
 */
component {

    function up( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.addColumn(
                table.string( "schema_type", 40 ).nullable()
            );
            table.addColumn(
                table.text( "schema_data" ).nullable()
            );
        } );
    }

    function down( schema, qb ) {
        schema.alter( "posts", function( table ) {
            table.dropColumn( "schema_data" );
            table.dropColumn( "schema_type" );
        } );
    }

}
