module CP.Modules.Commands exposing (CPModuleCommands, CPModuleCommandsCommand(..), CPModuleCommandsConfig, availableCommands, configEncoder, cpModulesCommandsDecoder, fromString, humanString, options, toString)

import Json.Decode as D
import Json.Decode.Pipeline exposing (custom, hardcoded, optional, required)
import Json.Encode as E


type alias CPModuleCommands =
    { config : CPModuleCommandsConfig
    }


type CPModuleCommandsCommand
    = CHANGE_CONFIGURATION
    | GET_CONFIGURATION
    | RESET
    | TRIGGER_MESSAGE


availableCommands =
    [ CHANGE_CONFIGURATION, GET_CONFIGURATION, RESET, TRIGGER_MESSAGE ]


type alias CPModuleCommandsConfig =
    { supportedCommands : List CPModuleCommandsCommand }


cpModulesCommandsDecoder : D.Decoder (Maybe CPModuleCommands)
cpModulesCommandsDecoder =
    D.nullable
        (D.succeed CPModuleCommands
            |> required "config" configDecoder
        )


configDecoder : D.Decoder CPModuleCommandsConfig
configDecoder =
    D.succeed CPModuleCommandsConfig
        |> required "supported_commands" (D.list commandDecoder)


commandDecoder : D.Decoder CPModuleCommandsCommand
commandDecoder =
    D.string
        |> D.andThen
            (\c ->
                case c of
                    "Elixir.CPSIM.CP.Commands.ChangeConfiguration" ->
                        D.succeed CHANGE_CONFIGURATION

                    "Elixir.CPSIM.CP.Commands.GetConfiguration" ->
                        D.succeed GET_CONFIGURATION

                    "Elixir.CPSIM.CP.Commands.Reset" ->
                        D.succeed RESET

                    "Elixir.CPSIM.CP.Commands.TriggerMessage" ->
                        D.succeed TRIGGER_MESSAGE

                    other ->
                        D.fail ("Unexpected supported command " ++ other)
            )


configEncoder : CPModuleCommandsConfig -> E.Value
configEncoder cfg =
    E.object
        [ ( "supported_commands", E.list commandEncoder cfg.supportedCommands )
        ]


commandEncoder : CPModuleCommandsCommand -> E.Value
commandEncoder command =
    E.string <| toString command


options : List CPModuleCommandsCommand
options =
    [ CHANGE_CONFIGURATION, GET_CONFIGURATION, RESET, TRIGGER_MESSAGE ]


humanString : CPModuleCommandsCommand -> String
humanString command =
    case command of
        CHANGE_CONFIGURATION ->
            "Change Configuration"

        GET_CONFIGURATION ->
            "Get Configuration"

        RESET ->
            "Reset"

        TRIGGER_MESSAGE ->
            "Trigger Message"


toString : CPModuleCommandsCommand -> String
toString command =
    case command of
        CHANGE_CONFIGURATION ->
            "change_configuration"

        GET_CONFIGURATION ->
            "get_configuration"

        RESET ->
            "reset"

        TRIGGER_MESSAGE ->
            "trigger_message"


fromString : String -> CPModuleCommandsCommand
fromString command =
    case command of
        "change_configuration" ->
            CHANGE_CONFIGURATION

        "get_configuration" ->
            GET_CONFIGURATION

        "reset" ->
            RESET

        "trigger_message" ->
            TRIGGER_MESSAGE

        _ ->
            CHANGE_CONFIGURATION
