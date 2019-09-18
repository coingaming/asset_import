defmodule AutoAssetsTest do
  use ExUnit.Case

  use AutoAssets.Assets

  defmodule Sub do
    use AutoAssets.Assets

    def hello do
      import_assets("from")
      import_assets("sub")
    end
  end

  test "import_assets/1" do
    import_assets("hello")
    import_assets("world")

    assert MapSet.new(["hello", "world"]) == AutoAssets.imports()

    assert MapSet.new(["hello", "world", "from", "sub"]) ==
             AutoAssets.get_asset_imports(__MODULE__)
  end
end
