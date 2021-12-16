module ActionsForm exposing (Model, Msg, default, update, view)

import CP.Modules.Actions as A exposing (CPModuleActionsAction)
import CP.Modules.Status.OCPPConnectorStatus as CS
import Css
import Html.Styled exposing (..)
import Html.Styled.Attributes exposing (checked, class, classList, css, disabled, for, id, multiple, selected, type_, value)
import Html.Styled.Events exposing (on, onCheck, onClick, onInput)
import Html5.DragDrop as DragDrop


type Tab
    = Template
    | Actions


type Template
    = VehicleCharge


type NewElement
    = NewAction A.CPModuleActionsAction
    | NewTemplate Template


type alias Model =
    { actions : List CPModuleActionsAction
    , selectedTab : Tab
    , insertDragDrop : DragDrop.Model NewElement Int
    , reorderDragDrop : DragDrop.Model ( CPModuleActionsAction, Int ) Int
    }


default : Model
default =
    Model [] Template DragDrop.init DragDrop.init


defaultAction : A.CPModuleActionsActionType -> A.CPModuleActionsAction
defaultAction =
    A.CPModuleActionsAction A.IDLE


defaultStatusChange : A.CPModuleActionsAction
defaultStatusChange =
    A.STATUS_CHANGE { connector = 0, status = CS.AVAILABLE } |> defaultAction


defaultAuthorize : A.CPModuleActionsAction
defaultAuthorize =
    A.AUTHORIZE { idTag = "" } |> defaultAction


defaultStartTransaction : A.CPModuleActionsAction
defaultStartTransaction =
    A.START_TRANSACTION { connector = 0, idTag = "" } |> defaultAction


defaultChargePeriod : A.CPModuleActionsAction
defaultChargePeriod =
    A.CHARGE_PERIOD { initialVehicleCharge = 0, period = 600, speedup = A.None, vehicleBatteryCapacity = 50000, vehiclePowerCapacity = 20000 } Nothing |> defaultAction


defaultStopTransaction : A.CPModuleActionsAction
defaultStopTransaction =
    A.STOP_TRANSACTION { idTag = "" } |> defaultAction


defaultDelay : A.CPModuleActionsAction
defaultDelay =
    A.DELAY { interval = 1 } |> defaultAction


template : Template -> List A.CPModuleActionsAction
template tpl =
    case tpl of
        VehicleCharge ->
            [ defaultAction (A.DELAY { interval = 2 })
            , defaultAction (A.STATUS_CHANGE { connector = 1, status = CS.PREPARING })
            , defaultAction (A.DELAY { interval = 2 })
            , defaultAction (A.AUTHORIZE { idTag = "123" })
            , defaultAction (A.DELAY { interval = 2 })
            , defaultAction (A.STATUS_CHANGE { connector = 1, status = CS.CHARGING })
            , defaultAction (A.START_TRANSACTION { connector = 1, idTag = "123" })
            , defaultAction (A.CHARGE_PERIOD { initialVehicleCharge = 5000, period = 60, speedup = A.IncreasePower 10.0, vehicleBatteryCapacity = 50000, vehiclePowerCapacity = 10000 } Nothing)
            , defaultAction (A.DELAY { interval = 5 })
            , defaultAction (A.STATUS_CHANGE { connector = 1, status = CS.FINISHING })
            , defaultAction (A.DELAY { interval = 2 })
            , defaultAction (A.STOP_TRANSACTION { idTag = "123" })
            ]


type Msg
    = SwitchToTab Tab
    | InsertDragDropMsg (DragDrop.Msg NewElement Int)
    | ReorderDragDropMsg (DragDrop.Msg ( A.CPModuleActionsAction, Int ) Int)
    | GotStatusChangeConnector Int A.CPModuleActionsActionTypeStatusChangeConfig Int
    | GotStatusChangeStatus Int A.CPModuleActionsActionTypeStatusChangeConfig CS.OCPPConnectorStatus
    | GotAuthorizeIdTag Int A.CPModuleActionsActionTypeAuthorizeConfig String
    | GotStartTransactionConnector Int A.CPModuleActionsActionTypeStartTransactionConfig Int
    | GotStartTransactionIdTag Int A.CPModuleActionsActionTypeStartTransactionConfig String
    | GotStopTransactionIdTag Int A.CPModuleActionsActionTypeStopTransactionConfig String
    | GotChargePeriodVehiclePowerCapacity Int A.CPModuleActionsActionTypeChargePeriodConfig Int
    | GotChargePeriodPeriod Int A.CPModuleActionsActionTypeChargePeriodConfig Int
    | GotChargePeriodVehicleBatteryCapacity Int A.CPModuleActionsActionTypeChargePeriodConfig Int
    | GotChargePeriodInitialVehicleCharge Int A.CPModuleActionsActionTypeChargePeriodConfig Float
    | GotChargePeriodSpeedup Int A.CPModuleActionsActionTypeChargePeriodConfig A.CPModuleActionsActionTypeChargePeriodConfigSpeedup
    | GotDelayInterval Int A.CPModuleActionsActionTypeDelayConfig Int
    | GotNewElement NewElement
    | GotDeleteElement Int


