import { Socket, Presence } from "./assets/phoenix/phoenix.esm.js";
import ElmPhoenixWebSocket from "./assets/elm-phoenix-websocket/elmPhoenixWebSocket.js";

var app = Elm.Main.init();
ElmPhoenixWebSocket.init(app.ports, Socket, Presence);
