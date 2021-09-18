module CP.Modules.Status.OCPPStatus exposing (OCPPStatus(..), decoder, encoder, fromString, humanString, options, toString)

import Json.Decode as D
import Json.Encode as E


type OCPPStatus
    = AVAILABLE
    | UNAVAILABLE
    | FAULTED


decoder : D.Decoder OCPPStatus
decoder =
    D.string
        |> D.andThen
            (\status ->
                case status of
                    "available" ->
                        D.succeed AVAILABLE

                    "unavailable" ->
                        D.succeed UNAVAILABLE

                    "faulted" ->
                        D.succeed FAULTED

                    other ->
                        D.fail ("Unexpected ocpp status " ++ other)
            )


encoder : OCPPStatus -> E.Value
encoder status =
    E.string <| toString status


options : List OCPPStatus
options =
    [ AVAILABLE, UNAVAILABLE, FAULTED ]


humanString : OCPPStatus -> String
humanString status =
    case status of
        AVAILABLE ->
            "Available"

        UNAVAILABLE ->
            "Unavailable"

        FAULTED ->
            "Faulted"


toString : OCPPStatus -> String
toString status =
    case status of
        AVAILABLE ->
            "available"

        UNAVAILABLE ->
            "unavailable"

        FAULTED ->
            "faulted"


fromString : String -> OCPPStatus
fromString status =
    case status of
        "available" ->
            AVAILABLE

        "unavailable" ->
            UNAVAILABLE

        "faulted" ->
            FAULTED

        _ ->
            AVAILABLE
