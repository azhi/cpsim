module CP exposing (CP, cpDecoder)

import CP.InternalConfig exposing (CPInternalConfig, cpInternalConfigDecoder)
import CP.Modules exposing (CPModules, cpModulesDecoder)
import CP.OCPPConfig exposing (CPOCPPConfig, cpOcppConfigDecoder)
import Json.Decode as D
import Json.Decode.Pipeline exposing (hardcoded, optional, required)


type alias CP =
    { internalConfig : CPInternalConfig
    , ocppConfig : CPOCPPConfig
    , modules : CPModules
    }


cpDecoder : D.Decoder CP
cpDecoder =
    D.succeed CP
        |> required "internal_config" cpInternalConfigDecoder
        |> required "ocpp_config" cpOcppConfigDecoder
        |> required "modules" cpModulesDecoder
