module CP.Modules.Status.OCPPConnectorStatus exposing (OCPPConnectorStatus(..))


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
