defmodule AssetImportTest.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", AssetImportTest do
    pipe_through([:browser])

    # live view test
    live("/thermo", ThermostatLive, session: [:nest, :users, :redir])
    live("/thermo/:id", ThermostatLive, session: [:nest, :users, :redir])

    live("/thermo-container", ThermostatLive,
      session: [:nest],
      container: {:span, style: "thermo-flex<script>"}
    )
  end
end
