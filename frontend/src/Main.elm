module Main exposing (main)

import Browser exposing (Document)
import Browser.Navigation as Nav
import Html
import Html.Styled exposing (..)
import Json.Decode
import Page
import Page.ChargePoints as ChargePoints
import Page.LaunchCP as LaunchCP
import Page.NotFound as NotFound
import Route exposing (Route)
import Session exposing (Session)
import Url exposing (Url)



-- NOTE: Based on discussions around how asset management features
-- like code splitting and lazy loading have been shaping up, it's possible
-- that most of this file may become unnecessary in a future release of Elm.
-- Avoid putting things in this module unless there is no alternative!
-- See https://discourse.elm-lang.org/t/elm-spa-in-0-19/1800/2 for more.


type Model
    = NotFound Session
    | ChargePoints ChargePoints.Model
    | LaunchCP LaunchCP.Model



-- MODEL


init : flags -> Url -> Nav.Key -> ( Model, Cmd Msg )
init _ url navKey =
    changeRouteTo (Route.fromUrl url)
        (NotFound (Session navKey))



-- VIEW


view : Model -> Document Msg
view model =
    let
        viewPage page config =
            let
                { title, body } =
                    Page.view page config
            in
            { title = title
            , body = body |> List.map Html.Styled.toUnstyled
            }

        mapToMsg toMsg { title, body } =
            { title = title
            , body = body |> List.map (Html.map toMsg)
            }
    in
    case model of
        NotFound _ ->
            viewPage Page.Other NotFound.view

        ChargePoints charge_points ->
            viewPage Page.ChargePoints (ChargePoints.view charge_points)
                |> mapToMsg GotChargePointsMsg

        LaunchCP launchCp ->
            viewPage Page.LaunchCP (LaunchCP.view launchCp)
                |> mapToMsg GotLaunchCPMsg



-- UPDATE


type Msg
    = ChangedUrl Url
    | ClickedLink Browser.UrlRequest
    | GotChargePointsMsg ChargePoints.Msg
    | GotLaunchCPMsg LaunchCP.Msg


toSession : Model -> Session
toSession page =
    case page of
        NotFound session ->
            session

        ChargePoints charge_points ->
            ChargePoints.toSession charge_points

        LaunchCP settings ->
            LaunchCP.toSession settings


changeRouteTo : Maybe Route -> Model -> ( Model, Cmd Msg )
changeRouteTo maybeRoute model =
    let
        session =
            toSession model
    in
    case ( model, maybeRoute ) of
        ( _, Nothing ) ->
            ( NotFound session, Cmd.none )

        ( ChargePoints _, Just (Route.ChargePoints selectedCp) ) ->
            ( model, Cmd.none )

        ( _, Just (Route.ChargePoints selectedCp) ) ->
            ChargePoints.init session selectedCp
                |> updateWith ChargePoints GotChargePointsMsg

        ( LaunchCP _, Just Route.LaunchCP ) ->
            ( model, Cmd.none )

        ( _, Just Route.LaunchCP ) ->
            LaunchCP.init session
                |> updateWith LaunchCP GotLaunchCPMsg


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( ClickedLink urlRequest, _ ) ->
            case urlRequest of
                Browser.Internal url ->
                    ( model
                    , Nav.pushUrl (.navKey (toSession model)) (Url.toString url)
                    )

                Browser.External href ->
                    ( model
                    , Nav.load href
                    )

        ( ChangedUrl url, _ ) ->
            changeRouteTo (Route.fromUrl url) model

        ( GotChargePointsMsg subMsg, ChargePoints charge_points ) ->
            ChargePoints.update subMsg charge_points
                |> updateWith ChargePoints GotChargePointsMsg

        ( GotLaunchCPMsg subMsg, LaunchCP launchCp ) ->
            LaunchCP.update subMsg launchCp
                |> updateWith LaunchCP GotLaunchCPMsg

        ( _, _ ) ->
            -- Disregard messages that arrived for the wrong page.
            ( model, Cmd.none )


updateWith : (subModel -> Model) -> (subMsg -> Msg) -> ( subModel, Cmd subMsg ) -> ( Model, Cmd Msg )
updateWith toModel toMsg ( subModel, subCmd ) =
    ( toModel subModel
    , Cmd.map toMsg subCmd
    )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions model =
    case model of
        NotFound _ ->
            Sub.none

        ChargePoints charge_points ->
            Sub.map GotChargePointsMsg (ChargePoints.subscriptions charge_points)

        LaunchCP launchCp ->
            Sub.map GotLaunchCPMsg (LaunchCP.subscriptions launchCp)



-- MAIN


main : Program Json.Decode.Value Model Msg
main =
    Browser.application
        { init = init
        , onUrlChange = ChangedUrl
        , onUrlRequest = ClickedLink
        , subscriptions = subscriptions
        , update = update
        , view = view
        }
