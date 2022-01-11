# CPSIM Frontend

An Elm SPA implementing a frontend for `CPSIM Backend`.
Uses [rtfeldman/elm-spa-example](https://github.com/rtfeldman/elm-spa-example) as a template.

## Build

* `elm make src/Main.elm --output elm.js`
* Use provided `index.html`

## Dev Server

* `elm-live -y http://localhost:4000/api -x /api --pushstate -- src/Main.elm --output=elm.js --debug`

Proxies API queries to `CPSIM Backend` started with default config. Provides auto page reloads on code changes.
