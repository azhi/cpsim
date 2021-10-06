module Page.LaunchCP exposing (Model, Msg, init, subscriptions, toSession, update, view)

import CP exposing (CP, cpDecoder)
import CP.InternalConfig exposing (CPInternalConfig)
import CP.Modules.Actions as A exposing (CPModuleActionsAction, CPModuleActionsActionTypeChargePeriodConfigSpeedup, CPModuleActionsBatch, CPModuleActionsConfig)
import CP.Modules.Commands as C exposing (CPModuleCommandsConfig)
import CP.Modules.Connection exposing (CPModuleConnectionConfig)
import CP.Modules.Heartbeat exposing (CPModuleHeartbeatConfig)
import CP.Modules.Status exposing (CPModuleStatusConfig)
import CP.Modules.Status.OCPPConnectorStatus as CS
import CP.Modules.Status.OCPPStatus as S
import CP.OCPPConfig exposing (CPOCPPConfig, CPOCPPConfigItem)
import Css
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (checked, class, classList, css, disabled, for, id, multiple, selected, type_, value)
import Html.Styled.Events exposing (on, onCheck, onClick, onInput)
import Http
import Json.Decode as D
import Json.Encode as E
import Session exposing (Session)



-- MODEL


type alias Model =
    { session : Session
    , internalConfig : CPInternalConfig
    , ocppConfig : CPOCPPConfig
    , connectionModule : CPModuleConnectionConfig
    , statusModule : CPModuleStatusConfig
    , actionsModuleForm : Maybe ( CPModuleActionsConfig, ActionsFormModel )
    , commandsModule : Maybe CPModuleCommandsConfig
    , heartbeatModule : Maybe CPModuleHeartbeatConfig
    }


type ActionsFormModelTab
    = Template
    | Actions


type alias ActionsFormModel =
    { actions : List CPModuleActionsAction
    , selectedTab : ActionsFormModelTab
    }


type Status a
    = Loading
    | LoadingSlowly
    | Loaded a
    | Failed



-- DEFAULTS


defaultInternalConfig : CPInternalConfig
defaultInternalConfig =
    CPInternalConfig "SIM1" "CPSIM" "2CON" Nothing 2 [ 1000.0, 10000.0 ] 75000 "ws://localhost:9292"


defaultOcppConfig : CPOCPPConfig
defaultOcppConfig =
    CPOCPPConfig [ CPOCPPConfigItem "test" (Just "1,2,3") False ]


defaultOcppConfigItem : CPOCPPConfigItem
defaultOcppConfigItem =
    CPOCPPConfigItem "" Nothing False


defaultConnectionModule : CPModuleConnectionConfig
defaultConnectionModule =
    CPModuleConnectionConfig 10 60 10 5


defaultStatusModule : CPModuleStatusConfig
defaultStatusModule =
    CPModuleStatusConfig S.AVAILABLE [ CS.AVAILABLE, CS.AVAILABLE ]


defaultActionsModule : CPModuleActionsConfig
defaultActionsModule =
    CPModuleActionsConfig <|
        Just <|
            CPModuleActionsBatch
                [ A.CPModuleActionsAction A.IDLE (A.DELAY { interval = 2 })
                , A.CPModuleActionsAction A.IDLE (A.STATUS_CHANGE { connector = 1, status = CS.PREPARING })
                , A.CPModuleActionsAction A.IDLE (A.DELAY { interval = 2 })
                , A.CPModuleActionsAction A.IDLE (A.AUTHORIZE { idTag = "123" })
                , A.CPModuleActionsAction A.IDLE (A.DELAY { interval = 2 })
                , A.CPModuleActionsAction A.IDLE (A.STATUS_CHANGE { connector = 1, status = CS.CHARGING })
                , A.CPModuleActionsAction A.IDLE (A.START_TRANSACTION { connector = 1, idTag = "123" })
                , A.CPModuleActionsAction A.IDLE (A.CHARGE_PERIOD { initialVehicleCharge = 5000, period = 60, speedup = A.IncreasePower 10.0, vehicleBatteryCapacity = 50000, vehiclePowerCapacity = 10000 } Nothing)
                , A.CPModuleActionsAction A.IDLE (A.DELAY { interval = 5 })
                , A.CPModuleActionsAction A.IDLE (A.STATUS_CHANGE { connector = 1, status = CS.FINISHING })
                , A.CPModuleActionsAction A.IDLE (A.DELAY { interval = 2 })
                , A.CPModuleActionsAction A.IDLE (A.STOP_TRANSACTION { idTag = "123" })
                ]


