# CPSIM CP

An Elixir library that is responsible for simulating a charge point according to OCPP 1.6.

All public interface is defined in `CPSIM.CP` module.

Charge point is implemented as a single genserver, with all the logic inside being splitted into different modules.

List of library components:

* `CPSIM.CP.DynamicSupervisor` - responsible for launching Charge Point simulations.
* `CPSIM.CP.Core` - entrypoint for charge point genserver. Mostly contains logic that delegates to CP simulation
modules.
  * `CPSIM.CP.Connection` - a required (non-disableable) module responsible for establishing a WS connection to the
  OCPP server, and sending an OCPP calls into the connection according to OCPP spec (one at a time). Delegates
  processing incoming OCPP calls back into `CPSIM.CP.Core`, where it can be delegated to appropriate module.
  * `CPSIM.CP.Status` - a required (non-disableable) module responsible for tracking current charge point's and it's
  connector's statuses, as well as reporting status changes to the server.
  * `CPSIM.CP.Actions` - an optional (disableable) module responsible for executing a list of external actions. Each
  action implementation is responsible for changing internal CP state and/or notifying the server about these changes
  through OCPP calls. Actions are a backbone of the simulation, and provide any functionality desirable for the end
  user.
  * `CPSIM.CP.Commands` - an optional (disableable) module responsible for responding to server OCPP calls. Has an
  implementation for each supported OCPP command that changes internal CP state/responds to command accordingly.
  * `CPSIM.CP.Heartbeat` - an optional (disableable) module responsible for handling OCPP heartbeats according to spec,
  i.e. responsible for sending heartbeat only when they are required according to internal config and server settings.

