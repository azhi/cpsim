module CP.Modules.Actions exposing (CPModuleActions, CPModuleActionsAction, CPModuleActionsActionStatus(..), CPModuleActionsActionType(..), CPModuleActionsActionTypeChargePeriodConfigSpeedup(..), CPModuleActionsBatch, CPModuleActionsConfig, configEncoder, cpModulesActionsDecoder)

import CP.Modules.Status.OCPPConnectorStatus as OCPPConnectorStatus exposing (OCPPConnectorStatus)
import Json.Decode as D
import Json.Decode.Extra as DE
import Json.Decode.Pipeline exposing (custom, hardcoded, optional, required)
import Json.Encode as E


type alias CPModuleActions =
    { config : CPModuleActionsConfig
    , state : CPModuleActionsState
    }


type CPModuleActionsActionStatus
    = IDLE
    | IN_PROGRESS
    | DONE


type alias CPModuleActionsActionTypeStatusChangeConfig =
    { connector : Int
    , status : OCPPConnectorStatus
    }


type alias CPModuleActionsActionTypeAuthorizeConfig =
    { idTag : String
    }


type alias CPModuleActionsActionTypeStartTransactionConfig =
    { connector : Int
    , idTag : String
    }


type alias CPModuleActionsActionTypeStopTransactionConfig =
    { idTag : String
    }


type CPModuleActionsActionTypeChargePeriodConfigSpeedup
    = IncreasePower Float
    | TimeDilation Float
    | None


type alias CPModuleActionsActionTypeChargePeriodConfig =
    { vehiclePowerCapacity : Int
    , period : Int
    , initialVehicleCharge : Float
    , vehicleBatteryCapacity : Int
    , speedup : CPModuleActionsActionTypeChargePeriodConfigSpeedup
    }


type alias CPModuleActionsActionTypeChargePeriodState =
    { realInterval : Int
    , speedupDilatedInterval : Float
    , periodLeft : Int
    , vehicleCharge : Float
    , power : Int
    , speedupIncreasedPower : Float
    , powerOffered : Int
    }


type alias CPModuleActionsActionTypeDelayConfig =
    { interval : Int
    }


type CPModuleActionsActionType
    = STATUS_CHANGE CPModuleActionsActionTypeStatusChangeConfig
    | AUTHORIZE CPModuleActionsActionTypeAuthorizeConfig
    | START_TRANSACTION CPModuleActionsActionTypeStartTransactionConfig
    | STOP_TRANSACTION CPModuleActionsActionTypeStopTransactionConfig
    | CHARGE_PERIOD CPModuleActionsActionTypeChargePeriodConfig (Maybe CPModuleActionsActionTypeChargePeriodState)
    | DELAY CPModuleActionsActionTypeDelayConfig


type alias CPModuleActionsAction =
    { status : CPModuleActionsActionStatus
    , typ : CPModuleActionsActionType
    }


type alias CPModuleActionsBatch =
    { actions : List CPModuleActionsAction
    }


type alias CPModuleActionsConfig =
    { initialQueue : Maybe CPModuleActionsBatch
    }


type alias CPModuleActionsState =
    { startedTransactionId : Maybe String
    , startedTransactionConnector : Maybe Int
    , queue : List CPModuleActionsBatch
    , status : CPModuleActionsStateStatus
    }


type CPModuleActionsStateStatus
    = Idle
    | Executing { instructionPointer : ( Int, Int ) }


cpModulesActionsDecoder : D.Decoder (Maybe CPModuleActions)
cpModulesActionsDecoder =
    D.nullable
        (D.succeed CPModuleActions
            |> required "config" configDecoder
            |> required "state" stateDecoder
        )


configDecoder : D.Decoder CPModuleActionsConfig
configDecoder =
    D.succeed CPModuleActionsConfig
        |> required "initial_queue" (D.maybe batchDecoder)


stateDecoder : D.Decoder CPModuleActionsState
stateDecoder =
    D.succeed CPModuleActionsState
        |> required "started_transaction_id" (D.nullable D.string)
        |> required "started_transaction_connector" (D.nullable D.int)
        |> required "queue" (D.list batchDecoder)
        |> custom stateStatusDecoder


