CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "origins" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "label" integer DEFAULT 0, "name" varchar);
CREATE UNIQUE INDEX "index_origins_on_label_and_name" ON "origins" ("label", "name");
CREATE INDEX "index_origins_on_name" ON "origins" ("name");
CREATE TABLE IF NOT EXISTS "cached_counts" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "model" varchar, "scope" varchar, "count" integer);
CREATE UNIQUE INDEX "index_cached_counts_on_model_and_scope" ON "cached_counts" ("model", "scope");
CREATE TABLE IF NOT EXISTS "archive_files" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "title" varchar, "summary" varchar, "call_number" varchar, "source_date_text" varchar, "source_id" varchar, "link" varchar, "location" varchar, "language_code" varchar, "parents" json DEFAULT '[]' NOT NULL, "source_date_start" date, "source_date_end" date, "archive_node_id" integer, "source_date_start_uncorrected" date /*application='Bundessuche'*/, "source_date_end_uncorrected" date /*application='Bundessuche'*/, CONSTRAINT parents_is_array CHECK (JSON_TYPE(parents) = 'array'));
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
CREATE TABLE IF NOT EXISTS "solid_queue_jobs" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "queue_name" varchar NOT NULL, "class_name" varchar NOT NULL, "arguments" text, "priority" integer DEFAULT 0 NOT NULL, "active_job_id" varchar, "scheduled_at" datetime(6), "finished_at" datetime(6), "concurrency_key" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_solid_queue_jobs_on_active_job_id" ON "solid_queue_jobs" ("active_job_id") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_jobs_on_class_name" ON "solid_queue_jobs" ("class_name") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_jobs_on_finished_at" ON "solid_queue_jobs" ("finished_at") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_jobs_for_filtering" ON "solid_queue_jobs" ("queue_name", "finished_at") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_jobs_for_alerting" ON "solid_queue_jobs" ("scheduled_at", "finished_at") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_pauses" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "queue_name" varchar NOT NULL, "created_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_solid_queue_pauses_on_queue_name" ON "solid_queue_pauses" ("queue_name") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_processes" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "kind" varchar NOT NULL, "last_heartbeat_at" datetime(6) NOT NULL, "supervisor_id" bigint, "pid" integer NOT NULL, "hostname" varchar, "metadata" text, "created_at" datetime(6) NOT NULL, "name" varchar NOT NULL);
CREATE INDEX "index_solid_queue_processes_on_last_heartbeat_at" ON "solid_queue_processes" ("last_heartbeat_at") /*application='Bundessuche'*/;
CREATE UNIQUE INDEX "index_solid_queue_processes_on_name_and_supervisor_id" ON "solid_queue_processes" ("name", "supervisor_id") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_processes_on_supervisor_id" ON "solid_queue_processes" ("supervisor_id") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_recurring_tasks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "schedule" varchar NOT NULL, "command" varchar(2048), "class_name" varchar, "arguments" text, "queue_name" varchar, "priority" integer DEFAULT 0, "static" boolean DEFAULT 1 NOT NULL, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_solid_queue_recurring_tasks_on_key" ON "solid_queue_recurring_tasks" ("key") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_recurring_tasks_on_static" ON "solid_queue_recurring_tasks" ("static") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_semaphores" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "key" varchar NOT NULL, "value" integer DEFAULT 1 NOT NULL, "expires_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE INDEX "index_solid_queue_semaphores_on_expires_at" ON "solid_queue_semaphores" ("expires_at") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_semaphores_on_key_and_value" ON "solid_queue_semaphores" ("key", "value") /*application='Bundessuche'*/;
CREATE UNIQUE INDEX "index_solid_queue_semaphores_on_key" ON "solid_queue_semaphores" ("key") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_blocked_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "concurrency_key" varchar NOT NULL, "expires_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_4cd34e2228"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE INDEX "index_solid_queue_blocked_executions_for_release" ON "solid_queue_blocked_executions" ("concurrency_key", "priority", "job_id") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_blocked_executions_for_maintenance" ON "solid_queue_blocked_executions" ("expires_at", "concurrency_key") /*application='Bundessuche'*/;
CREATE UNIQUE INDEX "index_solid_queue_blocked_executions_on_job_id" ON "solid_queue_blocked_executions" ("job_id") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_claimed_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "process_id" bigint, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_9cfe4d4944"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_claimed_executions_on_job_id" ON "solid_queue_claimed_executions" ("job_id") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_claimed_executions_on_process_id_and_job_id" ON "solid_queue_claimed_executions" ("process_id", "job_id") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_failed_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "error" text, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_39bbc7a631"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_failed_executions_on_job_id" ON "solid_queue_failed_executions" ("job_id") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_ready_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_81fcbd66af"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_ready_executions_on_job_id" ON "solid_queue_ready_executions" ("job_id") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_poll_all" ON "solid_queue_ready_executions" ("priority", "job_id") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_poll_by_queue" ON "solid_queue_ready_executions" ("queue_name", "priority", "job_id") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_recurring_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "task_key" varchar NOT NULL, "run_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_318a5533ed"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_recurring_executions_on_job_id" ON "solid_queue_recurring_executions" ("job_id") /*application='Bundessuche'*/;
CREATE UNIQUE INDEX "index_solid_queue_recurring_executions_on_task_key_and_run_at" ON "solid_queue_recurring_executions" ("task_key", "run_at") /*application='Bundessuche'*/;
CREATE TABLE IF NOT EXISTS "solid_queue_scheduled_executions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "job_id" bigint NOT NULL, "queue_name" varchar NOT NULL, "priority" integer DEFAULT 0 NOT NULL, "scheduled_at" datetime(6) NOT NULL, "created_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_c4316f352d"
FOREIGN KEY ("job_id")
  REFERENCES "solid_queue_jobs" ("id")
 ON DELETE CASCADE);
CREATE UNIQUE INDEX "index_solid_queue_scheduled_executions_on_job_id" ON "solid_queue_scheduled_executions" ("job_id") /*application='Bundessuche'*/;
CREATE INDEX "index_solid_queue_dispatch_all" ON "solid_queue_scheduled_executions" ("scheduled_at", "priority", "job_id") /*application='Bundessuche'*/;
CREATE INDEX "index_archive_files_on_source_date_start" ON "archive_files" ("source_date_start") /*application='Bundessuche'*/;
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
INSERT INTO "schema_migrations" (version) VALUES
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
('20240418135025'),
('1');