update : Msg -> Model -> Model
update msg model =
    case msg of
        SwitchToTab tab ->
            { model | selectedTab = tab }

        InsertDragDropMsg subMsg ->
            let
                ( dragDropModel, result ) =
                    DragDrop.update subMsg model.insertDragDrop
            in
            case result of
                Nothing ->
                    { model | insertDragDrop = dragDropModel }

                Just ( newEl, ind, _ ) ->
                    { model
                        | insertDragDrop = dragDropModel
                        , actions = List.take ind model.actions ++ updateNewElToActions newEl ++ List.drop ind model.actions
                    }

        ReorderDragDropMsg subMsg ->
            let
                ( dragDropModel, result ) =
                    DragDrop.update subMsg model.reorderDragDrop
            in
            case result of
                Nothing ->
                    { model | reorderDragDrop = dragDropModel }

                Just ( ( movedAction, fromInd ), toInd, _ ) ->
                    let
                        indexedActions =
                            List.indexedMap Tuple.pair model.actions

                        reorderedActions =
                            List.foldr
                                (\( ind, action ) acc ->
                                    if fromInd == ind then
                                        acc

                                    else if toInd == ind then
                                        movedAction :: (action :: acc)

                                    else
                                        action :: acc
                                )
                                []
                                indexedActions
                    in
                    { model
                        | reorderDragDrop = dragDropModel
                        , actions = reorderedActions
                    }

        GotStatusChangeConnector ind cfg int ->
            updateAction ind (A.STATUS_CHANGE { cfg | connector = int }) model

        GotStatusChangeStatus ind cfg status ->
            updateAction ind (A.STATUS_CHANGE { cfg | status = status }) model

        GotAuthorizeIdTag ind cfg str ->
            updateAction ind (A.AUTHORIZE { cfg | idTag = str }) model

        GotStartTransactionConnector ind cfg int ->
            updateAction ind (A.START_TRANSACTION { cfg | connector = int }) model

        GotStartTransactionIdTag ind cfg str ->
            updateAction ind (A.START_TRANSACTION { cfg | idTag = str }) model

        GotStopTransactionIdTag ind cfg str ->
            updateAction ind (A.STOP_TRANSACTION { cfg | idTag = str }) model

        GotChargePeriodVehiclePowerCapacity ind cfg int ->
            updateAction ind (A.CHARGE_PERIOD { cfg | vehiclePowerCapacity = int } Nothing) model

        GotChargePeriodPeriod ind cfg int ->
            updateAction ind (A.CHARGE_PERIOD { cfg | period = int } Nothing) model

        GotChargePeriodVehicleBatteryCapacity ind cfg int ->
            updateAction ind (A.CHARGE_PERIOD { cfg | vehicleBatteryCapacity = int } Nothing) model

        GotChargePeriodInitialVehicleCharge ind cfg float ->
            updateAction ind (A.CHARGE_PERIOD { cfg | initialVehicleCharge = float } Nothing) model

        GotChargePeriodSpeedup ind cfg speedup ->
            updateAction ind (A.CHARGE_PERIOD { cfg | speedup = speedup } Nothing) model

        GotDelayInterval ind cfg int ->
            updateAction ind (A.DELAY { cfg | interval = int }) model

        GotNewElement newEl ->
            { model | actions = model.actions ++ updateNewElToActions newEl }

        GotDeleteElement ind ->
            { model | actions = List.take ind model.actions ++ List.drop (ind + 1) model.actions }


updateNewElToActions : NewElement -> List A.CPModuleActionsAction
updateNewElToActions newEl =
    case newEl of
        NewAction action ->
            [ action ]

        NewTemplate tpl ->
            template tpl


