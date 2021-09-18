module CP.Modules.Actions exposing (CPModuleActions, CPModuleActionsConfig, configEncoder, cpModulesActionsDecoder)

import Json.Decode as D
import Json.Decode.Extra as DE
import Json.Decode.Pipeline exposing (custom, hardcoded, optional, required)
import Json.Encode as E


type alias CPModuleActions =
    { config : CPModuleActionsConfig
    , state : CPModuleActionsState
    }


type CPModuleActionsActionType
    = STATUS_CHANGE
    | AUTHORIZE
    | START_TRANSACTION
    | STOP_TRANSACTION
    | CHARGE_PERIOD
    | DELAY


type CPModuleActionsActionStatus
    = IDLE
    | IN_PROGRESS
    | DONE


type alias CPModuleActionsAction =
    { typ : CPModuleActionsActionType
    , status : CPModuleActionsActionStatus
    , config : D.Value
    , state : D.Value
    }


type alias CPModuleActionsBatch =
    { actions : List CPModuleActionsAction
    }


type alias CPModuleActionsConfig =
    { initialQueue : List CPModuleActionsBatch
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
        |> required "initial_queue" (D.list batchDecoder)


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
        |> required "type" actionTypeDecoder
        |> required "status" actionStatusDecoder
        |> required "config" D.value
        |> required "state" D.value


actionTypeDecoder : D.Decoder CPModuleActionsActionType
actionTypeDecoder =
    D.string
        |> D.andThen
            (\t ->
                case t of
                    "status_change" ->
                        D.succeed STATUS_CHANGE

                    "authorize" ->
                        D.succeed AUTHORIZE

                    "start_transaction" ->
                        D.succeed START_TRANSACTION

                    "stop_transaction" ->
                        D.succeed STOP_TRANSACTION

                    "charge_period" ->
                        D.succeed CHARGE_PERIOD

                    "delay" ->
                        D.succeed DELAY

                    other ->
                        D.fail ("Unexpected action type " ++ other)
            )


actionTypeToString : CPModuleActionsActionType -> String
actionTypeToString typ =
    case typ of
        STATUS_CHANGE ->
            "status_change"

        AUTHORIZE ->
            "authorize"

        START_TRANSACTION ->
            "start_transaction"

        STOP_TRANSACTION ->
            "stop_transaction"

        CHARGE_PERIOD ->
            "charge_period"

        DELAY ->
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
        [ ( "initial_queue", E.list batchEncoder cfg.initialQueue )
        ]


batchEncoder : CPModuleActionsBatch -> E.Value
batchEncoder batch =
    E.object
        [ ( "actions", E.list actionEncoder batch.actions )
        ]



-- TODO:


actionEncoder : CPModuleActionsAction -> E.Value
actionEncoder action =
    E.object
        [ ( "type", E.string <| actionTypeToString action.typ )
        , ( "status", E.string <| actionStatusToString action.status )
        ]
