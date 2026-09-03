-- Hosted Data API (PostgREST) exposes only public + graphql_public by default.
-- The backend contract requires the api schema (organizer + service RPC wrappers)
-- and the storage schema (banner orphan cleanup queries storage.objects).
-- Dashboard equivalent: Integrations > Data API > Exposed schemas.
-- `notify pgrst, 'reload schema'` refreshes the schema cache immediately.

alter role authenticator set pgrst.db_schemas = 'public, api, storage, graphql_public';
notify pgrst, 'reload schema';
