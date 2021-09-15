module CP.InternalConfig exposing (CPInternalConfig, cpInternalConfigDecoder)

import Json.Decode as D
import Json.Decode.Pipeline exposing (hardcoded, optional, required)


type alias CPInternalConfig =
    { connectorsCount : Int
    , connectorMeters : List Float
    , fwVersion : Maybe String
    , identity : String
    , vendor : String
    , model : String
    , powerLimit : Int
    , wsEndpoint : String
    }


cpInternalConfigDecoder : D.Decoder CPInternalConfig
cpInternalConfigDecoder =
    D.succeed CPInternalConfig
        |> required "connectors_count" D.int
        |> required "connector_meters" (D.list D.float)
        |> required "fw_version" (D.nullable D.string)
        |> required "identity" D.string
        |> required "vendor" D.string
        |> required "model" D.string
        |> required "power_limit" D.int
        |> required "ws_endpoint" D.string