stateStatusDecoder : D.Decoder CPModuleActionsStateStatus
stateStatusDecoder =
    D.field "status" D.string
        |> D.andThen
            (\s ->
                case s of
                    "idle" ->
                        D.succeed Idle

                    "executing" ->
                        D.map Executing
                            (D.succeed (\ip -> { instructionPointer = ip })
                                |> required "instruction_pointer" (D.map2 Tuple.pair (D.field "batch_ind" D.int) (D.field "action_ind" D.int))
                            )

                    other ->
                        D.fail ("Unexpected actions state status " ++ other)
            )


batchDecoder : D.Decoder CPModuleActionsBatch
batchDecoder =
    D.succeed CPModuleActionsBatch
        |> required "actions" (D.list actionDecoder)


actionDecoder : D.Decoder CPModuleActionsAction
actionDecoder =
    D.succeed CPModuleActionsAction
        |> required "status" actionStatusDecoder
        |> custom actionTypeDecoder


actionTypeDecoder : D.Decoder CPModuleActionsActionType
actionTypeDecoder =
    D.field "type" D.string
        |> D.andThen
            (\t ->
                case t of
                    "status_change" ->
                        D.succeed STATUS_CHANGE
                            |> required "config"
                                (D.succeed CPModuleActionsActionTypeStatusChangeConfig
                                    |> required "connector" D.int
                                    |> required "status" OCPPConnectorStatus.decoder
                                )

                    "authorize" ->
                        D.succeed AUTHORIZE
                            |> required "config"
                                (D.succeed CPModuleActionsActionTypeAuthorizeConfig
                                    |> required "id_tag" D.string
                                )

                    "start_transaction" ->
                        D.succeed START_TRANSACTION
                            |> required "config"
                                (D.succeed CPModuleActionsActionTypeStartTransactionConfig
                                    |> required "connector" D.int
                                    |> required "id_tag" D.string
                                )

                    "stop_transaction" ->
                        D.succeed STOP_TRANSACTION
                            |> required "config"
                                (D.succeed CPModuleActionsActionTypeStopTransactionConfig
                                    |> required "id_tag" D.string
                                )

                    "charge_period" ->
                        D.succeed CHARGE_PERIOD
                            |> required "config"
                                (D.succeed CPModuleActionsActionTypeChargePeriodConfig
                                    |> required "vehicle_power_capacity" D.int
                                    |> required "period" D.int
                                    |> required "initial_vehicle_charge" D.float
                                    |> required "vehicle_battery_capacity" D.int
                                    |> custom actionTypeChargePeriodSpeedupDecoder
                                )
                            |> required "state"
                                (D.maybe
                                    (D.succeed CPModuleActionsActionTypeChargePeriodState
                                        |> required "real_interval" D.int
                                        |> required "speedup_dilated_interval" D.float
                                        |> required "period_left" D.int
                                        |> required "vehicle_charge" D.float
                                        |> required "power" D.int
                                        |> required "speedup_increased_power" D.float
                                        |> required "power_offered" D.int
                                    )
                                )

                    "delay" ->
                        D.succeed DELAY
                            |> required "config"
                                (D.succeed CPModuleActionsActionTypeDelayConfig
                                    |> required "interval" D.int
                                )

                    other ->
                        D.fail ("Unexpected action type " ++ other)
            )


actionTypeChargePeriodSpeedupDecoder : D.Decoder CPModuleActionsActionTypeChargePeriodConfigSpeedup
actionTypeChargePeriodSpeedupDecoder =
    D.field "speedup_method" (D.maybe D.string)
        |> D.andThen
            (\t ->
                case t of
                    Just "increase_power" ->
                        D.succeed IncreasePower
                            |> required "speedup" D.float

                    Just "time_dilation" ->
                        D.succeed TimeDilation
                            |> required "speedup" D.float

                    Nothing ->
                        D.succeed None

                    Just other ->
                        D.fail ("Unexpected speedup method " ++ other)
            )


