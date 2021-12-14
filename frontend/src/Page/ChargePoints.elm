module Page.ChargePoints exposing (Model, Msg, init, subscriptions, toSession, update, view)

import CP exposing (CP, cpDecoder)
import CP.InternalConfig exposing (CPInternalConfig)
import CP.Modules.Actions exposing (CPModuleActions)
import CP.Modules.Commands exposing (CPModuleCommands)
import CP.Modules.Connection exposing (CPModuleConnection, CPModuleConnectionConfig, CPModuleConnectionState(..), OCPPCall, OCPPCallStatus(..))
import CP.Modules.Heartbeat exposing (CPModuleHeartbeat, CPModuleHeartbeatState)
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
import Session exposing (Session)
import Time



-- MODEL


type alias Model =
    { session : Session
    , cps : List CP
    , selectedCp : Maybe CP
    }



-- type Status a
--     = Loading
--     | LoadingSlowly
--     | Loaded a
--     | Failed


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session, cps = [], selectedCp = Nothing }
    , fetchCps
    )



-- UPDATE


type Msg
    = GotCPs (Result Http.Error (List CP))
    | CPClicked CP


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        GotCPs result ->
            case result of
                Ok cps ->
                    ( { model | cps = cps }, Cmd.none )

                Err _ ->
                    ( model, Cmd.none )

        CPClicked cp ->
            ( { model | selectedCp = Just cp }, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- REQUESTS


fetchCps : Cmd Msg
fetchCps =
    Http.get
        { url = "/api/cp"
        , expect = Http.expectJson GotCPs (D.list cpDecoder)
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


viewSidebarCp : Maybe CP -> CP -> Html Msg
viewSidebarCp selectedCp cp =
    button [ class "list-group-item list-group-item-action py-3 lh-tight", classList [ ( "active", isSelectedCp selectedCp cp ) ], onClick (CPClicked cp) ]
        [ div [ class "w-100" ] [ strong [] [ text cp.internalConfig.identity ] ]
        , div [ class "col-10 mb-1 small" ] [ text (viewCpConnectionShortStr cp.modules.connection.state) ]
        ]


isSelectedCp : Maybe CP -> CP -> Bool
isSelectedCp selectedCp cp =
    case selectedCp of
        Just scp ->
            scp.internalConfig.identity == cp.internalConfig.identity

        Nothing ->
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
        Just cp ->
            viewCp cp

        Nothing ->
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
    let
        header =
            [ text <| "Actions: " ++ (List.length a.state.queue |> String.fromInt) ++ " in queue" ]

        body =
            [ text "BODY" ]
    in
    viewCpWidget header body


viewHeartbeatWidget : CPModuleHeartbeat -> Html Msg
viewHeartbeatWidget h =
    let
        header =
            [ text <| "Heartbeat: " ++ viewHeartbeatShortStr h.state ]

        body =
            [ text "BODY" ]
    in
    viewCpWidget header body


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

        body =
            [ text "BODY" ]
    in
    viewCpWidget header body


viewOCPPConfigWidget : CPOCPPConfig -> Html Msg
viewOCPPConfigWidget c =
    let
        header =
            [ text <| "OCPP Config: " ++ (List.length c.items |> String.fromInt) ++ " Item(s)" ]

        body =
            [ text "BODY" ]
    in
    viewCpWidget header body


viewCommandsWidget : CPModuleCommands -> Html Msg
viewCommandsWidget c =
    let
        header =
            [ text <| "Commands: " ++ (List.length c.config.supportedCommands |> String.fromInt) ++ " enabled" ]

        body =
            [ text "BODY" ]
    in
    viewCpWidget header body


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
