module CP.Modules.Status.OCPPConnectorStatus exposing (OCPPConnectorStatus(..), decoder, encoder, fromString, humanString, options, toString)

import Json.Decode as D
import Json.Encode as E


type OCPPConnectorStatus
    = AVAILABLE
    | PREPARING
    | CHARGING
    | SUSPENDED_EV
    | SUSPENDED_EVSE
    | FINISHING
    | RESERVED
    | UNAVAILABLE
    | FAULTED


decoder : D.Decoder OCPPConnectorStatus
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

                    "preparing" ->
                        D.succeed PREPARING

                    "charging" ->
                        D.succeed CHARGING

                    "suspended_ev" ->
                        D.succeed SUSPENDED_EV

                    "suspended_evse" ->
                        D.succeed SUSPENDED_EVSE

                    "finishing" ->
                        D.succeed FINISHING

                    "reserved" ->
                        D.succeed RESERVED

                    other ->
                        D.fail ("Unexpected ocpp connector status " ++ other)
            )


encoder : OCPPConnectorStatus -> E.Value
encoder status =
    E.string <| toString status


options : List OCPPConnectorStatus
options =
    [ AVAILABLE, PREPARING, CHARGING, SUSPENDED_EV, SUSPENDED_EVSE, FINISHING, RESERVED, UNAVAILABLE, FAULTED ]


humanString : OCPPConnectorStatus -> String
humanString status =
    case status of
        AVAILABLE ->
            "Available"

        UNAVAILABLE ->
            "Unavailable"

        PREPARING ->
            "Preparing"

        CHARGING ->
            "Charging"

        SUSPENDED_EV ->
            "Suspended EV"

        SUSPENDED_EVSE ->
            "Suspended EVSE"

        FINISHING ->
            "Finishing"

        RESERVED ->
            "Reserved"

        FAULTED ->
            "Faulted"


toString : OCPPConnectorStatus -> String
toString status =
    case status of
        AVAILABLE ->
            "available"

        UNAVAILABLE ->
            "unavailable"

        PREPARING ->
            "preparing"

        CHARGING ->
            "charging"

        SUSPENDED_EV ->
            "suspended_ev"

        SUSPENDED_EVSE ->
            "suspended_evse"

        FINISHING ->
            "finishing"

        RESERVED ->
            "reserved"

        FAULTED ->
            "faulted"


fromString : String -> OCPPConnectorStatus
fromString status =
    case status of
        "available" ->
            AVAILABLE

        "unavailable" ->
            UNAVAILABLE

        "preparing" ->
            PREPARING

        "charging" ->
            CHARGING

        "suspended_ev" ->
            SUSPENDED_EV

        "suspended_evse" ->
            SUSPENDED_EVSE

        "finishing" ->
            FINISHING

        "reserved" ->
            RESERVED

        "faulted" ->
            FAULTED

        _ ->
            AVAILABLE
