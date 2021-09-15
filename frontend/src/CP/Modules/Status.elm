module CP.Modules.Status exposing (CPModuleStatus, CPModuleStatusConfig, cpModulesStatusDecoder)

import CP.Modules.Status.OCPPConnectorStatus as CS exposing (OCPPConnectorStatus)
import CP.Modules.Status.OCPPStatus as S exposing (OCPPStatus)
import Json.Decode as D
import Json.Decode.Extra as DE
import Json.Decode.Pipeline exposing (custom, hardcoded, optional, required)
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
        |> required "initial_status" ocppStatusDecoder
        |> required "initial_connector_statuses" (D.list ocppConnectorStatusDecoder)


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
                        D.map (REPORTED r) (D.field "status" ocppStatusDecoder)

                    Nothing ->
                        D.map NOT_REPORTED (D.field "status" ocppStatusDecoder)
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
                    (D.field "connector_statuses" (D.list ocppConnectorStatusDecoder))
            )


ocppStatusDecoder : D.Decoder OCPPStatus
ocppStatusDecoder =
    D.string
        |> D.andThen
            (\status ->
                case status of
                    "available" ->
                        D.succeed S.AVAILABLE

                    "unavailable" ->
                        D.succeed S.UNAVAILABLE

                    "faulted" ->
                        D.succeed S.FAULTED

                    other ->
                        D.fail ("Unexpected ocpp status " ++ other)
            )


ocppConnectorStatusDecoder : D.Decoder OCPPConnectorStatus
ocppConnectorStatusDecoder =
    D.string
        |> D.andThen
            (\status ->
                case status of
                    "available" ->
                        D.succeed CS.AVAILABLE

                    "unavailable" ->
                        D.succeed CS.UNAVAILABLE

                    "faulted" ->
                        D.succeed CS.FAULTED

                    "preparing" ->
                        D.succeed CS.PREPARING

                    "charging" ->
                        D.succeed CS.CHARGING

                    "suspended_ev" ->
                        D.succeed CS.SUSPENDED_EV

                    "suspended_evse" ->
                        D.succeed CS.SUSPENDED_EVSE

                    "finishing" ->
                        D.succeed CS.FINISHING

                    "reserved" ->
                        D.succeed CS.RESERVED

                    other ->
                        D.fail ("Unexpected ocpp connector status " ++ other)
            )
