module CP.Modules.Heartbeat exposing (CPModuleHeartbeat, CPModuleHeartbeatConfig, CPModuleHeartbeatState, configEncoder, cpModulesHeartbeatDecoder)

import Json.Decode as D
import Json.Decode.Extra as DE
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode as E
import Time


type alias CPModuleHeartbeat =
    { config : CPModuleHeartbeatConfig
    , state : CPModuleHeartbeatState
    }


type alias CPModuleHeartbeatConfig =
    { defaultInterval : Int }


type alias CPModuleHeartbeatState =
    { interval : Int
    , lastMessageAt : Maybe Time.Posix
    , lastHeartbeatAt : Maybe Time.Posix
    }


cpModulesHeartbeatDecoder : D.Decoder (Maybe CPModuleHeartbeat)
cpModulesHeartbeatDecoder =
    D.nullable
        (D.succeed CPModuleHeartbeat
            |> required "config" configDecoder
            |> required "state" stateDecoder
        )


configDecoder : D.Decoder CPModuleHeartbeatConfig
configDecoder =
    D.succeed CPModuleHeartbeatConfig
        |> required "default_interval" D.int


stateDecoder : D.Decoder CPModuleHeartbeatState
stateDecoder =
    D.succeed CPModuleHeartbeatState
        |> required "interval" D.int
        |> required "last_message_at" (D.nullable DE.datetime)
        |> required "last_heartbeat_at" (D.nullable DE.datetime)


configEncoder : CPModuleHeartbeatConfig -> E.Value
configEncoder cfg =
    E.object
        [ ( "default_interval", E.int cfg.defaultInterval )
        ]
