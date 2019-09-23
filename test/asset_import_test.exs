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

  test "asset_import/1 success" do
    asset_import("hello")
    asset_import("world")

    assert_current_imports(["hello", "world"])
    assert_registered_imports(["hello", "world", "from", "sub", "and", "some", "other", "module"])
  end

  test "asset_import/1 asset not found" do
    asset_import("hello")

    assert_raise CompileError, fn ->
      quote do
        asset_import("nonexistent")
      end
      |> Code.eval_quoted()
    end

    assert_current_imports(["hello"])
  end

  test "scripts/0" do
    asset_import("hello")
    asset_import("world")

    assert_current_imports(["hello", "world"])
    assert [_, _, _, _] = scripts()
    assert [_] = styles()
  end

  defp assert_current_imports(expected_names) do
    expected_assets =
      Enum.reduce(expected_names, MapSet.new(), &MapSet.put(&2, hash(name_to_file(&1))))

    assert AssetImport.current_imports() == expected_assets
  end

  defp assert_registered_imports(expected_names) do
    expected_assets =
      expected_names
      |> Enum.reduce(%{}, fn name, acc ->
        file = name_to_file(name)
        Map.put(acc, hash(file), file)
      end)

    assert AssetImport.get_asset_imports() == expected_assets
  end

  defp name_to_file(name) do
    File.cwd!()
    |> Path.join("assets")
    |> Path.join(name)
    |> Path.relative_to(Application.get_env(:asset_import, :assets_path))
    |> case do
      file = "/" <> _ ->
        file

      file ->
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
