module CP.Modules.Commands exposing (CPModuleCommands, CPModuleCommandsConfig)


type alias CPModuleCommands =
    { config : CPModuleCommandsConfig
    }


type CPModuleCommandsCommand
    = CHANGE_CONFIGURATION
    | GET_CONFIGURATION
    | RESET
    | TRIGGER_MESSAGE


type alias CPModuleCommandsConfig =
    { supportedCommands : List CPModuleCommandsCommand }
