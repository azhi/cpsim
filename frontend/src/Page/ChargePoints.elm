module Page.ChargePoints exposing (Model, Msg, init, subscriptions, toSession, update, view)

import CP exposing (CP, cpDecoder)
import CP.InternalConfig exposing (CPInternalConfig)
import CP.Modules.Actions as A exposing (CPModuleActions, CPModuleActionsConfig, CPModuleActionsState)
import CP.Modules.Commands as C exposing (CPModuleCommands)
import CP.Modules.Connection exposing (CPModuleConnection, CPModuleConnectionConfig, CPModuleConnectionState(..), OCPPCall, OCPPCallStatus(..))
import CP.Modules.Heartbeat exposing (CPModuleHeartbeat, CPModuleHeartbeatConfig, CPModuleHeartbeatState)
import CP.Modules.Status exposing (CPModuleStatus, CPModuleStatusConfig, CPModuleStatusState, CPModuleStatusStateMaybeReported(..))
import CP.Modules.Status.OCPPConnectorStatus as CS
import CP.Modules.Status.OCPPStatus as S
import CP.OCPPConfig exposing (CPOCPPConfig)
import Css
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (attribute, class, classList, css)
import Html.Styled.Events exposing (onClick)
import Http
import Iso8601
import Json.Decode as D
import Json.Encode as E
import Page
import Phoenix
import Ports
import Route
import Session exposing (Session)
import Time



-- MODEL


type alias Model =
    { session : Session
    , phoenix : Phoenix.Model
    , cps : List CP
    , selectedCp : SelectedCP
    }


type SelectedCP
    = None
    | Loading String
    | Loaded CP



-- type Status a
--     = Loading
--     | LoadingSlowly
--     | Loaded a
--     | Failed


init : Session -> Maybe String -> ( Model, Cmd Msg )
init session routeSelectedCp =
    let
        ( selectedCp, fetchCpCmd ) =
            maybeSelectRouteCp routeSelectedCp

        phoenix =
            Phoenix.init Ports.config
    in
    ( { session = session, phoenix = phoenix, cps = [], selectedCp = selectedCp }
    , Cmd.batch [ fetchCpCmd, fetchCps ]
    )


maybeSelectRouteCp : Maybe String -> ( SelectedCP, Cmd Msg )
maybeSelectRouteCp routeSelectedCp =
    case routeSelectedCp of
        Nothing ->
            ( None, Cmd.none )

        Just identity ->
            ( Loading identity, fetchCp identity )



-- UPDATE


type Msg
    = PhoenixMsg Phoenix.Msg
    | GotCPs (Result Http.Error (List CP))
    | GotSelectedCP (Result Http.Error CP)
    | CPClicked CP


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PhoenixMsg subMsg ->
            let
                ( phoenix, phoenixCmd, phoenixMsg ) =
                    Phoenix.update subMsg model.phoenix

                _ =
                    Debug.log "phoenixMsg" phoenixMsg
            in
            ( { model | phoenix = phoenix }
            , Cmd.map PhoenixMsg phoenixCmd
            )

        GotCPs (Ok cps) ->
            ( { model | cps = cps }, Cmd.none )

        GotCPs (Err _) ->
            -- TODO: nice errors
            ( model, Cmd.none )

        GotSelectedCP (Ok cp) ->
            case model.selectedCp of
                Loading identity ->
                    if identity == cp.internalConfig.identity then
                        let
                            ( phoenix, phoenixCmd ) =
                                Phoenix.join ("cp:" ++ identity) model.phoenix

                            _ =
                                Debug.log "newPhoenix" phoenix

                            _ =
                                Debug.log "newPhoenixCmd" phoenixCmd
                        in
                        ( { model | selectedCp = Loaded cp, phoenix = phoenix }, Cmd.map PhoenixMsg phoenixCmd )

                    else
                        ( model, Cmd.none )

                _ ->
                    ( model, Cmd.none )

        GotSelectedCP (Err _) ->
            -- TODO: nice errors
            ( model, Cmd.none )

        CPClicked cp ->
            ( { model | selectedCp = Loaded cp }, Route.pushUrl (.navKey (toSession model)) (Route.ChargePoints (Just cp.internalConfig.identity)) )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    Sub.map PhoenixMsg <|
        Phoenix.subscriptions model.phoenix



