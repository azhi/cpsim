module CP.OCPPConfig exposing (CPOCPPConfig, CPOCPPConfigItem, cpOcppConfigDecoder)

import Json.Decode as D
import Json.Decode.Pipeline exposing (hardcoded, optional, required)


type alias CPOCPPConfig =
    { items : List CPOCPPConfigItem
    }


type alias CPOCPPConfigItem =
    { key : String
    , value : Maybe String
    , readonly : Bool
    }


cpOcppConfigDecoder : D.Decoder CPOCPPConfig
cpOcppConfigDecoder =
    D.succeed CPOCPPConfig
        |> required "items" (D.list cpOcppConfigItemDecoder)


cpOcppConfigItemDecoder : D.Decoder CPOCPPConfigItem
cpOcppConfigItemDecoder =
    D.succeed CPOCPPConfigItem
        |> required "key" D.string
        |> required "value" (D.nullable D.string)
        |> required "readonly" D.bool
