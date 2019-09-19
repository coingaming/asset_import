defmodule AssetImportTest do
  use ExUnit.Case

  use AssetImport.Assets

  defmodule Sub do
    use AssetImport.Assets

    def hello do
      asset_import("from")
      asset_import("sub")
    end
  end

  test "asset_import/1" do
    asset_import("hello")
    asset_import("world")

    assert_asset_imports(["hello", "world"], AssetImport.imports())

    assert_registered_imports(
      ["hello", "world", "from", "sub", "and", "some", "other", "module"],
      AssetImport.get_asset_imports()
    )
  end

  defp assert_asset_imports(names, assets) do
    cwd = File.cwd!()

    assert assets ==
             names
             |> Enum.reduce(MapSet.new(), fn el, acc ->
               file =
                 Path.join(".", cwd
                 |> Path.join("assets")
                 |> Path.join(el)
                 |> Path.relative_to(Application.get_env(:asset_import, :assets_path)))

               MapSet.put(acc, hash(file))
             end)
  end

  defp assert_registered_imports(names, assets) do
    cwd = File.cwd!()

    assert assets ==
             names
             |> Enum.reduce(%{}, fn el, acc ->
              file =
                Path.join(".", cwd
                |> Path.join("assets")
                |> Path.join(el)
                |> Path.relative_to(Application.get_env(:asset_import, :assets_path)))

               Map.put(acc, hash(file), file)
             end)
  end

  defp hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode64(padding: false)
    |> String.replace(~r/[^a-zA-Z0-9]+/, "")
    |> String.slice(0..7)
  end
end
