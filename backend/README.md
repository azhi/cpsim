# CPSIM Backend

A simple Phoenix RESTful API for `CPSIM.CP`. Contains additional changeset validations that should prevent some invalid
CP configs to be started.

Setup:

* `mix deps.get`
* `mix ecto.setup`
* `mix phx.server`