defaultActionsForm : ActionsFormModel
defaultActionsForm =
    ActionsFormModel
        [ A.CPModuleActionsAction A.IDLE (A.DELAY { interval = 2 })
        , A.CPModuleActionsAction A.IDLE (A.STATUS_CHANGE { connector = 1, status = CS.PREPARING })
        , A.CPModuleActionsAction A.IDLE (A.DELAY { interval = 2 })
        , A.CPModuleActionsAction A.IDLE (A.AUTHORIZE { idTag = "123" })
        , A.CPModuleActionsAction A.IDLE (A.DELAY { interval = 2 })
        , A.CPModuleActionsAction A.IDLE (A.STATUS_CHANGE { connector = 1, status = CS.CHARGING })
        , A.CPModuleActionsAction A.IDLE (A.START_TRANSACTION { connector = 1, idTag = "123" })
        , A.CPModuleActionsAction A.IDLE (A.CHARGE_PERIOD { initialVehicleCharge = 5000, period = 60, speedup = A.IncreasePower 10.0, vehicleBatteryCapacity = 50000, vehiclePowerCapacity = 10000 } Nothing)
        , A.CPModuleActionsAction A.IDLE (A.DELAY { interval = 5 })
        , A.CPModuleActionsAction A.IDLE (A.STATUS_CHANGE { connector = 1, status = CS.FINISHING })
        , A.CPModuleActionsAction A.IDLE (A.DELAY { interval = 2 })
        , A.CPModuleActionsAction A.IDLE (A.STOP_TRANSACTION { idTag = "123" })
        ]
        Template


defaultCommandsModule : CPModuleCommandsConfig
defaultCommandsModule =
    CPModuleCommandsConfig
        [ C.CHANGE_CONFIGURATION
        , C.GET_CONFIGURATION
        , C.RESET
        , C.TRIGGER_MESSAGE
        ]


defaultHeartbeatModule : CPModuleHeartbeatConfig
defaultHeartbeatModule =
    CPModuleHeartbeatConfig 600


init : Session -> ( Model, Cmd Msg )
init session =
    ( Model session defaultInternalConfig defaultOcppConfig defaultConnectionModule defaultStatusModule (Just ( defaultActionsModule, defaultActionsForm )) (Just defaultCommandsModule) (Just defaultHeartbeatModule)
    , Cmd.none
    )



-- UPDATE


type InternalConfigMsg
    = GotIdentity String
    | GotVendor String
    | GotModel String
    | GotFwVersion String
    | GotConnectorsCount Int
    | GotConnectorMeter Int Float
    | GotPowerLimit Int
    | GotWsEndpoint String


type OCPPConfigMsg
    = GotKey Int String
    | GotValue Int String
    | GotReadonly Int Bool
    | RemoveOCPPConfigItem Int
    | NewOCPPConfigItem



-- TODO: Actions form


type CPModulesMsg
    = GotConnectionCallTimeout Int
    | GotConnectionDefaultRetry Int
    | GotConnectionHardReboot Int
    | GotConnectionSoftReboot Int
    | GotStatusInitial S.OCPPStatus
    | GotStatusConnectorInitial Int CS.OCPPConnectorStatus
    | GotCommandsToggle Bool
    | GotCommandsSupportedItems (List C.CPModuleCommandsCommand)
    | GotHeartbeatToggle Bool
    | GotHeartbeatDefaultInterval Int
    | GotActionsToggle Bool


type ActionFormMsg
    = SwitchToTab ActionsFormModelTab
    | GotStatusChangeConnector Int A.CPModuleActionsActionTypeStatusChangeConfig Int
    | GotStatusChangeStatus Int A.CPModuleActionsActionTypeStatusChangeConfig CS.OCPPConnectorStatus
    | GotAuthorizeIdTag Int A.CPModuleActionsActionTypeAuthorizeConfig String
    | GotStartTransactionConnector Int A.CPModuleActionsActionTypeStartTransactionConfig Int
    | GotStartTransactionIdTag Int A.CPModuleActionsActionTypeStartTransactionConfig String
    | GotStopTransactionIdTag Int A.CPModuleActionsActionTypeStopTransactionConfig String
    | GotChargePeriodVehiclePowerCapacity Int A.CPModuleActionsActionTypeChargePeriodConfig Int
    | GotChargePeriodPeriod Int A.CPModuleActionsActionTypeChargePeriodConfig Int
    | GotChargePeriodVehicleBatteryCapacity Int A.CPModuleActionsActionTypeChargePeriodConfig Int
    | GotChargePeriodInitialVehicleCharge Int A.CPModuleActionsActionTypeChargePeriodConfig Float
    | GotChargePeriodSpeedup Int A.CPModuleActionsActionTypeChargePeriodConfig A.CPModuleActionsActionTypeChargePeriodConfigSpeedup
    | GotDelayInterval Int A.CPModuleActionsActionTypeDelayConfig Int


