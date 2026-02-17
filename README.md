# Quellenportal

<img src="public/favicon.svg" alt="Quellenportal logo" width="80" align="right">

Quellenportal is a Rails application for searching the [German Federal Archive (Bundesarchiv)](https://www.bundesarchiv.de/). It imports [apeEAD](http://apex-project.eu/index.php/en/outcomes/standards/apeead) formatted XML files and makes them searchable. You can use it at [quellenportal.de](https://quellenportal.de) (also available at [archivfinder.de](https://archivfinder.de)).

The search is optimized for quickly skimming large volumes of archival records.

## Features

Quellenportal extends the upstream Bundesarchiv search with:

- **Fast full-text search** — sub-100ms search with relevance ranking and typo tolerance via Meilisearch
- **Faceted search** — filter by fonds (archival collection) and decade directly from search results, with a log-scale histogram for date distribution and results sorted by hit count
- **Search operators** — AND, OR, NOT, phrase search (`"..."`), and negation (`-term`)
- **Browsable entry points** — browse by fonds, provenance (origins), or time period, with letter index navigation
- **Node-scoped search** — search within a specific archival hierarchy branch
- **Auto-drill navigation** — automatically skips through single-child archive nodes
- **Citation export** — copy or download citations in RIS and BibTeX formats
- **Search help page** — documents available query syntax and operators
- **Background import** — imports XML data via Solid Queue background jobs
- **Direct Invenio links** — links to the Bundesarchiv's Invenio system for accessing actual archival objects

## Architecture

- **Rails 8** + SQLite (data storage, browse queries)
- **Meilisearch** (full-text search, faceting, typo tolerance)
- **Solid Queue** (background job processing for imports)
- **Kamal 2** (deployment, with Meilisearch as a managed accessory)

## Database

This application uses SQLite (even in production). Database creation and migration is done with the standard Rails tasks. Make sure to mount a volume into the docker image to persist your database. The default location is `/rails/db/sqlite`.

The Rails cache is also stored on this volume (`/rails/db/sqlite/cache`), so browse data and counts survive container restarts and deploys.

## Included XML Data

The `test/fixtures/files/dataset*` folders contain excerpts of the [CC0](https://creativecommons.org/public-domain/cc0/) licensed data from the German Federal Archive. You can find the full dataset on [open-data.bundesarchiv.de](https://open-data.bundesarchiv.de/apex-ead/) and more information on the open data program on their [website](https://www.bundesarchiv.de/DE/Content/Artikel/Ueber-uns/Aus-unserer-Arbeit/open-data.html).

## Downloading the full XML data

Download all XML files from the Bundesarchiv open data portal with the built-in rake task:

```bash
bin/rails data:download
```

This fetches the file listing from [open-data.bundesarchiv.de](https://open-data.bundesarchiv.de/apex-ead/) and downloads all XML files into the `data/` directory, skipping any that already exist. After downloading, import with:

```bash
bin/rails data:import_sync   # synchronous (~110 min for 4.3M records)
bin/rails data:import        # background via Solid Queue
bin/rails data:reindex       # rebuild Meilisearch index
```

## License

Quellenportal is licensed under the GNU Affero General Public License (AGPL) — see the LICENSE file for details.

This does not cover the fonts used (found in `app/assets/fonts/`). Both are covered by the [SIL Open Font License](https://openfontlicense.org). For details see the fonts section and the respective `LICENSE` file.

## Fonts

Quellenportal uses two fonts:
* [Atkinson Hyperlegible](https://brailleinstitute.org/freefont)
* [EB Garamond](http://www.georgduffner.at/ebgaramond/)

Atkinson Hyperlegible is the default font for all text and EB Garamond is used for the title.

## Authors

Teal Bauer <teal@starsong.eu>, [Starsong Consulting](https://starsong.consulting)

Based on Bundessuche by Michael Emhofer, [emi.industries](https://emi.industries)
