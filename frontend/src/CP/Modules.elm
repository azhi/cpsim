module CP.Modules exposing (CPModules, cpModulesDecoder)

import CP.Modules.Actions exposing (CPModuleActions, cpModulesActionsDecoder)
import CP.Modules.Commands exposing (CPModuleCommands, cpModulesCommandsDecoder)
import CP.Modules.Connection exposing (CPModuleConnection, cpModulesConnectionDecoder)
import CP.Modules.Heartbeat exposing (CPModuleHeartbeat, cpModulesHeartbeatDecoder)
import CP.Modules.Status exposing (CPModuleStatus, cpModulesStatusDecoder)
import Json.Decode as D
import Json.Decode.Pipeline exposing (hardcoded, optional, required)


type alias CPModules =
    { connection : CPModuleConnection
    , status : CPModuleStatus
    , actions : Maybe CPModuleActions
    , commands : Maybe CPModuleCommands
    , heartbeat : Maybe CPModuleHeartbeat
    }


cpModulesDecoder : D.Decoder CPModules
cpModulesDecoder =
    D.succeed CPModules
        |> required "Elixir.CPSIM.CP.Connection" cpModulesConnectionDecoder
        |> required "Elixir.CPSIM.CP.Status" cpModulesStatusDecoder
        |> required "Elixir.CPSIM.CP.Actions" cpModulesActionsDecoder
        |> required "Elixir.CPSIM.CP.Commands" cpModulesCommandsDecoder
        |> required "Elixir.CPSIM.CP.Heartbeat" cpModulesHeartbeatDecoder
