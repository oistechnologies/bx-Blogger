/**
 * bx-Blogger — B2Provider
 *
 * cbfs disk provider that targets Backblaze B2's S3-compatible
 * endpoint. Identical to cbfs's stock S3Provider except it swaps
 * the underlying s3sdk client for our PatchedAmazonS3 subclass,
 * which fixes the path-style URL builder for non-AWS domains.
 *
 * Why a custom provider rather than patching s3sdk in place
 * ---------------------------------------------------------
 * The previous workaround patched s3sdk's source on container boot
 * via a perl one-liner in docker-entrypoint.sh. Brittle: if Ortus
 * reformats AmazonS3.cfc the regex stops matching, the patch
 * silently no-ops, and uploads break with 403 AccessDenied.
 * A subclass keeps the fix entirely inside the project and survives
 * any non-API-breaking change in s3sdk.
 *
 * Configuration
 * -------------
 * Register against any cbfs disk that targets B2 by setting:
 *
 *     "provider" : "models.cbfs.B2Provider"
 *
 * (Or the WireBox alias B2Provider if registered.) Properties are
 * the same as cbfs's S3Provider — accessKey, secretKey, awsDomain,
 * awsRegion, defaultBucketName, etc. See config/Coldbox.bx for the
 * media + backups disk wiring.
 *
 * Activation rule
 * ---------------
 * The patched client is only swapped in when both:
 *   - urlStyle == "path"
 *   - awsDomain does NOT contain "amazonaws.com"
 *
 * Outside those conditions the parent's stock client is left in
 * place because the bug doesn't apply. This means the same provider
 * can be pointed at AWS or B2 without code changes, and the cost
 * of the override is zero on AWS.
 *
 * @extends cbfs.models.providers.S3Provider
 */
component extends="cbfs.models.providers.S3Provider" {

    /**
     * Run the parent's startup, then conditionally replace the s3
     * client with our patched subclass. The parent constructs an
     * AmazonS3 instance via `createObject("component","s3sdk.models.AmazonS3")`
     * during its own startup; we swap our subclass in afterwards so
     * we don't have to duplicate the parent's param-defaults block.
     *
     * The replacement is safe because cbfs reads `variables.s3` for
     * every operation (put / get / delete / list / etc.) and the
     * patched class is fully ABI-compatible with the parent — same
     * methods, same return shapes, just a corrected URL builder.
     */
    public any function startup( required string name, struct properties = {} ) {
        super.startup( argumentCollection = arguments );

        var awsDomain = arguments.properties.awsDomain ?: "amazonaws.com";
        var urlStyle  = arguments.properties.urlStyle  ?: "path";

        if ( urlStyle == "path" && !( awsDomain contains "amazonaws.com" ) ) {
            try {
                variables.s3 = createObject( "component", "models.cbfs.PatchedAmazonS3" )
                    .init( argumentCollection = arguments.properties );
                variables.wirebox.autowire( variables.s3 );
            }
            catch ( any e ) {
                throw(
                    type    = "bxBlogger.B2Provider.ConfigurationException",
                    message = "B2Provider failed to swap in PatchedAmazonS3: " & e.message
                );
            }
        }

        return this;
    }

}
