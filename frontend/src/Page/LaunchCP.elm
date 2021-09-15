module Page.LaunchCP exposing (Model, Msg, init, subscriptions, toSession, update, view)

import Html
import Html.Styled exposing (..)
import Session exposing (Session)



-- MODEL


type alias Model =
    { session : Session
    }



-- type Status a
--     = Loading
--     | LoadingSlowly
--     | Loaded a
--     | Failed


init : Session -> ( Model, Cmd Msg )
init session =
    ( { session = session }
    , Cmd.none
    )



-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "Conduit"
    , content =
        div [] [ text "LaunchCP" ]
    }



-- UPDATE


type Msg
    = Dummy


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    ( model, Cmd.none )



-- SUBSCRIPTIONS


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- EXPORT


toSession : Model -> Session
toSession model =
    model.session