-- REQUESTS


fetchCps : Cmd Msg
fetchCps =
    Http.get
        { url = "/api/cp"
        , expect = Http.expectJson GotCPs (D.list cpDecoder)
        }


fetchCp : String -> Cmd Msg
fetchCp identity =
    Http.get
        { url = "/api/cp/" ++ identity
        , expect = Http.expectJson GotSelectedCP cpDecoder
        }



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "CPSIM"
    , content =
        div [ class "container-fluid" ]
            [ div [ class "d-flex" ]
                [ viewSidebar model
                , maybeViewCp model
                ]
            ]
    }


viewSidebar : Model -> Html Msg
viewSidebar model =
    div [ class "d-flex flex-column", css [ Css.width (Css.px 380) ] ]
        [ div [ class "list-group list-group-flush scrollarea border-bottom" ]
            (viewSidebarCps model)
        ]


viewSidebarCps : Model -> List (Html Msg)
viewSidebarCps model =
    if List.length model.cps > 0 then
        List.map (viewSidebarCp model.selectedCp) model.cps

    else
        [ p [] [ text "No CPs" ] ]


viewSidebarCp : SelectedCP -> CP -> Html Msg
viewSidebarCp selectedCp cp =
    button [ class "list-group-item list-group-item-action py-3 lh-tight", classList [ ( "active", isSelectedCp selectedCp cp ) ], onClick (CPClicked cp) ]
        [ div [ class "w-100" ] [ strong [] [ text cp.internalConfig.identity ] ]
        , div [ class "col-10 mb-1 small" ] [ text (viewCpConnectionShortStr cp.modules.connection.state) ]
        ]


isSelectedCp : SelectedCP -> CP -> Bool
isSelectedCp selectedCp cp =
    case selectedCp of
        Loading identity ->
            identity == cp.internalConfig.identity

        Loaded scp ->
            scp.internalConfig.identity == cp.internalConfig.identity

        None ->
            False


viewCpConnectionShortStr : CPModuleConnectionState -> String
viewCpConnectionShortStr state =
    case state of
        Idle ->
            "idle"

        WSInit ->
            "WS Init"

        BootNotification _ ->
            "BootNotification sent"

        Pending _ ->
            "Pending"

        Retry { connectionError, retryAt } ->
            "Retry (" ++ connectionError ++ ")"

        Resetting _ ->
            "Resetting"

        Done _ ->
            "Connected"


viewStatusShortStr : (a -> String) -> CPModuleStatusStateMaybeReported a -> String
viewStatusShortStr humanizer maybeRepStatus =
    case maybeRepStatus of
        NOT_REPORTED st ->
            humanizer st ++ "?"

        REPORTED _ st ->
            humanizer st


viewHeartbeatShortStr : CPModuleHeartbeatState -> String
viewHeartbeatShortStr state =
    case Maybe.map2 Tuple.pair state.lastMessageAt state.lastHeartbeatAt of
        Just ( msg, hrt ) ->
            "at "
                ++ (Iso8601.fromTime <|
                        if Time.posixToMillis msg > Time.posixToMillis hrt then
                            msg

                        else
                            hrt
                   )

        Nothing ->
            case state.lastHeartbeatAt of
                Just hrt ->
                    "at " ++ Iso8601.fromTime hrt

                Nothing ->
                    case state.lastMessageAt of
                        Just msg ->
                            "at " ++ Iso8601.fromTime msg

                        Nothing ->
                            "not reported"


maybeViewCp : Model -> Html Msg
maybeViewCp model =
    case model.selectedCp of
        Loaded cp ->
            viewCp cp

        Loading _ ->
            div [ class "p-3" ] [ Page.loadingSpinner ]

        None ->
            div [ class "p-3" ] [ text "No CP Selected" ]