type Msg
    = InternalConfig InternalConfigMsg
    | OCPPConfig OCPPConfigMsg
    | CPModules CPModulesMsg
    | ActionForm ActionFormMsg
    | Submit
    | CPLaunched (Result Http.Error CP)


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        InternalConfig subMsg ->
            updateInternalConfig subMsg model

        OCPPConfig subMsg ->
            updateOCPPConfig subMsg model

        CPModules subMsg ->
            updateCPModules subMsg model

        ActionForm subMsg ->
            updateActionForm subMsg model

        Submit ->
            ( model, submitLaunch model )

        CPLaunched _ ->
            -- TODO:
            ( model, Cmd.none )


updateInternalConfig : InternalConfigMsg -> Model -> ( Model, Cmd Msg )
updateInternalConfig msg model =
    case ( model, msg ) of
        ( { internalConfig }, GotIdentity str ) ->
            ( { model | internalConfig = { internalConfig | identity = str } }, Cmd.none )

        ( { internalConfig }, GotVendor str ) ->
            ( { model | internalConfig = { internalConfig | vendor = str } }, Cmd.none )

        ( { internalConfig }, GotModel str ) ->
            ( { model | internalConfig = { internalConfig | model = str } }, Cmd.none )

        ( { internalConfig }, GotFwVersion str ) ->
            ( { model | internalConfig = { internalConfig | fwVersion = formMaybeStr str } }, Cmd.none )

        ( { internalConfig }, GotConnectorsCount int ) ->
            ( { model | internalConfig = { internalConfig | connectorsCount = int } } |> updateConnectorsCount, Cmd.none )

        ( { internalConfig }, GotConnectorMeter ind meter ) ->
            ( { model | internalConfig = { internalConfig | connectorMeters = listReplaceOnInd ind meter internalConfig.connectorMeters } }, Cmd.none )

        ( { internalConfig }, GotPowerLimit int ) ->
            ( { model | internalConfig = { internalConfig | powerLimit = int } }, Cmd.none )

        ( { internalConfig }, GotWsEndpoint str ) ->
            ( { model | internalConfig = { internalConfig | wsEndpoint = str } }, Cmd.none )


updateConnectorsCount : Model -> Model
updateConnectorsCount model =
    let
        connectorsCount =
            model.internalConfig.connectorsCount
    in
    case model of
        { internalConfig, statusModule } ->
            { model
                | internalConfig = { internalConfig | connectorMeters = listClampOrAddLength connectorsCount 0.0 internalConfig.connectorMeters }
                , statusModule = { statusModule | initialConnectorStatuses = listClampOrAddLength connectorsCount CS.AVAILABLE statusModule.initialConnectorStatuses }
            }


updateOCPPConfig : OCPPConfigMsg -> Model -> ( Model, Cmd Msg )
updateOCPPConfig msg model =
    case ( model, msg ) of
        ( { ocppConfig }, GotKey ind str ) ->
            ( { model | ocppConfig = { ocppConfig | items = listUpdateOnInd ind (\ci -> { ci | key = str }) ocppConfig.items } }, Cmd.none )

        ( { ocppConfig }, GotValue ind str ) ->
            ( { model | ocppConfig = { ocppConfig | items = listUpdateOnInd ind (\ci -> { ci | value = formMaybeStr str }) ocppConfig.items } }, Cmd.none )

        ( { ocppConfig }, GotReadonly ind bool ) ->
            ( { model | ocppConfig = { ocppConfig | items = listUpdateOnInd ind (\ci -> { ci | readonly = bool }) ocppConfig.items } }, Cmd.none )

        ( { ocppConfig }, RemoveOCPPConfigItem ind ) ->
            ( { model | ocppConfig = { ocppConfig | items = List.take ind ocppConfig.items ++ List.drop (ind + 1) ocppConfig.items } }, Cmd.none )

        ( { ocppConfig }, NewOCPPConfigItem ) ->
            ( { model | ocppConfig = { ocppConfig | items = ocppConfig.items ++ [ defaultOcppConfigItem ] } }, Cmd.none )


