module Page exposing (Page(..), view, viewErrors)

import Css exposing (..)
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (class, css, style)
import Html.Styled.Events exposing (onClick)
import Route exposing (Route)


{-| Determines which navbar link (if any) will be rendered as active.

Note that we don't enumerate every page here, because the navbar doesn't
have links for every page. Anything that's not part of the navbar falls
under Other.

-}
type Page
    = Other
    | ChargePoints
    | LaunchCP


{-| Take a page's Html and frames it with a header and footer.
-}
view : Page -> { title : String, content : Html msg } -> { title : String, body : List (Html msg) }
view page { title, content } =
    { title = title
    , body = [ viewHeader page, content ]
    }


viewHeader : Page -> Html msg
viewHeader page =
    header [ class "p-3 border-bottom" ]
        [ nav [ class "nav container-fluid mb-0" ]
            [ navbarLink page Route.ChargePoints [ i [ class "fas fa-charging-station" ] [], text "Charge Points" ]
            , navbarLink page Route.LaunchCP [ i [ class "fas fa-plus-circle" ] [], text "Launch new CP" ]
            ]
        ]


navbarLink : Page -> Route -> List (Html msg) -> Html msg
navbarLink page route linkContent =
    a [ class ("nav-link px-2 " ++ activeColorClass page route), css [ navbarLinkBorder ], Route.href route ] linkContent


navbarLinkBorder : Style
navbarLinkBorder =
    Css.batch
        [ pseudoClass "not(:last-child)"
            [ borderRight2 (px 1) solid
            ]
        ]


activeColorClass : Page -> Route -> String
activeColorClass page route =
    if isActive page route then
        "link-secondary"

    else
        "link-dark"


isActive : Page -> Route -> Bool
isActive page route =
    case ( page, route ) of
        ( ChargePoints, Route.ChargePoints ) ->
            True

        ( LaunchCP, Route.LaunchCP ) ->
            True

        _ ->
            False


{-| Render dismissable errors. We use this all over the place!
-}
viewErrors : msg -> List String -> Html msg
viewErrors dismissErrors errors =
    if List.isEmpty errors then
        text ""

    else
        div
            [ class "error-messages"
            , style "position" "fixed"
            , style "top" "0"
            , style "background" "rgb(250, 250, 250)"
            , style "padding" "20px"
            , style "border" "1px solid"
            ]
        <|
            List.map (\error -> p [] [ text error ]) errors
                ++ [ button [ onClick dismissErrors ] [ text "Ok" ] ]