updateAction : Int -> A.CPModuleActionsActionType -> Model -> Model
updateAction ind typ af =
    { af | actions = listUpdateOnInd ind (\x -> { x | typ = typ }) af.actions }


listUpdateOnInd : Int -> (a -> a) -> List a -> List a
listUpdateOnInd ind upd list =
    List.indexedMap
        (\currentInd currentValue ->
            if currentInd == ind then
                upd currentValue

            else
                currentValue
        )
        list


fillBgColor : Css.Style
fillBgColor =
    Css.backgroundColor <| Css.hex "c2c2c2"


fillBorderColor : Css.Style
fillBorderColor =
    Css.borderColor <| Css.hex "606060"


ghostBgColor : Css.Style
ghostBgColor =
    Css.backgroundColor <| Css.hex "e6e6e6"


ghostBorderColor : Css.Style
ghostBorderColor =
    Css.borderColor <| Css.hex "848484"


view : Model -> Html Msg
view model =
    let
        maybeInsertDropInfo =
            Maybe.map2
                Tuple.pair
                (DragDrop.getDragId model.insertDragDrop)
                (DragDrop.getDropId model.insertDragDrop)

        maybeReorderDropInfo =
            Maybe.map2
                Tuple.pair
                (DragDrop.getDragId model.reorderDragDrop)
                (DragDrop.getDropId model.reorderDragDrop)
    in
    div [ class "d-flex" ]
        [ viewForm maybeInsertDropInfo maybeReorderDropInfo model.actions
        , viewToolbox model.selectedTab
        ]


viewForm : Maybe ( NewElement, Int ) -> Maybe ( ( CPModuleActionsAction, Int ), Int ) -> List CPModuleActionsAction -> Html Msg
viewForm maybeInsertDropInfo maybeReorderDropInfo actions =
    let
        maybeDroppable =
            if List.isEmpty actions then
                DragDrop.droppable InsertDragDropMsg 0 |> List.map Html.Styled.Attributes.fromUnstyled

            else
                []
    in
    div (class "p-3 bg-light flex-grow-1 me-3" :: maybeDroppable) <| List.indexedMap (actionItem maybeInsertDropInfo maybeReorderDropInfo) actions


actionItem : Maybe ( NewElement, Int ) -> Maybe ( ( CPModuleActionsAction, Int ), Int ) -> Int -> CPModuleActionsAction -> Html Msg
actionItem maybeInsertDropInfo maybeReorderDropInfo ind action =
    let
        maybeInsertDropGhost =
            Maybe.map
                (\( newEl, dropInd ) ->
                    if dropInd == ind then
                        case newEl of
                            NewAction act ->
                                [ ghostActionItemForm ind act ]

                            NewTemplate tpl ->
                                []

                    else
                        []
                )
                maybeInsertDropInfo
                |> Maybe.withDefault []

        maybeReorderDropGhost =
            Maybe.map
                (\( ( movedAction, fromInd ), toInd ) ->
                    if toInd == ind then
                        [ ghostActionItemForm ind movedAction ]

                    else
                        []
                )
                maybeReorderDropInfo
                |> Maybe.withDefault []

        maybeRealForm =
            Maybe.map
                (\( ( movedAction, fromInd ), toInd ) ->
                    if fromInd == ind then
                        []

                    else
                        [ realActionItemForm ind action ]
                )
                maybeReorderDropInfo
                |> Maybe.withDefault [ realActionItemForm ind action ]
    in
    div [] (maybeReorderDropGhost ++ maybeInsertDropGhost ++ maybeRealForm)


realActionItemForm : Int -> CPModuleActionsAction -> Html Msg
realActionItemForm =
    actionItemForm (Css.borderStyle Css.solid) fillBorderColor fillBgColor


ghostActionItemForm : Int -> CPModuleActionsAction -> Html Msg
ghostActionItemForm =
    actionItemForm (Css.borderStyle Css.dashed) ghostBorderColor ghostBgColor