viewCp : CP -> Html Msg
viewCp cp =
    div [ class "p-3" ]
        [ h1 [] [ text cp.internalConfig.identity ]
        , div [ class "d-flex flex-wrap" ]
            ([ Just <| viewConnectionWidget cp.modules.connection
             , Just <| viewStatusWidget cp.modules.status
             , Maybe.map viewActionsWidget cp.modules.actions
             , Just <| viewInternalConfigWidget cp.internalConfig
             , Maybe.map viewHeartbeatWidget cp.modules.heartbeat
             , Just <| viewOCPPConfigWidget cp.ocppConfig
             , Maybe.map viewCommandsWidget cp.modules.commands
             ]
                |> List.filterMap identity
            )
        ]


viewConnectionWidget : CPModuleConnection -> Html Msg
viewConnectionWidget conn =
    let
        header =
            [ text <| "Connection: " ++ viewCpConnectionShortStr conn.state ]
    in
    viewCpWidget header (viewConnectionWidgetBody conn)


viewConnectionWidgetBody : CPModuleConnection -> List (Html Msg)
viewConnectionWidgetBody conn =
    viewConnectionWidgetBodyState conn.state
        ++ viewConnectionWidgetBodyConfig conn.config


viewConnectionWidgetBodyState : CPModuleConnectionState -> List (Html Msg)
viewConnectionWidgetBodyState state =
    case state of
        Idle ->
            [ p [] [ text "Idle" ] ]

        WSInit ->
            [ p [] [ text "Websocket Initialization" ] ]

        BootNotification { outgoingCallQueue } ->
            p [] [ text "BootNotification sent" ] :: viewConnectionWidgetCallQueue outgoingCallQueue

        Pending { outgoingCallQueue } ->
            p [] [ text "BootNotification Pending state (awaiting server commands)" ] :: viewConnectionWidgetCallQueue outgoingCallQueue

        Retry { connectionError, retryAt } ->
            [ p [] [ text "Connection failed:" ]
            , p [] [ text connectionError ]
            , p [] [ text <| "Will retry at " ++ Iso8601.fromTime retryAt ]
            ]

        Resetting { retryAt } ->
            [ p [] [ text "Simulating reset" ]
            , p [] [ text <| "Will connect at " ++ Iso8601.fromTime retryAt ]
            ]

        Done { outgoingCallQueue, currentTimeDiff } ->
            [ p [] [ text "Connected" ]
            , p [] [ text <| "Current time delay is " ++ String.fromFloat currentTimeDiff ++ " us" ]
            ]
                ++ viewConnectionWidgetCallQueue outgoingCallQueue


viewConnectionWidgetBodyConfig : CPModuleConnectionConfig -> List (Html Msg)
viewConnectionWidgetBodyConfig config =
    [ viewSpoiler False
        [ text "Connection module config" ]
        [ Html.Styled.table [ class "table table-stripped" ]
            [ thead []
                [ tr []
                    [ th [ attribute "scope" "col" ] [ text "Key" ]
                    , th [ attribute "scope" "col" ] [ text "Value" ]
                    , th [ attribute "scope" "col" ] [ text "Unit" ]
                    ]
                ]
            , tbody []
                [ tr []
                    [ td [] [ text "Call Timeout Interval" ]
                    , td [] [ text <| String.fromInt config.callTimeoutInterval ]
                    , td [] [ text "s" ]
                    ]
                , tr []
                    [ td [] [ text "Default Retry interval" ]
                    , td [] [ text <| String.fromInt config.defaultRetryInterval ]
                    , td [] [ text "s" ]
                    ]
                , tr []
                    [ td [] [ text "Hard Reboot interval" ]
                    , td [] [ text <| String.fromInt config.hardRebootInterval ]
                    , td [] [ text "s" ]
                    ]
                , tr []
                    [ td [] [ text "Soft Reboot interval" ]
                    , td [] [ text <| String.fromInt config.softRebootInterval ]
                    , td [] [ text "s" ]
                    ]
                ]
            ]
        ]
    ]


