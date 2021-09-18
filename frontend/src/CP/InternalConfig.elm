module CP.InternalConfig exposing (CPInternalConfig, configEncoder, cpInternalConfigDecoder)

import Json.Decode as D
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode as E


type alias CPInternalConfig =
    { identity : String
    , vendor : String
    , model : String
    , fwVersion : Maybe String
    , connectorsCount : Int
    , connectorMeters : List Float
    , powerLimit : Int
    , wsEndpoint : String
    }


cpInternalConfigDecoder : D.Decoder CPInternalConfig
cpInternalConfigDecoder =
    D.succeed CPInternalConfig
        |> required "identity" D.string
        |> required "vendor" D.string
        |> required "model" D.string
        |> required "fw_version" (D.nullable D.string)
        |> required "connectors_count" D.int
        |> required "connector_meters" (D.list D.float)
        |> required "power_limit" D.int
        |> required "ws_endpoint" D.string


configEncoder : CPInternalConfig -> E.Value
configEncoder cfg =
    E.object
        [ ( "identity", E.string cfg.identity )
        , ( "vendor", E.string cfg.vendor )
        , ( "model", E.string cfg.model )
        , ( "fw_version", cfg.fwVersion |> Maybe.map E.string |> Maybe.withDefault E.null )
        , ( "connectors_count", E.int cfg.connectorsCount )
        , ( "connector_meters", E.list E.float cfg.connectorMeters )
        , ( "power_limit", E.int cfg.powerLimit )
        , ( "ws_endpoint", E.string cfg.wsEndpoint )
        ]
