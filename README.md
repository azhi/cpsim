# CPSIM

A platform for simulating a Charge Point as defined in [OCPP 1.6](https://www.openchargealliance.org/protocols/ocpp-16/) protocol.

Consists of:

* `cp` - an Elixir library that does the simulation itself.
* `backend` - a Phoenix (Elixir) app that provides RESTful API, using `cp` as a backend.
* `frontend` - an Elm app that provides a web GUI for the phoenix backend.

See READMEs in each component for more info.
