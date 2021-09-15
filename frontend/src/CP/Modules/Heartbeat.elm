module CP.Modules.Heartbeat exposing (CPModuleHeartbeat, CPModuleHeartbeatConfig)

import Time


type alias CPModuleHeartbeat =
    { config : CPModuleHeartbeatConfig
    , state : CPModuleHeartbeatState
    }


type alias CPModuleHeartbeatConfig =
    { defaultInterval : Int }


type alias CPModuleHeartbeatState =
    { interval : Int
    , lastMessageAt : Maybe Time.Posix
    , lastHeartbeatAt : Maybe Time.Posix
    }