viewConnectionWidgetCallQueue : List OCPPCall -> List (Html Msg)
viewConnectionWidgetCallQueue outgoingCallQueue =
    if List.isEmpty outgoingCallQueue then
        [ p [] [ text "Outgoing OCPP calls queue is empty" ] ]

    else
        [ viewSpoiler True
            [ text "Outgoing OCPP calls queue" ]
            [ Html.Styled.table [ class "table table-stripped" ]
                [ thead []
                    [ tr []
                        [ th [ attribute "scope" "col" ] [ text "Sent?" ]
                        , th [ attribute "scope" "col" ] [ text "ID" ]
                        , th [ attribute "scope" "col" ] [ text "Action" ]
                        , th [ attribute "scope" "col" ] [ text "Payload" ]
                        ]
                    ]
                , tbody [] (List.map viewConnectionWidgetOCPPCall outgoingCallQueue)
                ]
            ]
        ]


viewConnectionWidgetOCPPCall : OCPPCall -> Html Msg
viewConnectionWidgetOCPPCall call =
    let
        statusText =
            case call.status of
                Sent ->
                    "Yes"

                NotSent ->
                    "No"
    in
    tr []
        [ td [] [ text statusText ]
        , td [] [ text call.id ]
        , td [] [ text call.action ]
        , td [] [ text <| E.encode 0 call.payload ]
        ]


viewStatusWidget : CPModuleStatus -> Html Msg
viewStatusWidget st =
    let
        header =
            [ text <| "Status: " ++ viewStatusShortStr S.humanString st.state.status ]
    in
    viewCpWidget header (viewStatusWidgetBody st)


viewStatusWidgetBody : CPModuleStatus -> List (Html Msg)
viewStatusWidgetBody st =
    viewStatusWidgetBodyState st.state
        ++ viewStatusWidgetBodyConfig st.config


viewStatusWidgetBodyState : CPModuleStatusState -> List (Html Msg)
viewStatusWidgetBodyState state =
    viewStatus S.humanString "ChargePoint (connector 0): " state.status :: List.indexedMap (viewConnectorStatus CS.humanString) state.connectorStatuses


viewStatusWidgetBodyConfig : CPModuleStatusConfig -> List (Html Msg)
viewStatusWidgetBodyConfig config =
    [ viewSpoiler False
        [ text "Status module config" ]
        [ Html.Styled.table [ class "table table-stripped" ]
            [ thead []
                [ tr []
                    [ th [ attribute "scope" "col" ] [ text "Key" ]
                    , th [ attribute "scope" "col" ] [ text "Value" ]
                    ]
                ]
            , tbody [] <|
                tr []
                    [ td [] [ text "Initial Charge Point Status" ]
                    , td [] [ text <| S.humanString config.initialStatus ]
                    ]
                    :: List.indexedMap
                        (\ind cs ->
                            tr []
                                [ td [] [ text <| "Initial Connector " ++ String.fromInt (ind + 1) ++ " Status" ]
                                , td [] [ text <| CS.humanString cs ]
                                ]
                        )
                        config.initialConnectorStatuses
            ]
        ]
    ]


viewConnectorStatus : (s -> String) -> Int -> CPModuleStatusStateMaybeReported s -> Html Msg
viewConnectorStatus convertor ind =
    viewStatus convertor ("Connector " ++ String.fromInt (ind + 1) ++ ": ")


viewStatus : (s -> String) -> String -> CPModuleStatusStateMaybeReported s -> Html Msg
viewStatus convertor prefix maybeReportedStatus =
    case maybeReportedStatus of
        REPORTED at status ->
            viewSpoiler True
                [ span [] [ text prefix ]
                , strong [] [ text (convertor status) ]
                ]
                [ p [] [ text <| "Reported to server at " ++ Iso8601.fromTime at ]
                ]

        NOT_REPORTED status ->
            viewSpoiler True
                [ span [] [ text prefix ]
                , strong [] [ text (convertor status) ]
                ]
                [ p [] [ text "Not yet reported to server" ]
                ]


viewActionsWidget : CPModuleActions -> Html Msg
viewActionsWidget a =
    viewCpWidget (viewActionsWidgetHeader a.state) (viewActionsWidgetBody a)