actionTypeToString : CPModuleActionsActionType -> String
actionTypeToString typ =
    case typ of
        STATUS_CHANGE _ ->
            "status_change"

        AUTHORIZE _ ->
            "authorize"

        START_TRANSACTION _ ->
            "start_transaction"

        STOP_TRANSACTION _ ->
            "stop_transaction"

        CHARGE_PERIOD _ _ ->
            "charge_period"

        DELAY _ ->
            "delay"


actionStatusDecoder : D.Decoder CPModuleActionsActionStatus
actionStatusDecoder =
    D.string
        |> D.andThen
            (\s ->
                case s of
                    "idle" ->
                        D.succeed IDLE

                    "in_progress" ->
                        D.succeed IN_PROGRESS

                    "done" ->
                        D.succeed DONE

                    other ->
                        D.fail ("Unexpected action status " ++ other)
            )


actionStatusToString : CPModuleActionsActionStatus -> String
actionStatusToString status =
    case status of
        IDLE ->
            "idle"

        IN_PROGRESS ->
            "in_progress"

        DONE ->
            "done"


configEncoder : CPModuleActionsConfig -> E.Value
configEncoder cfg =
    E.object
        [ ( "initial_queue", maybeBatchEncoder cfg.initialQueue )
        ]


maybeBatchEncoder : Maybe CPModuleActionsBatch -> E.Value
maybeBatchEncoder maybeBatch =
    Maybe.map batchEncoder maybeBatch
        |> Maybe.withDefault E.null


batchEncoder : CPModuleActionsBatch -> E.Value
batchEncoder batch =
    if List.isEmpty batch.actions then
        E.null

    else
        E.object
            [ ( "actions", E.list actionEncoder batch.actions )
            ]


actionEncoder : CPModuleActionsAction -> E.Value
actionEncoder action =
    E.object
        [ ( "type", E.string <| actionTypeToString action.typ )
        , ( "config", actionConfigEncoder action.typ )
        ]


actionConfigEncoder : CPModuleActionsActionType -> E.Value
actionConfigEncoder typ =
    case typ of
        STATUS_CHANGE cfg ->
            E.object
                [ ( "connector", E.int cfg.connector )
                , ( "status", OCPPConnectorStatus.encoder cfg.status )
                ]

        AUTHORIZE cfg ->
            E.object [ ( "id_tag", E.string cfg.idTag ) ]

        START_TRANSACTION cfg ->
            E.object
                [ ( "connector", E.int cfg.connector )
                , ( "id_tag", E.string cfg.idTag )
                ]

        STOP_TRANSACTION cfg ->
            E.object [ ( "id_tag", E.string cfg.idTag ) ]

        CHARGE_PERIOD cfg _ ->
            E.object
                [ ( "vehicle_power_capacity", E.int cfg.vehiclePowerCapacity )
                , ( "period", E.int cfg.period )
                , ( "initial_vehicle_charge", E.float cfg.initialVehicleCharge )
                , ( "vehicle_battery_capacity", E.int cfg.vehicleBatteryCapacity )
                , ( "speedup", actionConfigChargePeriodSpeedupEncoder cfg.speedup )
                , ( "speedup_method", actionConfigChargePeriodSpeedupMethodEncoder cfg.speedup )
                ]

        DELAY cfg ->
            E.object [ ( "interval", E.int cfg.interval ) ]


actionConfigChargePeriodSpeedupEncoder : CPModuleActionsActionTypeChargePeriodConfigSpeedup -> E.Value
actionConfigChargePeriodSpeedupEncoder speedup =
    case speedup of
        IncreasePower coeff ->
            E.float coeff

        TimeDilation coeff ->
            E.float coeff

        None ->
            E.null


actionConfigChargePeriodSpeedupMethodEncoder : CPModuleActionsActionTypeChargePeriodConfigSpeedup -> E.Value
actionConfigChargePeriodSpeedupMethodEncoder speedup =
    case speedup of
        IncreasePower _ ->
            E.string "increase_power"

        TimeDilation _ ->
            E.string "time_dilation"

        None ->
            E.null
