module CP.Modules.Connection exposing (CPModuleConnection, CPModuleConnectionConfig, CPModuleConnectionState(..), configEncoder, cpModulesConnectionDecoder)

import Json.Decode as D
import Json.Decode.Extra as DE
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode as E
import Time


type alias CPModuleConnection =
    { config : CPModuleConnectionConfig
    , state : CPModuleConnectionState
    }


type alias CPModuleConnectionConfig =
    { callTimeoutInterval : Int
    , defaultRetryInterval : Int
    , hardRebootInterval : Int
    , softRebootInterval : Int
    }


type CPModuleConnectionState
    = Idle
    | WSInit
    | BootNotification { outgoingCallQueue : List OCPPCall }
    | Pending { outgoingCallQueue : List OCPPCall }
    | Retry { connectionError : String, retryAt : Time.Posix }
    | Resetting { retryAt : Time.Posix }
    | Done { outgoingCallQueue : List OCPPCall, currentTimeDiff : Float }


type OCPPCallStatus
    = NotSent
    | Sent


type alias OCPPCall =
    { id : String
    , action : String
    , payload : D.Value
    , status : OCPPCallStatus
    }


cpModulesConnectionDecoder : D.Decoder CPModuleConnection
cpModulesConnectionDecoder =
    D.succeed CPModuleConnection
        |> required "config" configDecoder
        |> required "state" stateDecoder


configDecoder : D.Decoder CPModuleConnectionConfig
configDecoder =
    D.succeed CPModuleConnectionConfig
        |> required "call_timeout_interval" D.int
        |> required "default_retry_interval" D.int
        |> required "hard_reboot_interval" D.int
        |> required "soft_reboot_interval" D.int


stateDecoder : D.Decoder CPModuleConnectionState
stateDecoder =
    D.field "status" D.string
        |> D.andThen stateByStatusDecoder


stateByStatusDecoder : String -> D.Decoder CPModuleConnectionState
stateByStatusDecoder status =
    case status of
        "idle" ->
            D.succeed Idle

        "ws_init" ->
            D.succeed WSInit

        "boot_notification" ->
            D.map BootNotification
                (D.succeed (\q -> { outgoingCallQueue = q })
                    |> required "outgoing_call_queue" (D.list ocppCallDecoder)
                )

        "pending" ->
            D.map Pending
                (D.succeed (\q -> { outgoingCallQueue = q })
                    |> required "outgoing_call_queue" (D.list ocppCallDecoder)
                )

        "retry" ->
            D.map Retry
                (D.succeed (\e r -> { connectionError = e, retryAt = r })
                    |> required "connection_error" D.string
                    |> required "retry_at" DE.datetime
                )

        "resetting" ->
            D.map Resetting
                (D.succeed (\r -> { retryAt = r })
                    |> required "retry_at" DE.datetime
                )

        "done" ->
            D.map Done
                (D.succeed (\q d -> { outgoingCallQueue = q, currentTimeDiff = d })
                    |> required "outgoing_call_queue" (D.list ocppCallDecoder)
                    |> required "current_time_diff" D.float
                )

        other ->
            D.fail ("Unexpected connection status " ++ other)


ocppCallDecoder : D.Decoder OCPPCall
ocppCallDecoder =
    D.succeed OCPPCall
        |> required "id" D.string
        |> required "action" D.string
        |> required "payload" D.value
        |> required "sent" ocppCallStatusDecoder


ocppCallStatusDecoder : D.Decoder OCPPCallStatus
ocppCallStatusDecoder =
    D.bool
        |> D.andThen
            (\sent ->
                if sent then
                    D.succeed Sent

                else
                    D.succeed NotSent
            )


configEncoder : CPModuleConnectionConfig -> E.Value
configEncoder cfg =
    E.object
        [ ( "call_timeout_interval", E.int cfg.callTimeoutInterval )
        , ( "default_retry_interval", E.int cfg.defaultRetryInterval )
        , ( "hard_reboot_interval", E.int cfg.hardRebootInterval )
        , ( "soft_reboot_interval", E.int cfg.softRebootInterval )
        ]
