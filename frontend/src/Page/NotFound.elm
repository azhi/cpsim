module Page.NotFound exposing (view)

import Html
import Html.Styled exposing (..)



-- VIEW


view : { title : String, content : Html msg }
view =
    { title = "Page Not Found"
    , content =
        div [] [ text "Not Found" ]
    }