viewActionsWidgetHeader : CPModuleActionsState -> List (Html Msg)
viewActionsWidgetHeader st =
    [ span [ css [ Css.display Css.inlineBlock, Css.maxWidth (Css.px 600) ] ]
        (span [] [ text "Actions: " ]
            :: (case st.status of
                    A.Idle ->
                        [ span [] [ text "IDLE" ] ]

                    A.Executing { instructionPointer } ->
                        let
                            ( batchInd, instrInd ) =
                                instructionPointer

                            batch =
                                (List.drop batchInd >> List.head >> Maybe.withDefault (A.CPModuleActionsBatch [])) st.queue

                            maybeInstr =
                                (List.drop instrInd >> List.head) batch.actions
                        in
                        case maybeInstr of
                            Just action ->
                                span [] [ text <| A.humanString action.typ ++ " " ]
                                    :: viewActionConfig action.typ

                            Nothing ->
                                [ span [] [ text "None" ] ]
               )
        )
    ]


viewActionsWidgetBody : CPModuleActions -> List (Html Msg)
viewActionsWidgetBody a =
    viewActionsWidgetBodyState a.state
        ++ viewActionsWidgetBodyConfig a.config


viewActionsWidgetBodyState : CPModuleActionsState -> List (Html Msg)
viewActionsWidgetBodyState st =
    [ p []
        [ span [] [ text "Current Transaction ID: " ]
        , strong [] [ text <| Maybe.withDefault "(None)" st.startedTransactionId ]
        ]
    , p []
        [ span [] [ text "Current Transaction Connector: " ]
        , strong [] [ text (st.startedTransactionConnector |> Maybe.map String.fromInt |> Maybe.withDefault "(None)") ]
        ]
    ]
        ++ viewActionsWidgetBodyStateQueue st


viewActionsWidgetBodyStateQueue : CPModuleActionsState -> List (Html Msg)
viewActionsWidgetBodyStateQueue st =
    case st.status of
        A.Idle ->
            [ p [] [ text "IDLE" ] ]

        A.Executing { instructionPointer } ->
            let
                ( batchInd, instrInd ) =
                    instructionPointer

                batch =
                    (List.drop batchInd >> List.head >> Maybe.withDefault (A.CPModuleActionsBatch [])) st.queue
            in
            [ p [] [ text "EXECUTING" ]
            , viewActionsQueue instrInd batch.actions
            ]


viewActionsQueue : Int -> List A.CPModuleActionsAction -> Html Msg
viewActionsQueue activeInd actions =
    Html.Styled.table [ class "table table-stripped caption-top" ]
        [ thead []
            [ tr []
                [ th [ attribute "scope" "col" ] [ text "Current" ]
                , th [ attribute "scope" "col" ] [ text "Type" ]
                , th [ attribute "scope" "col" ] [ text "Config" ]
                , th [ attribute "scope" "col" ] [ text "State" ]
                ]
            ]
        , tbody [] <|
            List.indexedMap
                (\ind a ->
                    tr []
                        [ td []
                            [ if ind == activeInd then
                                i [ class "fas fa-arrow-right", css [ Css.color <| Css.hex "2a0ffa" ] ] []

                              else
                                text ""
                            ]
                        , td [] [ text <| A.humanString a.typ ]
                        , td [ css [ Css.maxWidth (Css.px 600) ] ] (viewActionConfig a.typ)
                        , td [] (viewActionState a.typ)
                        ]
                )
                actions
        ]


viewActionConfig : A.CPModuleActionsActionType -> List (Html Msg)
viewActionConfig typ =
    case typ of
        A.STATUS_CHANGE { connector, status } ->
            [ text <| "Set '" ++ CS.humanString status ++ "' for connector #" ++ String.fromInt connector ]

        A.AUTHORIZE { idTag } ->
            [ text idTag ]

        A.START_TRANSACTION { connector, idTag } ->
            [ text <| "Auth idTag " ++ idTag ++ " on connector #" ++ String.fromInt connector ]

        A.STOP_TRANSACTION { idTag } ->
            [ text <| "Auth idTag " ++ idTag ]

        A.CHARGE_PERIOD { vehiclePowerCapacity, period, initialVehicleCharge, vehicleBatteryCapacity, speedup } _ ->
            List.intersperse (span [] [ text "," ])
                [ span [] [ text <| "For " ++ String.fromInt period ++ "s" ]
                , span [] [ text <| "charge vehicle with power capacity " ++ String.fromInt vehiclePowerCapacity ++ "W" ]
                , span [] [ text <| "battery capacity " ++ String.fromInt vehicleBatteryCapacity ++ "Wh" ]
                , span [] [ text <| "initial charge " ++ (roundFloat 2 >> String.fromFloat) initialVehicleCharge ++ "Wh" ]
                , span [] [ text <| "speedup " ++ viewActionConfigSpeedup speedup ]
                ]

        A.DELAY { interval } ->
            [ text <| String.fromInt interval ++ " seconds" ]


