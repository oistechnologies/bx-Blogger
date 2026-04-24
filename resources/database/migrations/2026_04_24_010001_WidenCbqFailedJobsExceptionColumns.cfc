/**
 * Widen cbq_failed_jobs exception columns — TEXT instead of VARCHAR(255).
 *
 * Why this isn't in cbq itself:
 *   cbq 5.0.7 ships the `cbq_failed_jobs` table with
 *   `exceptionType` / `exceptionMessage` / `exceptionDetail` as
 *   VARCHAR(255). Real-world JVM exception messages routinely
 *   exceed that (the KeyNotFoundException from the Phase 10
 *   scheduler bug was ~500 chars just on the first line).
 *
 *   When a cbq worker catches an exception and tries to INSERT a
 *   row into `cbq_failed_jobs`, MySQL truncates + rejects the
 *   INSERT (strict mode):
 *
 *     Data truncation: Data too long for column 'exceptionMessage'
 *
 *   That INSERT failure leaves the original `cbq_jobs` row stuck
 *   in a reserved-but-not-completed state. The worker can't mark
 *   it failed, can't mark it complete, and next poll cycle finds
 *   it still reserved — so it retries. Forever. We saw a single
 *   broken job climb to `attempts=107` in ~30 minutes.
 *
 * Fix:
 *   ALTER the three varchar columns to TEXT (up to 65KB).
 *   `exceptionExtendedInfo` / `exceptionStackTrace` / `exception`
 *   are already LONGTEXT in cbq's schema — no change needed.
 *
 * Future cbq versions may widen these upstream; when that lands
 * we can drop this migration (or leave it as a no-op, since TEXT
 * is a superset of whatever cbq will likely widen to).
 */
component {

    function up( schema, qb ) {
        // Raw DDL — qb's schema.alter().change() is grammar-version-
        // sensitive for MODIFY COLUMN; a literal ALTER keeps this
        // portable across MySQL 5.7 / 8.x / 8.4 without ceremony.
        queryExecute(
            "ALTER TABLE cbq_failed_jobs
                MODIFY exceptionType    TEXT NULL,
                MODIFY exceptionMessage TEXT NOT NULL,
                MODIFY exceptionDetail  TEXT NULL"
        );
    }

    function down( schema, qb ) {
        // Rollback to cbq's original VARCHAR(255) definitions. Data
        // that exceeds 255 chars will be truncated by the cast —
        // acceptable on a rollback (it's a diagnostic field, not a
        // correctness-critical one).
        queryExecute(
            "ALTER TABLE cbq_failed_jobs
                MODIFY exceptionType    VARCHAR(255) NULL,
                MODIFY exceptionMessage VARCHAR(255) NOT NULL,
                MODIFY exceptionDetail  VARCHAR(255) NULL"
        );
    }

}
