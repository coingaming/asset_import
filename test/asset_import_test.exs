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

    assert_asset_imports(["hello", "world"], AssetImport.current_imports())

    assert_registered_imports(
      ["hello", "world", "from", "sub", "and", "some", "other", "module"],
      AssetImport.get_asset_imports()
    )
  end

  test "scripts/0" do
    asset_import("hello")
    asset_import("world")

    assert_asset_imports(["hello", "world"], AssetImport.current_imports())

    assert is_list(scripts())
    assert is_list(styles())

    assert is_binary(render_scripts())
    assert is_binary(render_styles())
  end

  defp assert_asset_imports(names, assets) do
    assert assets == names |> Enum.reduce(MapSet.new(), fn name, acc ->
      file = name_to_file(name)
      MapSet.put(acc, hash(file))
    end)
  end

  defp assert_registered_imports(names, assets) do
    assert assets == names |> Enum.reduce(%{}, fn name, acc ->
      file = name_to_file(name)
      Map.put(acc, hash(file), file)
    end)
  end

  defp name_to_file(name) do
    file =
      File.cwd!()
      |> Path.join("assets")
      |> Path.join(name)
      |> Path.relative_to(Application.get_env(:asset_import, :assets_path))

    if String.starts_with?(file, "/") do
      file
    else
      Path.join(".", file)
    end
  end

  defp hash(value) do
    :crypto.hash(:sha256, value)
    |> Base.encode64(padding: false)
    |> String.replace(~r/[^a-zA-Z0-9]+/, "")
    |> String.slice(0..7)
  end
end