viewActionState : A.CPModuleActionsActionType -> List (Html Msg)
viewActionState typ =
    case typ of
        A.STATUS_CHANGE _ ->
            []

        A.AUTHORIZE _ ->
            []

        A.START_TRANSACTION _ ->
            []

        A.STOP_TRANSACTION _ ->
            []

        A.CHARGE_PERIOD _ (Just { realInterval, speedupDilatedInterval, periodLeft, vehicleCharge, power, speedupIncreasedPower, powerOffered }) ->
            [ Html.Styled.table [ class "table table-stripped" ]
                [ thead []
                    [ tr []
                        [ th [ attribute "scope" "col" ] [ text "Key" ]
                        , th [ attribute "scope" "col" ] [ text "Value" ]
                        , th [ attribute "scope" "col" ] [ text "Unit" ]
                        ]
                    ]
                , tbody [] <|
                    [ tr []
                        [ td [] [ text "Period Left" ]
                        , td [] [ text <| String.fromInt periodLeft ]
                        , td [] [ text "s" ]
                        ]
                    , tr []
                        [ td [] [ text "Vehicle Charge" ]
                        , td [] [ text <| (roundFloat 2 >> String.fromFloat) vehicleCharge ]
                        , td [] [ text "Wh" ]
                        ]
                    , tr []
                        [ td [] [ text "Update Interval (s)" ]
                        , td [] [ text <| String.fromInt realInterval ]
                        , td [] [ text "s" ]
                        ]
                    , tr []
                        [ td [] [ text "Time-dilated (speedup) interval (s)" ]
                        , td [] [ text <| (roundFloat 2 >> String.fromFloat) speedupDilatedInterval ]
                        , td [] [ text "s" ]
                        ]
                    , tr []
                        [ td [] [ text "Charging Power" ]
                        , td [] [ text <| String.fromInt power ]
                        , td [] [ text "W" ]
                        ]
                    , tr []
                        [ td [] [ text "Speedup Increased Charging Power" ]
                        , td [] [ text <| (roundFloat 2 >> String.fromFloat) speedupIncreasedPower ]
                        , td [] [ text "W" ]
                        ]
                    , tr []
                        [ td [] [ text "Charging Power Offered" ]
                        , td [] [ text <| String.fromInt powerOffered ]
                        , td [] [ text "W" ]
                        ]
                    ]
                ]
            ]

        A.CHARGE_PERIOD _ Nothing ->
            []

        A.DELAY _ ->
            []


viewActionConfigSpeedup : A.CPModuleActionsActionTypeChargePeriodConfigSpeedup -> String
viewActionConfigSpeedup speedup =
    case speedup of
        A.IncreasePower coeff ->
            "speedup by increasing power x" ++ (roundFloat 2 >> String.fromFloat) coeff

        A.TimeDilation coeff ->
            "speedup by dilating time x" ++ (roundFloat 2 >> String.fromFloat) coeff

        A.None ->
            ""


viewActionsWidgetBodyConfig : CPModuleActionsConfig -> List (Html Msg)
viewActionsWidgetBodyConfig c =
    [ viewSpoiler False
        [ text "Actions module config" ]
        (case c.initialQueue of
            Just batch ->
                [ p [] [ text "Initial Queue" ]
                , viewActionsQueue -1 batch.actions
                ]

            Nothing ->
                []
        )
    ]


