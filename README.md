# Quellenportal

Quellenportal is a Rails application for searching the [German Federal Archive (Bundesarchiv)](https://www.bundesarchiv.de/). It imports [apeEAD](http://apex-project.eu/index.php/en/outcomes/standards/apeead) formatted XML files and makes them searchable. You can use it at [quellenportal.de](https://quellenportal.de) (also available at [archivfinder.de](https://archivfinder.de)).

The search is optimized for quickly skimming large volumes of archival records.

## Features

Quellenportal extends the upstream Bundesarchiv search with:

- **Full-text trigram search** — substring matching via SQLite FTS5, including call numbers, titles, summaries, and provenance
- **Search operators** — AND, OR, NOT, phrase search (`"..."`), prefix matching (`term*`), and negation (`-term`)
- **Browsable entry points** — browse by fonds, provenance (origins), or decade, with letter index navigation
- **Node-scoped search** — search within a specific archival hierarchy branch
- **Auto-drill navigation** — automatically skips through single-child archive nodes
- **Citation export** — copy or download citations in RIS and BibTeX formats
- **Search help page** — documents available query syntax and operators
- **Background import** — imports XML data via Solid Queue background jobs
- **Direct Invenio links** — links to the Bundesarchiv's Invenio system for accessing actual archival objects

## Database

This application uses SQLite (even in production), database creation and migration is done with the standard Rails tasks.
Make sure to mount a volume into the docker image to persist your database. The default location for this is `/rails/db/sqlite`.

## Included XML Data

The `test/fixtures/files/dataset*` folders contain excerpts of the [CC0](https://creativecommons.org/public-domain/cc0/) licensed data from the German Federal Archive. You can find the full dataset on [open-data.bundesarchiv.de](https://open-data.bundesarchiv.de/apex-ead/) and more information on the open data program on their [website](https://www.bundesarchiv.de/DE/Content/Artikel/Ueber-uns/Aus-unserer-Arbeit/open-data.html).

## Downloading the full XML Data for import

In order to run your own instance you need the full dataset. It's available on [open-data.bundesarchiv.de](https://open-data.bundesarchiv.de/apex-ead/). Since the files are linked individually it's easiest to use an [auto downloader](https://www.downthemall.net/) to get all the data.
The default location that the importer looks for is the `data` folder, it's easiest to place your XML files there.

## License

Quellenportal is licensed under the GNU Affero General Public License (AGPL) — see the LICENSE file for details. The AGPL is a strong copyleft license that requires you to provide the source code of a modified version to users even if those users only access the software via a network.

If you would like to use a modified version of Quellenportal in a commercial setting please contact <info@quellenportal.de> for more information!

This does not cover the fonts used (found in `app/assets/fonts/`). Both are covered by the [SIL Open Font License](https://openfontlicense.org). For details see the fonts section and the respective `LICENSE` file.

## Fonts

Quellenportal uses two fonts:
* [Atkinson Hyperlegible](https://brailleinstitute.org/freefont)
* [EB Garamond](http://www.georgduffner.at/ebgaramond/)

Atkinson Hyperlegible is the default font for all text and EB Garamond is used for the title.

## Authors

Michael Emhofer, [emi.industries](https://emi.industries)

Extended by Teal Bauer <teal@starsong.eu>
