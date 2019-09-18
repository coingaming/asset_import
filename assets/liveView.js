import LiveSocket from "phoenix_live_view"
import Socket from "phoenix"

let liveSocket = new LiveSocket("/live", Socket)
liveSocket.connect()
