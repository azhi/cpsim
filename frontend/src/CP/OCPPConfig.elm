module CP.OCPPConfig exposing (CPOCPPConfig, CPOCPPConfigItem, configEncoder, cpOcppConfigDecoder)

import Json.Decode as D
import Json.Decode.Pipeline exposing (hardcoded, optional, required)
import Json.Encode as E


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


configEncoder : CPOCPPConfig -> E.Value
configEncoder cfg =
    E.object
        [ ( "items", E.list configItemEncoder cfg.items )
        ]


configItemEncoder : CPOCPPConfigItem -> E.Value
configItemEncoder cfg =
    E.object
        [ ( "key", E.string cfg.key )
        , ( "value", cfg.value |> Maybe.map E.string |> Maybe.withDefault E.null )
        , ( "readonly", E.bool cfg.readonly )
        ]