updateCPModules : CPModulesMsg -> Model -> ( Model, Cmd Msg )
updateCPModules msg model =
    case ( model, msg ) of
        ( { connectionModule }, GotConnectionCallTimeout int ) ->
            ( { model | connectionModule = { connectionModule | callTimeoutInterval = int } }, Cmd.none )

        ( { connectionModule }, GotConnectionDefaultRetry int ) ->
            ( { model | connectionModule = { connectionModule | defaultRetryInterval = int } }, Cmd.none )

        ( { connectionModule }, GotConnectionHardReboot int ) ->
            ( { model | connectionModule = { connectionModule | hardRebootInterval = int } }, Cmd.none )

        ( { connectionModule }, GotConnectionSoftReboot int ) ->
            ( { model | connectionModule = { connectionModule | softRebootInterval = int } }, Cmd.none )

        ( { statusModule }, GotStatusInitial status ) ->
            ( { model | statusModule = { statusModule | initialStatus = status } }, Cmd.none )

        ( { statusModule }, GotStatusConnectorInitial ind status ) ->
            ( { model | statusModule = { statusModule | initialConnectorStatuses = listReplaceOnInd ind status statusModule.initialConnectorStatuses } }, Cmd.none )

        ( _, GotCommandsToggle bool ) ->
            if bool then
                ( { model | commandsModule = Just defaultCommandsModule }, Cmd.none )

            else
                ( { model | commandsModule = Nothing }, Cmd.none )

        ( { commandsModule }, GotCommandsSupportedItems items ) ->
            ( { model | commandsModule = Maybe.map (\cm -> { cm | supportedCommands = items }) commandsModule }, Cmd.none )

        ( _, GotHeartbeatToggle bool ) ->
            if bool then
                ( { model | heartbeatModule = Just defaultHeartbeatModule }, Cmd.none )

            else
                ( { model | heartbeatModule = Nothing }, Cmd.none )

        ( { heartbeatModule }, GotHeartbeatDefaultInterval int ) ->
            ( { model | heartbeatModule = Maybe.map (\hm -> { hm | defaultInterval = int }) heartbeatModule }, Cmd.none )

        ( _, GotActionsToggle bool ) ->
            if bool then
                ( { model | actionsModuleForm = Just ( defaultActionsModule, defaultActionsForm ) }, Cmd.none )

            else
                ( { model | actionsModuleForm = Nothing }, Cmd.none )


updateActionForm : ActionFormMsg -> Model -> ( Model, Cmd Msg )
updateActionForm msg model =
    case ( model, msg ) of
        ( { actionsModuleForm }, SwitchToTab tab ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> updateActionFormComponent (\af -> { af | selectedTab = tab }) amf) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotStatusChangeConnector ind cfg int ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.STATUS_CHANGE { cfg | connector = int })) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotStatusChangeStatus ind cfg status ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.STATUS_CHANGE { cfg | status = status })) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotAuthorizeIdTag ind cfg str ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.AUTHORIZE { cfg | idTag = str })) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotStartTransactionConnector ind cfg int ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.START_TRANSACTION { cfg | connector = int })) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotStartTransactionIdTag ind cfg str ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.START_TRANSACTION { cfg | idTag = str })) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotStopTransactionIdTag ind cfg str ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.STOP_TRANSACTION { cfg | idTag = str })) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotChargePeriodVehiclePowerCapacity ind cfg int ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.CHARGE_PERIOD { cfg | vehiclePowerCapacity = int } Nothing)) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotChargePeriodPeriod ind cfg int ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.CHARGE_PERIOD { cfg | period = int } Nothing)) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotChargePeriodVehicleBatteryCapacity ind cfg int ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.CHARGE_PERIOD { cfg | vehicleBatteryCapacity = int } Nothing)) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotChargePeriodInitialVehicleCharge ind cfg float ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.CHARGE_PERIOD { cfg | initialVehicleCharge = float } Nothing)) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotChargePeriodSpeedup ind cfg speedup ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.CHARGE_PERIOD { cfg | speedup = speedup } Nothing)) |> updateActionModuleList) actionsModuleForm }, Cmd.none )

        ( { actionsModuleForm }, GotDelayInterval ind cfg int ) ->
            ( { model | actionsModuleForm = Maybe.map (\amf -> amf |> updateActionFormComponent (updateActionFormAction ind (A.DELAY { cfg | interval = int })) |> updateActionModuleList) actionsModuleForm }, Cmd.none )


updateActionModuleList : ( CPModuleActionsConfig, ActionsFormModel ) -> ( CPModuleActionsConfig, ActionsFormModel )
updateActionModuleList ( am, af ) =
    ( { am | initialQueue = Just <| CPModuleActionsBatch af.actions }, af )


updateActionFormComponent : (ActionsFormModel -> ActionsFormModel) -> ( CPModuleActionsConfig, ActionsFormModel ) -> ( CPModuleActionsConfig, ActionsFormModel )
updateActionFormComponent fn ( am, af ) =
    ( am, fn af )


updateActionFormAction : Int -> A.CPModuleActionsActionType -> ActionsFormModel -> ActionsFormModel
updateActionFormAction ind typ af =
    { af | actions = listUpdateOnInd ind (\x -> { x | typ = typ }) af.actions }


listReplaceOnInd : Int -> a -> List a -> List a
listReplaceOnInd ind value list =
    List.indexedMap
        (\currentInd currentValue ->
            if currentInd == ind then
                value

            else
                currentValue
        )
        list


