import Config

config :asset_import,
  assets_path: File.cwd!() |> Path.join("assets")
