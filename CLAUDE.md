# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Quellenportal (formerly Bundessuche) is a Rails 8 application that imports and searches German Federal Archive (Bundesarchiv) data. It parses apeEAD-formatted XML files and provides a search interface optimized for quickly skimming large volumes of archival records.

## Common Commands

```bash
# Development server
bin/rails server

# Run all tests
bin/rails test

# Run single test file
bin/rails test test/models/archive_file_test.rb

# Run specific test by line number
bin/rails test test/models/archive_file_test.rb:42

# Import archive data from XML files (defaults to ./data directory)
bin/rails data:import_sync

# Import from specific directory
bin/rails data:import_sync[path/to/xml/files]

# Configure Meilisearch index settings (search/sort/filter/pagination)
bin/rails data:configure_indices

# Rebuild origins index with dedup + Unicode normalization (zero-downtime blue-green swap)
bin/rails data:rebuild_origins

# Delete and recreate all Meilisearch indices
bin/rails data:recreate_indices

# Linting
bundle exec stree check app lib
bundle exec htmlbeautifier app/views/**/*.erb
```

## Architecture

### Data Storage

All data is stored in **Meilisearch** (no SQL database). `MeilisearchRepository` (`app/services/meilisearch_repository.rb`) wraps all Meilisearch HTTP API calls. Three indices:

- **`ArchiveFile_<env>`**: Individual archival records (~4.3M documents). Searchable by title, summary, call number, parent names, origin names. Filterable by fonds, decade, date range, origin.
- **`ArchiveNode_<env>`**: Hierarchical tree structure (fonds, series, etc.). Filterable by level, parent, first letter.
- **`Origin_<env>`**: Provenance entities (~101K unique, deduped by name). Deterministic IDs via SHA256 hash of name.

### Data Model

The archive follows a hierarchical structure reflecting archival organization:

- **ArchiveNode**: Hierarchical tree (fonds → series → subseries). Stores `parent_node_id`, `ancestor_ids`, `parents` array.
- **ArchiveFile**: Individual archival records at the "file" level. Stores denormalized `parents` JSON array and `fonds_*` fields for faceting.
- **Origin**: Provenance (originator) of archive files. Keyed by name with deterministic IDs. `first_letter` is Unicode-normalized (NFD accent stripping).

### Search System

Search uses Meilisearch's built-in full-text search with typo tolerance and German stop words. Faceted search supports filtering by fonds name, unitid, unitid prefix, decade, and date range. `maxTotalHits` is set to 500K on all indices.

### Data Import

`BundesarchivImporter` (`app/importers/bundesarchiv_importer.rb`) parses apeEAD XML files. It processes documents hierarchically via the `ArchiveObject` class, creating nodes for structural levels and files for file-level records. Documents are batched and upserted to Meilisearch in groups of 100/1000.

Origins are deduped by name with deterministic SHA256-based IDs, so the same origin appearing across multiple XML files merges naturally. `normalize_letter` uses Unicode `\p{L}`/`\p{N}` classes and NFD decomposition for accent stripping.

### Key Design Decisions

- **Meilisearch as sole data store**: No SQL database. All reads and writes go through `MeilisearchRepository`. Index settings configured via `data:configure_indices`.
- **Blue-green index rebuilds**: `data:rebuild_origins` builds into a shadow index, then atomically swaps via Meilisearch's swap-indexes API for zero-downtime rebuilds.
- **Denormalized parents**: ArchiveFile stores `parents` as JSON array to avoid repeated tree traversal during display.
- **German locale**: Default locale is `de`.
- **ViewComponent**: Used for reusable UI components (`app/components/`).
- **IP blocking**: `IpBlocker` middleware with three tiers: config-file bans (`config/manual_bans.txt`), runtime manual bans, and auto-bans (30-day TTL). Honeypot paths trigger auto-bans.

## Deployment

Deployed via Kamal 2 to a Proxmox LXC container. Meilisearch runs as a Kamal accessory on the same host.

```bash
# Deploy
kamal deploy

# Run commands in production container
kamal app exec --reuse 'bin/rails data:configure_indices'
kamal app exec --reuse 'bin/rails data:rebuild_origins'

# Interactive console
kamal console

# Tail logs
kamal logs
```

## Testing

Uses Rails Minitest with fixtures. Tests run in parallel. Fixture files in `test/fixtures/files/dataset*` contain sample Bundesarchiv XML data (CC0 licensed).
