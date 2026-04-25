/**
 * bx-Blogger — PatchedAmazonS3
 *
 * Subclass of s3sdk's AmazonS3 that fixes the path-style URL builder
 * for Backblaze B2 (and any other non-AWS endpoint that already
 * embeds the region in its hostname).
 *
 * Bug being patched
 * -----------------
 * `s3sdk.models.AmazonS3.buildUrlEndpoint( bucketName )` always
 * appends `awsRegion` before `awsDomain` when `urlStyle == "path"`,
 * regardless of whether the domain is AWS:
 *
 *     hostnameComponents.append( variables.awsRegion );
 *     hostnameComponents.append( variables.awsDomain );
 *
 * For B2 with awsDomain = "s3.us-west-004.backblazeb2.com" and
 * awsRegion = "us-west-004" this produces
 * "us-west-004.s3.us-west-004.backblazeb2.com" — region twice. B2
 * returns 403 AccessDenied for every request to that hostname.
 *
 * Why a subclass works where on-instance overrides don't
 * --------------------------------------------------------
 * AmazonS3 calls `buildUrlEndpoint( bucketName )` internally from
 * putObject / getObject / a handful of other entry points. Those
 * are unqualified calls (no `this.` prefix) and resolve through
 * the component's `variables` scope, bypassing any closure we
 * assign to `this.buildUrlEndpoint`. Standard CFML/BoxLang virtual
 * dispatch DOES pick up subclass overrides for unqualified calls,
 * so this subclass intercepts every internal call site uniformly.
 *
 * Scope of the override
 * ---------------------
 * Only the path-style + non-AWS branch is patched. AWS itself
 * (amazonaws.com) and virtual-style URLs defer to the parent's
 * implementation — those code paths weren't broken.
 *
 * @extends s3sdk.models.AmazonS3
 *
 * NOTE: This file is .cfc rather than .bx because s3sdk's AmazonS3
 * is itself a .cfc and the BoxLang BX/CFC inheritance model needs
 * the child to declare with the same `component` keyword the parent
 * uses. A .bx file with `class extends="s3sdk.models.AmazonS3"`
 * fails at parse time because BoxLang treats `extends` differently
 * than legacy CFML when crossing the .bx/.cfc boundary.
 */
component extends="s3sdk.models.AmazonS3" {

	/**
	 * Override the URL endpoint builder. For path-style URLs against
	 * a non-AWS domain, use `awsDomain` verbatim — the operator-
	 * supplied endpoint already includes the region, no prefix needed.
	 *
	 * For everything else (AWS, virtual-style) defer to the parent.
	 *
	 * @bucketName  Optional. Honoured by the parent for virtual-style
	 *              AWS URLs; ignored on the patched path because
	 *              path-style puts the bucket in the URL path, not
	 *              the hostname.
	 */
	public any function buildUrlEndpoint( string bucketName ) {
		var awsDomain = variables.awsDomain    ?: "";
		var isAws     = awsDomain contains "amazonaws.com";
		var isPath    = ( variables.urlStyle ?: "" ) == "path";

		if ( isPath && !isAws ) {
			var protocol                  = ( variables.ssl ) ? "https://" : "http://";
			variables.URLEndpointHostname = awsDomain;
			variables.URLEndpoint         = protocol & awsDomain;
			return this;
		}

		// AWS or virtual-style — let the original method run.
		return super.buildUrlEndpoint( argumentCollection = arguments );
	}

}
