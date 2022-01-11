# CPSIM

A platform for simulating a Charge Point as defined in [OCPP 1.6](https://www.openchargealliance.org/protocols/ocpp-16/) protocol.

Consists of:

* `cp` - an Elixir library that does the simulation itself.
* `backend` - a Phoenix (Elixir) app that provides RESTful API, using `cp` as a backend.
* `frontend` - an Elm app that provides a web GUI for the phoenix backend.

See READMEs in each component for more info.

## Current Status

Mostly holds together, but lacks some crucial features, like:

* realtime updates for and on frontend
* ability to enqueue new actions for existing Charge Point on frontend
* ability to persist Charge Point state to DB - as of now, Charge Point state only exists inside active genserver
* Dockerfiles and deploy instructions

### Future work

Throughout the code, there are a lot of TODOs pointing at future improvements.