listUpdateOnInd : Int -> (a -> a) -> List a -> List a
listUpdateOnInd ind upd list =
    List.indexedMap
        (\currentInd currentValue ->
            if currentInd == ind then
                upd currentValue

            else
                currentValue
        )
        list


listUniqueAdd : a -> List a -> List a
listUniqueAdd item list =
    if List.member item list then
        list

    else
        item :: list


formMaybeStr : String -> Maybe String
formMaybeStr str =
    if String.isEmpty str then
        Nothing

    else
        Just str


listClampOrAddLength : Int -> a -> List a -> List a
listClampOrAddLength length default list =
    let
        list_length =
            List.length list
    in
    if list_length == length then
        list

    else if list_length < length then
        list ++ List.repeat (length - list_length) default

    else
        List.take length list



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- REQUESTS


submitLaunch : Model -> Cmd Msg
submitLaunch model =
    Http.post
        { url = "/api/cp"
        , body = Http.jsonBody <| launchParams model
        , expect = Http.expectJson CPLaunched cpDecoder
        }


launchParams : Model -> E.Value
launchParams model =
    E.object
        [ ( "internal_config", CP.InternalConfig.configEncoder model.internalConfig )
        , ( "ocpp_config", CP.OCPPConfig.configEncoder model.ocppConfig )
        , ( "modules"
          , E.object <|
                [ ( "connection", CP.Modules.Connection.configEncoder model.connectionModule )
                , ( "status", CP.Modules.Status.configEncoder model.statusModule )
                ]
                    ++ launchParamsMaybeModule model.commandsModule "commands" C.configEncoder
                    ++ launchParamsMaybeModule model.heartbeatModule "heartbeat" CP.Modules.Heartbeat.configEncoder
                    ++ launchParamsMaybeModule model.actionsModuleForm "actions" (Tuple.first >> A.configEncoder)
          )
        ]


launchParamsMaybeModule : Maybe a -> String -> (a -> E.Value) -> List ( String, E.Value )
launchParamsMaybeModule maybe key encoder =
    maybe
        |> Maybe.map encoder
        |> Maybe.map (\v -> [ ( key, v ) ])
        |> Maybe.withDefault []



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "CPSIM"
    , content =
        div [ class "container" ]
            [ form []
                [ viewInternalConfigForm model.internalConfig
                , viewOcppConfigForm model.ocppConfig
                , viewConnectionModuleForm model.connectionModule
                , viewStatusModuleForm model.statusModule
                , viewMaybeCommandsModuleForm model.commandsModule
                , viewMaybeHeartbeatModuleForm model.heartbeatModule
                , viewMaybeActionsModuleForm model.actionsModuleForm
                , viewSubmit
                ]
            ]
    }


viewInternalConfigForm : CPInternalConfig -> Html Msg
viewInternalConfigForm ic =
    fieldset []
        [ legend [] [ text "Internal Config" ]
        , viewTextInput "identity" "Identity" ic.identity (InternalConfig << GotIdentity)
        , viewTextInput "vendor" "Vendor" ic.vendor (InternalConfig << GotVendor)
        , viewTextInput "model" "Model" ic.model (InternalConfig << GotModel)
        , viewTextInput "fw_version" "Firmware Version" (Maybe.withDefault "" ic.fwVersion) (InternalConfig << GotFwVersion)
        , viewIntInput "connectors_count" "Connectors count" ic.connectorsCount (InternalConfig << GotConnectorsCount)
        , viewInternalConfigConnectorMeterInputs ic
        , viewIntInput "power_limit" "Power limit" ic.powerLimit (InternalConfig << GotPowerLimit)
        , viewTextInput "ws_endpoint" "Websocket endpoint URL" ic.wsEndpoint (InternalConfig << GotWsEndpoint)
        ]


viewInternalConfigConnectorMeterInputs : CPInternalConfig -> Html Msg
viewInternalConfigConnectorMeterInputs ic =
    div [ class "mb-3" ]
        [ label [ class "form-label" ] [ text "Connector meters" ]
        , div [ class "d-flex" ] <| List.indexedMap viewInternalConfigConnectorMeterInput ic.connectorMeters
        ]


viewInternalConfigConnectorMeterInput : Int -> Float -> Html Msg
viewInternalConfigConnectorMeterInput c v =
    let
        event =
            String.toFloat >> Maybe.withDefault v >> GotConnectorMeter c >> InternalConfig
    in
    input [ class "form-control mx-1", type_ "number", value (String.fromFloat v), onInput event ] []


viewOcppConfigForm : CPOCPPConfig -> Html Msg
viewOcppConfigForm oc =
    fieldset [] <|
        legend [] [ text "OCPP Config" ]
            :: List.indexedMap viewOcppConfigItemForm oc.items
            ++ [ viewOcppConfigItemAdd ]


