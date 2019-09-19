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

    assert MapSet.new(["hello", "world"]) == AssetImport.imports()

    assert MapSet.new(["hello", "world", "from", "sub", "and", "some", "other", "module"]) ==
             AssetImport.get_asset_imports()
  end
end