actionItemForm : Css.Style -> Css.Style -> Css.Style -> Int -> CPModuleActionsAction -> Html Msg
actionItemForm borderStyle borderColor bgColor ind action =
    let
        insertDroppable =
            DragDrop.droppable InsertDragDropMsg ind

        reorderDroppable =
            DragDrop.droppable ReorderDragDropMsg ind

        reorderDraggable =
            DragDrop.draggable ReorderDragDropMsg ( action, ind )

        dragDroppable =
            insertDroppable
                ++ reorderDroppable
                ++ reorderDraggable
                |> List.map Html.Styled.Attributes.fromUnstyled
    in
    div
        ([ class "my-3 p-1 border-3 rounded-3", css [ borderStyle, borderColor, bgColor ] ]
            ++ dragDroppable
        )
        [ div [ class "d-flex" ]
            [ h4 [ class "flex-grow-1" ] [ text <| actionTitle action ]
            , button [ class "form-control mx-1", type_ "button", onClick (GotDeleteElement ind), css [ Css.borderStyle Css.none, Css.width (Css.px 100), bgColor ] ] [ i [ class "fas fa-times", css [ Css.color <| Css.hex "ff5555" ] ] [] ]
            ]
        , div [ class "d-flex flex-wrap align-content-around align-items-center" ] <| actionInputs ind action
        ]


actionTitle : CPModuleActionsAction -> String
actionTitle action =
    case action.typ of
        A.STATUS_CHANGE _ ->
            "Status Change"

        A.AUTHORIZE _ ->
            "Authorize"

        A.START_TRANSACTION _ ->
            "Start Transaction"

        A.STOP_TRANSACTION _ ->
            "Stop Transaction"

        A.CHARGE_PERIOD _ _ ->
            "Charge Period"

        A.DELAY _ ->
            "Delay"


actionInputs : Int -> CPModuleActionsAction -> List (Html Msg)
actionInputs ind action =
    case action.typ of
        A.STATUS_CHANGE cfg ->
            [ viewIntInput "connector" "Connector" cfg.connector (GotStatusChangeConnector ind cfg)
            , div [ class "mb-1 d-inline-flex align-items-center me-5" ]
                [ label [ class "form-label me-1 text-end", css [ Css.width (Css.px 230) ] ] [ text "Connector OCPP Status:" ]
                , viewTypedSelect CS.options CS.humanString CS.fromString CS.toString cfg.status (GotStatusChangeStatus ind cfg)
                ]
            ]

        A.AUTHORIZE cfg ->
            [ viewTextInput "id_tag" "ID Tag" cfg.idTag (GotAuthorizeIdTag ind cfg) ]

        A.START_TRANSACTION cfg ->
            [ viewIntInput "connector" "Connector" cfg.connector (GotStartTransactionConnector ind cfg)
            , viewTextInput "id_tag" "ID Tag" cfg.idTag (GotStartTransactionIdTag ind cfg)
            ]

        A.STOP_TRANSACTION cfg ->
            [ viewTextInput "id_tag" "ID Tag" cfg.idTag (GotStopTransactionIdTag ind cfg) ]

        A.CHARGE_PERIOD cfg _ ->
            [ viewIntInput "vehicle_power_capacity" "Vehicle Power Capacity (Power Limit, W)" cfg.vehiclePowerCapacity (GotChargePeriodVehiclePowerCapacity ind cfg)
            , viewIntInput "period" "Period (s)" cfg.period (GotChargePeriodPeriod ind cfg)
            , viewIntInput "vehicle_battery_capacity" "Vehicle Battery Capacity (Charging Limit, Wh)" cfg.vehicleBatteryCapacity (GotChargePeriodVehicleBatteryCapacity ind cfg)
            , viewFloatInput "initial_vehicle_charge" "Initial Vehicle Charge (Wh)" cfg.initialVehicleCharge (GotChargePeriodInitialVehicleCharge ind cfg)

            -- TODO: speedup typed select
            ]
                ++ speedupCoeffInput ind cfg

        A.DELAY cfg ->
            [ viewIntInput "interval" "Interval" cfg.interval (GotDelayInterval ind cfg) ]


speedupCoeffInput : Int -> A.CPModuleActionsActionTypeChargePeriodConfig -> List (Html Msg)
speedupCoeffInput ind cfg =
    case cfg.speedup of
        A.IncreasePower coeff ->
            [ viewFloatInput "speedup_increase_power_coeff" "Speedup coefficient (more than 1.0 means faster)" coeff (A.IncreasePower >> GotChargePeriodSpeedup ind cfg) ]

        A.TimeDilation coeff ->
            [ viewFloatInput "speedup_time_dilation_coeff" "Speedup coefficient (more than 1.0 means faster)" coeff (A.IncreasePower >> GotChargePeriodSpeedup ind cfg) ]

        A.None ->
            []