viewOcppConfigItemForm : Int -> CPOCPPConfigItem -> Html Msg
viewOcppConfigItemForm ind ci =
    div [ class "mb-3 d-flex align-items-center" ]
        [ input [ class "form-control mx-1", type_ "text", value ci.key, onInput (GotKey ind >> OCPPConfig) ] []
        , input [ class "form-control mx-1", type_ "text", value (Maybe.withDefault "" ci.value), onInput (GotValue ind >> OCPPConfig) ] []
        , div [ class "form-check form-switch mx-1" ]
            [ input [ class "form-check-input", id ("ocpp_config_item_" ++ String.fromInt ind), type_ "checkbox", checked ci.readonly, onCheck (GotReadonly ind >> OCPPConfig) ] []
            , label [ class "form-check-label", for ("ocpp_config_item_" ++ String.fromInt ind) ] [ text "readonly" ]
            ]
        , button [ class "form-control mx-1", type_ "button", onClick (RemoveOCPPConfigItem ind |> OCPPConfig), css [ Css.borderStyle Css.none, Css.width (Css.px 100) ] ] [ i [ class "fas fa-times", css [ Css.color <| Css.hex "ff5555" ] ] [] ]
        ]


viewOcppConfigItemAdd : Html Msg
viewOcppConfigItemAdd =
    button [ class "form-control", type_ "button", onClick (NewOCPPConfigItem |> OCPPConfig), css [ Css.borderStyle Css.none ] ] [ i [ class "fas fa-plus" ] [ text "Add" ] ]


viewConnectionModuleForm : CPModuleConnectionConfig -> Html Msg
viewConnectionModuleForm cm =
    fieldset []
        [ legend [] [ text "Connection module" ]
        , viewIntInput "call_timeout_interval" "Call Timeout Interval" cm.callTimeoutInterval (GotConnectionCallTimeout >> CPModules)
        , viewIntInput "default_retry_interval" "Default Retry Interval" cm.defaultRetryInterval (GotConnectionDefaultRetry >> CPModules)
        , viewIntInput "hard_reboot_interval" "Hard Reboot Interval" cm.hardRebootInterval (GotConnectionHardReboot >> CPModules)
        , viewIntInput "soft_reboot_interval" "Soft Reboot Interval" cm.softRebootInterval (GotConnectionSoftReboot >> CPModules)
        ]


viewStatusModuleForm : CPModuleStatusConfig -> Html Msg
viewStatusModuleForm sm =
    fieldset []
        [ legend [] [ text "Status module" ]
        , div [ class "mb-3" ]
            [ label [ class "form-label" ] [ text "Initial OCPP Status" ]
            , viewTypedSelect S.options S.humanString S.fromString S.toString sm.initialStatus (GotStatusInitial >> CPModules)
            ]
        , div [ class "mb-3" ]
            [ label [ class "form-label" ] [ text "Connector OCPP Statuses" ]
            , div [ class "d-flex" ] <| List.indexedMap (\ind val -> viewTypedSelect CS.options CS.humanString CS.fromString CS.toString val (GotStatusConnectorInitial ind >> CPModules)) sm.initialConnectorStatuses
            ]
        ]


viewMaybeCommandsModuleForm : Maybe CPModuleCommandsConfig -> Html Msg
viewMaybeCommandsModuleForm cm =
    fieldset []
        (legend [ class "d-flex", disabled <| isModuleEnabled cm ]
            [ span [] [ text "Commands module" ]
            , div [ class "form-check form-switch mx-1" ]
                [ input [ class "form-check-input", id "command_module_enable", type_ "checkbox", checked <| isModuleEnabled cm, onCheck (GotCommandsToggle >> CPModules) ] []
                ]
            ]
            :: (Maybe.map viewCommandsModuleForm cm
                    |> Maybe.withDefault []
               )
        )


viewCommandsModuleForm : CPModuleCommandsConfig -> List (Html Msg)
viewCommandsModuleForm cm =
    [ div [ class "mb-3" ]
        [ label [ class "form-label" ] [ text "Supported commands" ]
        , viewMultipleTypedSelect C.options C.humanString C.fromString C.toString cm.supportedCommands (GotCommandsSupportedItems >> CPModules)
        ]
    ]


viewMaybeHeartbeatModuleForm : Maybe CPModuleHeartbeatConfig -> Html Msg
viewMaybeHeartbeatModuleForm hm =
    fieldset []
        (legend [ class "d-flex", disabled <| isModuleEnabled hm ]
            [ span [] [ text "Heartbeat module" ]
            , div [ class "form-check form-switch mx-1" ]
                [ input [ class "form-check-input", id "heartbeat_module_enable", type_ "checkbox", checked <| isModuleEnabled hm, onCheck (GotHeartbeatToggle >> CPModules) ] []
                ]
            ]
            :: (Maybe.map viewHeartbeatModuleForm hm
                    |> Maybe.withDefault []
               )
        )


