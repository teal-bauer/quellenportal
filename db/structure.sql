CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "origins" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "label" integer DEFAULT 0, "name" varchar);
CREATE UNIQUE INDEX "index_origins_on_label_and_name" ON "origins" ("label", "name") /*application='Bundessuche'*/;
CREATE INDEX "index_origins_on_name" ON "origins" ("name") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "cached_counts" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "model" varchar, "scope" varchar, "count" integer);
CREATE UNIQUE INDEX "index_cached_counts_on_model_and_scope" ON "cached_counts" ("model", "scope") /*application='Bundessuche'*/;
CREATE VIRTUAL TABLE archive_file_trigrams USING fts5(
  archive_file_id UNINDEXED,
  archive_node_id UNINDEXED,
  fonds_id UNINDEXED,
  fonds_name UNINDEXED,
  decade UNINDEXED,
  title, summary, call_number, parents, origin_names,
  tokenize = 'trigram'
)
/* archive_file_trigrams(archive_file_id,archive_node_id,fonds_id,fonds_name,decade,title,summary,call_number,parents,origin_names) */;
CREATE TABLE IF NOT EXISTS 'archive_file_trigrams_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'archive_file_trigrams_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'archive_file_trigrams_content'(id INTEGER PRIMARY KEY, c0, c1, c2, c3, c4, c5, c6, c7, c8, c9);
CREATE TABLE IF NOT EXISTS 'archive_file_trigrams_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'archive_file_trigrams_config'(k PRIMARY KEY, v) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS "archive_nodes" ("id" varchar NOT NULL PRIMARY KEY, "parent_node_id" varchar, "name" varchar, "level" varchar, "unitid" varchar, "unitdate" varchar, "physdesc" json, "langmaterial" varchar, "origination" json, "repository" json, "scopecontent" text, "relatedmaterial" text, "prefercite" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "archive_files" ("id" varchar NOT NULL PRIMARY KEY, "archive_node_id" varchar, "title" varchar, "parents" json NOT NULL, "call_number" varchar, "source_date_text" varchar, "source_date_start" date, "source_date_end" date, "source_date_start_uncorrected" date, "source_date_end_uncorrected" date, "link" varchar, "location" varchar, "language_code" varchar, "summary" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "originations" ("archive_file_id" varchar NOT NULL, "origin_id" bigint NOT NULL);
CREATE INDEX "index_archive_nodes_on_parent_node_id" ON "archive_nodes" ("parent_node_id") /*application='Bundessuche'*/;
CREATE INDEX "index_archive_files_on_title_and_summary" ON "archive_files" ("title", "summary") /*application='Bundessuche'*/;
CREATE INDEX "index_archive_files_on_title" ON "archive_files" ("title") /*application='Bundessuche'*/;
CREATE INDEX "index_archive_files_on_source_date_start" ON "archive_files" ("source_date_start") /*application='Bundessuche'*/;
CREATE INDEX "index_archive_files_on_call_number" ON "archive_files" ("call_number") /*application='Bundessuche'*/;
CREATE INDEX "index_archive_files_on_archive_node_id" ON "archive_files" ("archive_node_id") /*application='Bundessuche'*/;
CREATE UNIQUE INDEX "index_originations_on_archive_file_id_and_origin_id" ON "originations" ("archive_file_id", "origin_id") /*application='Bundessuche'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20260218205230'),
('20260218200227'),
('20260216195107'),
('20260216141601'),
('20260215000730'),
('20240826215919'),
('20240825103844'),
('20240825102326'),
('20240825095047'),
('20240825093053'),
('20240825083132'),
('20240811213335'),
('20240811202445'),
('20240510085044'),
('20240418135025');

