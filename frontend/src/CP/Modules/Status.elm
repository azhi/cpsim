module CP.Modules.Status exposing (CPModuleStatus, CPModuleStatusConfig, configEncoder, cpModulesStatusDecoder)

import CP.Modules.Status.OCPPConnectorStatus as CS exposing (OCPPConnectorStatus)
import CP.Modules.Status.OCPPStatus as S exposing (OCPPStatus)
import Json.Decode as D
import Json.Decode.Extra as DE
import Json.Decode.Pipeline exposing (custom, hardcoded, optional, required)
import Json.Encode as E
import Time


type alias CPModuleStatus =
    { config : CPModuleStatusConfig
    , state : CPModuleStatusState
    }


type alias CPModuleStatusConfig =
    { initialStatus : OCPPStatus
    , initialConnectorStatuses : List OCPPConnectorStatus
    }


type CPModuleStatusStateMaybeReported a
    = NOT_REPORTED a
    | REPORTED Time.Posix a


type alias CPModuleStatusState =
    { status : CPModuleStatusStateMaybeReported OCPPStatus
    , connectorStatuses : List (CPModuleStatusStateMaybeReported OCPPConnectorStatus)
    }


cpModulesStatusDecoder : D.Decoder CPModuleStatus
cpModulesStatusDecoder =
    D.succeed CPModuleStatus
        |> required "config" configDecoder
        |> required "state" stateDecoder


configDecoder : D.Decoder CPModuleStatusConfig
configDecoder =
    D.succeed CPModuleStatusConfig
        |> required "initial_status" S.decoder
        |> required "initial_connector_statuses" (D.list CS.decoder)


stateDecoder : D.Decoder CPModuleStatusState
stateDecoder =
    D.succeed CPModuleStatusState
        |> custom ocppStateStatusDecoder
        |> custom ocppStateConnectorStatusDecoder


ocppStateStatusDecoder : D.Decoder (CPModuleStatusStateMaybeReported OCPPStatus)
ocppStateStatusDecoder =
    D.field "status_reported_at" (D.nullable DE.datetime)
        |> D.andThen
            (\mr ->
                case mr of
                    Just r ->
                        D.map (REPORTED r) (D.field "status" S.decoder)

                    Nothing ->
                        D.map NOT_REPORTED (D.field "status" S.decoder)
            )


ocppStateConnectorStatusDecoder : D.Decoder (List (CPModuleStatusStateMaybeReported OCPPConnectorStatus))
ocppStateConnectorStatusDecoder =
    D.field "connector_statuses_reported_at" (D.list (D.nullable DE.datetime))
        |> D.andThen
            (\lmr ->
                D.map
                    (\ls ->
                        List.map2
                            (\mr s ->
                                case mr of
                                    Just r ->
                                        REPORTED r s

                                    Nothing ->
                                        NOT_REPORTED s
                            )
                            lmr
                            ls
                    )
                    (D.field "connector_statuses" (D.list CS.decoder))
            )


configEncoder : CPModuleStatusConfig -> E.Value
configEncoder cfg =
    E.object
        [ ( "initial_status", S.encoder cfg.initialStatus )
        , ( "initial_connector_statuses", E.list CS.encoder cfg.initialConnectorStatuses )
        ]