viewHeartbeatModuleForm : CPModuleHeartbeatConfig -> List (Html Msg)
viewHeartbeatModuleForm hm =
    [ viewIntInput "default_heartbeat_interval" "Default interval" hm.defaultInterval (GotHeartbeatDefaultInterval >> CPModules)
    ]


viewMaybeActionsModuleForm : Maybe ( CPModuleActionsConfig, ActionsFormModel ) -> Html Msg
viewMaybeActionsModuleForm am =
    fieldset []
        (legend [ class "d-flex", disabled <| isModuleEnabled am ]
            [ span [] [ text "Actions module" ]
            , div [ class "form-check form-switch mx-1" ]
                [ input [ class "form-check-input", id "actions_module_enable", type_ "checkbox", checked <| isModuleEnabled am, onCheck (GotActionsToggle >> CPModules) ] []
                ]
            ]
            :: (Maybe.map viewActionsModuleForm am
                    |> Maybe.withDefault []
               )
        )


viewActionsModuleForm : ( CPModuleActionsConfig, ActionsFormModel ) -> List (Html Msg)
viewActionsModuleForm ( am, fm ) =
    [ div [ class "mb-3" ]
        [ label [ class "form-label" ] [ text "Initial actions queue" ]
        , viewActionsEditor fm
        ]
    ]


viewActionsEditor : ActionsFormModel -> Html Msg
viewActionsEditor fm =
    div [ class "d-flex" ]
        [ actionListForm fm.actions
        , actionListToolbox fm.selectedTab
        ]


actionListForm : List CPModuleActionsAction -> Html Msg
actionListForm actions =
    div [ class "p-3 bg-light flex-grow-1 me-3" ] <| List.indexedMap actionForm actions


actionForm : Int -> CPModuleActionsAction -> Html Msg
actionForm ind action =
    div [ class "border rounded-3" ]
        (span [] [ text <| actionTitle action ]
            :: actionInputs ind action
        )


actionTitle : CPModuleActionsAction -> String
actionTitle action =
    case action.typ of
        A.STATUS_CHANGE _ ->
            "Status Change"

        A.AUTHORIZE _ ->
            "Authorize"

        A.START_TRANSACTION _ ->
            "Start Transaction"

        A.STOP_TRANSACTION _ ->
            "Stop Transaction"

        A.CHARGE_PERIOD _ _ ->
            "Charge Period"

        A.DELAY _ ->
            "Delay"


actionInputs : Int -> CPModuleActionsAction -> List (Html Msg)
actionInputs ind action =
    case action.typ of
        A.STATUS_CHANGE cfg ->
            [ viewIntInput "connector" "Connector" cfg.connector (GotStatusChangeConnector ind cfg >> ActionForm)
            , div [ class "mb-3" ]
                [ label [ class "form-label" ] [ text "Connector OCPP Status" ]
                , viewTypedSelect CS.options CS.humanString CS.fromString CS.toString cfg.status (GotStatusChangeStatus ind cfg >> ActionForm)
                ]
            ]

        A.AUTHORIZE cfg ->
            [ viewTextInput "id_tag" "ID Tag" cfg.idTag (GotAuthorizeIdTag ind cfg >> ActionForm) ]

        A.START_TRANSACTION cfg ->
            [ viewIntInput "connector" "Connector" cfg.connector (GotStartTransactionConnector ind cfg >> ActionForm)
            , viewTextInput "id_tag" "ID Tag" cfg.idTag (GotStartTransactionIdTag ind cfg >> ActionForm)
            ]

        A.STOP_TRANSACTION cfg ->
            [ viewTextInput "id_tag" "ID Tag" cfg.idTag (GotStopTransactionIdTag ind cfg >> ActionForm) ]

        A.CHARGE_PERIOD cfg _ ->
            [ viewIntInput "vehicle_power_capacity" "Vehicle Power Capacity (Power Limit, W)" cfg.vehiclePowerCapacity (GotChargePeriodVehiclePowerCapacity ind cfg >> ActionForm)
            , viewIntInput "period" "Period (s)" cfg.period (GotChargePeriodPeriod ind cfg >> ActionForm)
            , viewIntInput "vehicle_battery_capacity" "Vehicle Battery Capacity (Charging Limit, Wh)" cfg.vehicleBatteryCapacity (GotChargePeriodVehicleBatteryCapacity ind cfg >> ActionForm)
            , viewFloatInput "initial_vehicle_charge" "Initial Vehicle Charge (Wh)" cfg.initialVehicleCharge (GotChargePeriodInitialVehicleCharge ind cfg >> ActionForm)

            -- TODO: speedup typed select
            ]
                ++ speedupCoeffInput ind cfg

        A.DELAY cfg ->
            [ viewIntInput "interval" "Interval" cfg.interval (GotDelayInterval ind cfg >> ActionForm) ]