viewToolbox : Tab -> Html Msg
viewToolbox tab =
    div [ css [ Css.minWidth (Css.px 250) ] ]
        [ ul [ class "nav nav-tabs" ]
            [ li [ class "nav-item" ] [ button [ type_ "button", class "nav-link", classList [ ( "active", tab == Template ) ], onClick (SwitchToTab Template) ] [ text "Templates" ] ]
            , li [ class "nav-item" ] [ button [ type_ "button", class "nav-link", classList [ ( "active", tab == Actions ) ], onClick (SwitchToTab Actions) ] [ text "Actions" ] ]
            ]
        , viewToolboxContent tab
        ]


viewToolboxContent : Tab -> Html Msg
viewToolboxContent tab =
    div [] <|
        case tab of
            Template ->
                [ viewToolboxTemplate "Vehicle Charge" (NewTemplate VehicleCharge)
                ]

            Actions ->
                [ viewToolboxAction "Status Change" (NewAction defaultStatusChange)
                , viewToolboxAction "Authorize" (NewAction defaultAuthorize)
                , viewToolboxAction "Start Transaction" (NewAction defaultStartTransaction)
                , viewToolboxAction "Stop Transaction" (NewAction defaultStopTransaction)
                , viewToolboxAction "Charge Period" (NewAction defaultChargePeriod)
                , viewToolboxAction "Delay" (NewAction defaultDelay)
                ]


viewToolboxAction : String -> NewElement -> Html Msg
viewToolboxAction title newEl =
    let
        draggable =
            DragDrop.draggable InsertDragDropMsg newEl |> List.map Html.Styled.Attributes.fromUnstyled
    in
    div
        ([ class "my-3 p-1 border border-3 rounded-3", css [ fillBgColor, Css.important fillBorderColor ] ]
            ++ draggable
        )
        [ span [] [ text title ]
        , button [ class "form-control", type_ "button", onClick (GotNewElement newEl), css [ Css.borderStyle Css.none, fillBgColor ] ] [ i [ class "fas fa-plus" ] [ text "Add" ] ]
        ]


viewToolboxTemplate : String -> NewElement -> Html Msg
viewToolboxTemplate title newEl =
    let
        draggable =
            DragDrop.draggable InsertDragDropMsg newEl |> List.map Html.Styled.Attributes.fromUnstyled
    in
    div
        ([ class "my-3 p-1 border border-3 rounded-3", css [ fillBgColor, Css.important fillBorderColor ] ]
            ++ draggable
        )
        [ span [] [ text title ]
        , button [ class "form-control", type_ "button", onClick (GotNewElement newEl), css [ Css.borderStyle Css.none, fillBgColor ] ] [ i [ class "fas fa-plus" ] [ text "Add" ] ]
        ]


viewTextInput : String -> String -> String -> (String -> Msg) -> Html Msg
viewTextInput n t v e =
    div [ class "mb-1 d-inline-flex align-items-center me-5" ]
        [ label [ class "form-label me-1 text-end", css [ Css.width (Css.px 230) ], for n ] [ text <| t ++ ":" ]
        , input [ class "form-control", id n, type_ "text", value v, onInput e ] []
        ]


viewIntInput : String -> String -> Int -> (Int -> Msg) -> Html Msg
viewIntInput n t v e =
    div [ class "mb-1 d-inline-flex align-items-center me-5" ]
        [ label [ class "form-label me-1 text-end", css [ Css.width (Css.px 230) ], for n ] [ text <| t ++ ":" ]
        , input [ class "form-control", id n, type_ "number", value (String.fromInt v), onInput (String.toInt >> Maybe.withDefault v >> e) ] []
        ]


viewFloatInput : String -> String -> Float -> (Float -> Msg) -> Html Msg
viewFloatInput n t v e =
    div [ class "mb-1 d-inline-flex align-items-center me-5" ]
        [ label [ class "form-label me-1 text-end", css [ Css.width (Css.px 230) ], for n ] [ text <| t ++ ":" ]
        , input [ class "form-control", id n, type_ "number", value (String.fromFloat v), onInput (String.toFloat >> Maybe.withDefault v >> e) ] []
        ]


viewTypedSelect : List a -> (a -> String) -> (String -> a) -> (a -> String) -> a -> (a -> Msg) -> Html Msg
viewTypedSelect options format from to v e =
    select [ class "form-select", onInput (from >> e) ] <|
        List.map (viewTypedSelectOption format to v) options


viewTypedSelectOption : (a -> String) -> (a -> String) -> a -> a -> Html Msg
viewTypedSelectOption format to sel v =
    option [ value (to v), selected (v == sel) ] [ text (format v) ]
