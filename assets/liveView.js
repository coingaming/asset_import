import LiveSocket from "phoenix_live_view"
import Socket from "phoenix"
import AssetImport from "./assetImport"

let liveSocket = new LiveSocket("/live", Socket, {AssetImport})
liveSocket.connect()