speedupCoeffInput : Int -> A.CPModuleActionsActionTypeChargePeriodConfig -> List (Html Msg)
speedupCoeffInput ind cfg =
    case cfg.speedup of
        A.IncreasePower coeff ->
            [ viewFloatInput "speedup_increase_power_coeff" "Speedup coefficient (more than 1.0 means faster)" coeff (A.IncreasePower >> GotChargePeriodSpeedup ind cfg >> ActionForm) ]

        A.TimeDilation coeff ->
            [ viewFloatInput "speedup_time_dilation_coeff" "Speedup coefficient (more than 1.0 means faster)" coeff (A.IncreasePower >> GotChargePeriodSpeedup ind cfg >> ActionForm) ]

        A.None ->
            []


actionListToolbox : ActionsFormModelTab -> Html Msg
actionListToolbox tab =
    div []
        [ ul [ class "nav nav-tabs" ]
            [ li [ class "nav-item" ] [ button [ type_ "button", class "nav-link", classList [ ( "active", tab == Template ) ], onClick (SwitchToTab Template |> ActionForm) ] [ text "Templates" ] ]
            , li [ class "nav-item" ] [ button [ type_ "button", class "nav-link", classList [ ( "active", tab == Actions ) ], onClick (SwitchToTab Actions |> ActionForm) ] [ text "Actions" ] ]
            ]
        , actionListToolboxContent tab
        ]


actionListToolboxContent : ActionsFormModelTab -> Html Msg
actionListToolboxContent tab =
    case tab of
        Template ->
            div [] [ text "Template content" ]

        Actions ->
            div [] [ text "Actions content" ]


viewSubmit : Html Msg
viewSubmit =
    button [ type_ "button", class "form-control btn btn-primary", type_ "button", onClick Submit ] [ text "Launch" ]


isModuleEnabled : Maybe a -> Bool
isModuleEnabled maybe =
    case maybe of
        Just _ ->
            True

        Nothing ->
            False


viewTextInput : String -> String -> String -> (String -> Msg) -> Html Msg
viewTextInput n t v e =
    div [ class "mb-3" ]
        [ label [ class "form-label", for n ] [ text t ]
        , input [ class "form-control", id n, type_ "text", value v, onInput e ] []
        ]


viewIntInput : String -> String -> Int -> (Int -> Msg) -> Html Msg
viewIntInput n t v e =
    div [ class "mb-3" ]
        [ label [ class "form-label", for n ] [ text t ]
        , input [ class "form-control", id n, type_ "number", value (String.fromInt v), onInput (String.toInt >> Maybe.withDefault v >> e) ] []
        ]


viewFloatInput : String -> String -> Float -> (Float -> Msg) -> Html Msg
viewFloatInput n t v e =
    div [ class "mb-3" ]
        [ label [ class "form-label", for n ] [ text t ]
        , input [ class "form-control", id n, type_ "number", value (String.fromFloat v), onInput (String.toFloat >> Maybe.withDefault v >> e) ] []
        ]


viewTypedSelect : List a -> (a -> String) -> (String -> a) -> (a -> String) -> a -> (a -> Msg) -> Html Msg
viewTypedSelect options format from to v e =
    select [ class "mb-3 form-select", onInput (from >> e) ] <|
        List.map (viewTypedSelectOption format to v) options


viewTypedSelectOption : (a -> String) -> (a -> String) -> a -> a -> Html Msg
viewTypedSelectOption format to sel v =
    option [ value (to v), selected (v == sel) ] [ text (format v) ]


viewMultipleTypedSelect : List a -> (a -> String) -> (String -> a) -> (a -> String) -> List a -> (List a -> Msg) -> Html Msg
viewMultipleTypedSelect options format from to v e =
    select [ class "mb-3 form-select", multiple True, on "change" (viewMultipleTypedSelectDecoder from e) ] <|
        List.map (viewMultipleTypedSelectOption format to v) options


viewMultipleTypedSelectOption : (a -> String) -> (a -> String) -> List a -> a -> Html Msg
viewMultipleTypedSelectOption format to sel v =
    option [ value (to v), selected (List.member v sel) ] [ text (format v) ]


viewMultipleTypedSelectDecoder : (String -> a) -> (List a -> Msg) -> D.Decoder Msg
viewMultipleTypedSelectDecoder from event =
    D.at [ "target", "selectedOptions" ]
        (D.keyValuePairs <| D.field "value" D.string)
        |> D.andThen (D.succeed << event << List.map from << List.map Tuple.second)



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
