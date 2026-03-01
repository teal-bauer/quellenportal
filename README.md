# Quellenportal

<img src="public/favicon.svg" alt="Quellenportal logo" width="80" align="right">

Quellenportal is a Rails application for searching the [German Federal Archive (Bundesarchiv)](https://www.bundesarchiv.de/). It imports [apeEAD](http://apex-project.eu/index.php/en/outcomes/standards/apeead) formatted XML files and makes them searchable. You can use it at [quellenportal.de](https://quellenportal.de).

The search is optimized for quickly skimming large volumes of archival records.

## Features

Bundessuche supported:

- **Citation export** — copy or download citations in RIS and BibTeX formats
- **Direct Invenio links** — links to the Bundesarchiv's Invenio system for accessing actual archival objects

Quellenportal extends upstream with:

- **Fast full-text search** — sub-100ms search with relevance ranking and typo tolerance via Meilisearch
- **Faceted search** — filter by fonds (archival collection) and decade directly from search results, with a log-scale histogram for date distribution and results sorted by hit count
- **Search operators** — AND, OR, NOT, phrase search (`"..."`), and negation (`-term`)
- **Browsable entry points** — browse by fonds, provenance (origins), or time period, with letter index navigation
- **Node-scoped search** — search within a specific archival hierarchy branch
- **Auto-drill navigation** — automatically skips through single-child archive nodes
- **Search help page** — documents available query syntax and operators
- **Background import** — imports XML data via Solid Queue background jobs

## Architecture

- **Rails 8** + **Meilisearch** (sole data store for all archival records)
- **SQLite** (only for Solid Queue job tables and import progress tracking)
- **Solid Queue** (background job processing for imports)
- **Kamal 2** (deployment, with Meilisearch as a managed accessory)

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

Quellenportal is licensed under the GNU Affero General Public License (AGPL) — see the [LICENSE](LICENSE) file for details. The AGPL is a strong copyleft license that requires you to provide the source code of a modified version to users, even if those users only access the software via a network.

This does not cover the fonts used (found in `app/assets/fonts/`). Both are covered by the [SIL Open Font License](https://openfontlicense.org). For details see the fonts section and the respective `LICENSE` file.

## Fonts

Quellenportal uses two fonts:
* [Atkinson Hyperlegible](https://brailleinstitute.org/freefont)
* [EB Garamond](http://www.georgduffner.at/ebgaramond/)

Atkinson Hyperlegible is the default font for all text and EB Garamond is used for the title.

## Authors

Teal Bauer <teal@starsong.eu>, [Starsong Consulting](https://starsong.consulting)

Based on Bundessuche by Michael Emhofer, [emi.industries](https://emi.industries)
