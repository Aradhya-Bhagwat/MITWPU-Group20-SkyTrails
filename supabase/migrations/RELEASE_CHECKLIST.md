# Watchlist Refactor Release Checklist

## Staging rehearsal
1. Apply `V1_additive.sql` -> `V6_validation.sql` in order.
2. Confirm `V6_validation.sql` returns:
   - `invalid_typed_rows = 0`
   - no counter drift rows
   - orphan checks all `0`
3. Validate `watchlist_rule_migration_audit` count is expected and reviewed.

## App sync checks
1. Create shared watchlist in app.
2. Add participant by UUID.
3. Remove participant.
4. Confirm rows in `watchlist_shares` have `server_row_version`, `deleted_at` behavior as expected.

## Cascade and GC checks
1. Delete watchlist with entries/photos.
2. Confirm entries/photos cascade delete at DB level.
3. Confirm `photo_delete_gc_queue` receives rows.
4. Run `watchlist-photo-gc` function and verify queue rows move to `done`.

## Observed identity checks
1. Mark entry observed from authenticated app user.
2. Confirm `observed_by_user_id` is populated in `watchlist_entries`.
3. Confirm `observed_by` remains nullable fallback text.

## Production rollout
1. Apply `V1` -> `V3`.
2. Release app build.
3. Run smoke scenarios above.
4. Apply `V4_cleanup`.
5. Run `V6_validation.sql` and archive output.
