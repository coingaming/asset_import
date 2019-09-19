import Config

config :asset_import,
  entrypoints_file: File.cwd!() |> Path.join("assets/entrypoints.json")
