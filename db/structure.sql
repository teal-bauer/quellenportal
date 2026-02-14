CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "origins" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "label" integer DEFAULT 0, "name" varchar);
CREATE UNIQUE INDEX "index_origins_on_label_and_name" ON "origins" ("label", "name");
CREATE INDEX "index_origins_on_name" ON "origins" ("name");
CREATE TABLE IF NOT EXISTS "cached_counts" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "model" varchar, "scope" varchar, "count" integer);
CREATE UNIQUE INDEX "index_cached_counts_on_model_and_scope" ON "cached_counts" ("model", "scope");
CREATE TABLE IF NOT EXISTS "archive_files" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "title" varchar, "summary" varchar, "call_number" varchar, "source_date_text" varchar, "source_id" varchar, "link" varchar, "location" varchar, "language_code" varchar, "parents" json DEFAULT '[]' NOT NULL, "source_date_start" date, "source_date_end" date, "archive_node_id" integer, CONSTRAINT parents_is_array CHECK (JSON_TYPE(parents) = 'array'));
CREATE TABLE IF NOT EXISTS "archive_nodes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar, "parent_node_id" integer, "source_id" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "level" varchar);
CREATE INDEX "index_archive_nodes_on_source_id" ON "archive_nodes" ("source_id");
CREATE INDEX "index_archive_nodes_on_parent_node_id" ON "archive_nodes" ("parent_node_id");
CREATE INDEX "index_archive_files_on_archive_node_id" ON "archive_files" ("archive_node_id");
CREATE UNIQUE INDEX "index_archive_files_on_source_id" ON "archive_files" ("source_id");
CREATE INDEX "index_archive_files_on_call_number" ON "archive_files" ("call_number");
CREATE INDEX "index_archive_files_on_title_and_summary" ON "archive_files" ("title", "summary");
CREATE INDEX "index_archive_files_on_summary" ON "archive_files" ("summary");
CREATE INDEX "index_archive_files_on_title" ON "archive_files" ("title");
CREATE TABLE IF NOT EXISTS "originations" ("archive_file_id" integer DEFAULT NULL, "origin_id" integer DEFAULT NULL);
CREATE INDEX "index_originations_on_origin_id" ON "originations" ("origin_id");
CREATE UNIQUE INDEX "index_originations_on_archive_file_id_and_origin_id" ON "originations" ("archive_file_id", "origin_id");
CREATE INDEX "index_originations_on_archive_file_id" ON "originations" ("archive_file_id");
CREATE VIRTUAL TABLE archive_file_trigrams USING fts5(archive_file_id UNINDEXED, archive_node_id UNINDEXED, title, summary, call_number, parents, origin_names, tokenize = 'trigram')
/* archive_file_trigrams(archive_file_id,archive_node_id,title,summary,call_number,parents,origin_names) */;
CREATE TABLE IF NOT EXISTS 'archive_file_trigrams_data'(id INTEGER PRIMARY KEY, block BLOB);
CREATE TABLE IF NOT EXISTS 'archive_file_trigrams_idx'(segid, term, pgno, PRIMARY KEY(segid, term)) WITHOUT ROWID;
CREATE TABLE IF NOT EXISTS 'archive_file_trigrams_content'(id INTEGER PRIMARY KEY, c0, c1, c2, c3, c4, c5, c6);
CREATE TABLE IF NOT EXISTS 'archive_file_trigrams_docsize'(id INTEGER PRIMARY KEY, sz BLOB);
CREATE TABLE IF NOT EXISTS 'archive_file_trigrams_config'(k PRIMARY KEY, v) WITHOUT ROWID;
INSERT INTO "schema_migrations" (version) VALUES
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