viewHeartbeatWidget : CPModuleHeartbeat -> Html Msg
viewHeartbeatWidget h =
    let
        header =
            [ text <| "Heartbeat: " ++ viewHeartbeatShortStr h.state ]
    in
    viewCpWidget header (viewHeartbeatWidgetBody h)


viewHeartbeatWidgetBody : CPModuleHeartbeat -> List (Html Msg)
viewHeartbeatWidgetBody h =
    viewHeartbeatWidgetBodyState h.state
        ++ viewHeartbeatWidgetBodyConfig h.config


viewHeartbeatWidgetBodyState : CPModuleHeartbeatState -> List (Html Msg)
viewHeartbeatWidgetBodyState s =
    [ Html.Styled.table [ class "table table-stripped" ]
        [ thead []
            [ tr []
                [ th [ attribute "scope" "col" ] [ text "Key" ]
                , th [ attribute "scope" "col" ] [ text "Value" ]
                , th [ attribute "scope" "col" ] [ text "Unit" ]
                ]
            ]
        , tbody [] <|
            [ tr []
                [ td [] [ text "Interval" ]
                , td [] [ text <| String.fromInt s.interval ]
                , td [] [ text "s" ]
                ]
            , tr []
                [ td [] [ text "Last Message At" ]
                , td [] [ text (s.lastMessageAt |> Maybe.map Iso8601.fromTime |> Maybe.withDefault "(None)") ]
                , td [] [ text "" ]
                ]
            , tr []
                [ td [] [ text "Last Heartbeat At" ]
                , td [] [ text (s.lastHeartbeatAt |> Maybe.map Iso8601.fromTime |> Maybe.withDefault "(None)") ]
                , td [] [ text "" ]
                ]
            ]
        ]
    ]


viewHeartbeatWidgetBodyConfig : CPModuleHeartbeatConfig -> List (Html Msg)
viewHeartbeatWidgetBodyConfig c =
    [ viewSpoiler False
        [ text "Heartbeat module config" ]
        [ Html.Styled.table [ class "table table-stripped" ]
            [ thead []
                [ tr []
                    [ th [ attribute "scope" "col" ] [ text "Key" ]
                    , th [ attribute "scope" "col" ] [ text "Value" ]
                    , th [ attribute "scope" "col" ] [ text "Unit" ]
                    ]
                ]
            , tbody [] <|
                [ tr []
                    [ td [] [ text "Default Interval" ]
                    , td [] [ text <| String.fromInt c.defaultInterval ]
                    , td [] [ text "s" ]
                    ]
                ]
            ]
        ]
    ]


roundFloat : Int -> Float -> Float
roundFloat precision value =
    let
        power =
            10 ^ precision |> toFloat
    in
    (value * power)
        |> Basics.round
        |> toFloat
        |> (\x -> x / power)


viewInternalConfigWidget : CPInternalConfig -> Html Msg
viewInternalConfigWidget ic =
    let
        header =
            [ text <| "Internal Config: Connector meters " ++ (List.map (roundFloat 2 >> String.fromFloat) ic.connectorMeters |> String.join ", ") ]
    in
    viewCpWidget header (viewInternalConfigWidgetBody ic)


viewInternalConfigWidgetBody : CPInternalConfig -> List (Html Msg)
viewInternalConfigWidgetBody ic =
    [ Html.Styled.table [ class "table table-stripped" ]
        [ thead []
            [ tr []
                [ th [ attribute "scope" "col" ] [ text "Key" ]
                , th [ attribute "scope" "col" ] [ text "Value" ]
                , th [ attribute "scope" "col" ] [ text "Unit" ]
                ]
            ]
        , tbody [] <|
            [ tr []
                [ td [] [ text "WS Endpoint" ]
                , td [] [ text ic.wsEndpoint ]
                , td [] [ text "" ]
                ]
            , tr []
                [ td [] [ text "Vendor" ]
                , td [] [ text ic.vendor ]
                , td [] [ text "" ]
                ]
            , tr []
                [ td [] [ text "Model" ]
                , td [] [ text ic.model ]
                , td [] [ text "" ]
                ]
            , tr []
                [ td [] [ text "Firmware Version" ]
                , td [] [ text <| Maybe.withDefault "(None)" ic.fwVersion ]
                , td [] [ text "" ]
                ]
            , tr []
                [ td [] [ text "Power Limit" ]
                , td [] [ text <| String.fromInt ic.powerLimit ]
                , td [] [ text "W" ]
                ]
            ]
                ++ List.indexedMap
                    (\ind meter ->
                        tr []
                            [ td [] [ text <| "Connector " ++ String.fromInt (ind + 1) ++ " Meter" ]
                            , td [] [ text <| (roundFloat 2 >> String.fromFloat) meter ]
                            , td [] [ text "kWh" ]
                            ]
                    )
                    ic.connectorMeters
        ]
    ]


