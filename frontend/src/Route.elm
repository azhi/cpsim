module Route exposing (Route(..), fromUrl, href, pushUrl, replaceUrl)

import Browser.Navigation as Nav
import Html.Styled exposing (Attribute)
import Html.Styled.Attributes as Attr
import Url exposing (Url)
import Url.Builder as B
import Url.Parser as P exposing ((</>), (<?>), Parser, oneOf, s)
import Url.Parser.Query as Q



-- ROUTING


type Route
    = ChargePoints (Maybe String)
    | LaunchCP


parser : Parser (Route -> a) a
parser =
    oneOf
        [ P.map ChargePoints (P.top <?> Q.string "selectedCP")
        , P.map LaunchCP (s "launch_cp")
        ]



-- PUBLIC HELPERS


href : Route -> Attribute msg
href targetRoute =
    Attr.href (routeToString targetRoute)


replaceUrl : Nav.Key -> Route -> Cmd msg
replaceUrl key route =
    Nav.replaceUrl key (routeToString route)


pushUrl : Nav.Key -> Route -> Cmd msg
pushUrl key route =
    Nav.pushUrl key (routeToString route)


fromUrl : Url -> Maybe Route
fromUrl url =
    P.parse parser url



-- INTERNAL


routeToString : Route -> String
routeToString page =
    case page of
        ChargePoints (Just selectedCP) ->
            B.absolute [] [ B.string "selectedCP" selectedCP ]

        ChargePoints Nothing ->
            B.absolute [] []

        LaunchCP ->
            B.absolute [ "launch_cp" ] []
