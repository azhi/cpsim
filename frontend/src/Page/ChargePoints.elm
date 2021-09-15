module Page.ChargePoints exposing (Model, Msg, init, subscriptions, toSession, update, view)

import CP exposing (CP, cpDecoder)
import CP.Modules.Connection exposing (CPModuleConnectionState(..))
import Css exposing (..)
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (class, classList, css)
import Html.Styled.Events exposing (onClick)
import Http
import Json.Decode as D
import Session exposing (Session)



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
                , viewCp model
                ]
            ]
    }


viewSidebar : Model -> Html Msg
viewSidebar model =
    div [ class "d-flex flex-column", css [ width (px 380) ] ]
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
            "Pending (awaiting server commands)"

        Retry { connectionError, retryAt } ->
            "Retry (" ++ connectionError ++ ")"

        Resetting _ ->
            "Resetting"

        Done _ ->
            "Connected"


viewCp : Model -> Html Msg
viewCp model =
    case model.selectedCp of
        Just cp ->
            div [] [ text cp.internalConfig.identity ]

        Nothing ->
            div [] [ text "No CP Selected" ]



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