viewOCPPConfigWidget : CPOCPPConfig -> Html Msg
viewOCPPConfigWidget c =
    let
        header =
            [ text <| "OCPP Config: " ++ (List.length c.items |> String.fromInt) ++ " Item(s)" ]
    in
    viewCpWidget header (viewOCPPConfigWidgetBody c)


viewOCPPConfigWidgetBody : CPOCPPConfig -> List (Html Msg)
viewOCPPConfigWidgetBody c =
    [ Html.Styled.table [ class "table table-stripped" ]
        [ thead []
            [ tr []
                [ th [ attribute "scope" "col" ] [ text "Key" ]
                , th [ attribute "scope" "col" ] [ text "Value" ]
                , th [ attribute "scope" "col" ] [ text "Readonly" ]
                ]
            ]
        , tbody [] <|
            List.map
                (\ci ->
                    tr []
                        [ td [] [ text ci.key ]
                        , td [] [ text <| Maybe.withDefault "(None)" ci.value ]
                        , td []
                            [ text
                                (if ci.readonly then
                                    "Yes"

                                 else
                                    "No"
                                )
                            ]
                        ]
                )
                c.items
        ]
    ]


viewCommandsWidget : CPModuleCommands -> Html Msg
viewCommandsWidget c =
    let
        header =
            [ text <| "Commands: " ++ (List.length c.config.supportedCommands |> String.fromInt) ++ " enabled" ]
    in
    viewCpWidget header (viewCommandsWidgetBody c)


viewCommandsWidgetBody : CPModuleCommands -> List (Html Msg)
viewCommandsWidgetBody c =
    [ Html.Styled.table [ class "table table-stripped" ]
        [ thead []
            [ tr []
                [ th [ attribute "scope" "col" ] [ text "Command" ]
                , th [ attribute "scope" "col" ] [ text "Supported" ]
                ]
            ]
        , tbody [] <|
            List.map
                (\cmd ->
                    tr []
                        [ td [] [ text <| C.humanString cmd ]
                        , td []
                            [ text <|
                                if List.member cmd c.config.supportedCommands then
                                    "Yes"

                                else
                                    "No"
                            ]
                        ]
                )
                C.availableCommands
        ]
    ]


viewCpWidget : List (Html Msg) -> List (Html Msg) -> Html Msg
viewCpWidget header body =
    div [ class "card me-3 mb-3" ]
        [ h5 [ class "card-header" ] header
        , div [ class "card-body" ] body
        ]


viewSpoiler : Bool -> List (Html Msg) -> List (Html Msg) -> Html Msg
viewSpoiler preOpen title body =
    let
        attrs =
            if preOpen then
                [ attribute "open" "true" ]

            else
                []
    in
    details attrs <|
        summary [ css [ viewSpoilerSummaryStyle ] ] title
            :: body


viewSpoilerSummaryStyle : Css.Style
viewSpoilerSummaryStyle =
    Css.batch
        [ Css.width (Css.pct 100)
        , Css.padding2 (Css.rem 0.5) Css.zero
        , Css.borderTop3 (Css.px 1) Css.solid (Css.rgb 0 0 0)
        , Css.position Css.relative
        , Css.listStyle Css.none
        , Css.outline Css.zero
        , Css.after
            [ Css.property "content" "'+'"
            , Css.position Css.absolute
            , Css.lineHeight Css.zero
            , Css.marginTop (Css.rem 0.75)
            , Css.right Css.zero
            ]
        ]



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
