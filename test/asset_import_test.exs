defmodule AssetImportTest do
  use ExUnit.Case
  use AssetImportTest.Assets
  use Phoenix.ConnTest

  import Phoenix.LiveViewTest

  # alias Phoenix.LiveView
  # alias Phoenix.LiveViewTest.DOM
  alias AssetImportTest.Endpoint
  # , ClockLive, ClockControlsLive}

  @endpoint Endpoint
  @moduletag :capture_log

  setup config do
    {:ok,
     conn: Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), config[:session] || %{})}
  end

  defmodule Sub do
    use AssetImportTest.Assets

    def hello do
      asset_import("from")
      asset_import("sub")
    end
  end

  describe "asset_import/1" do
    test "all registered imports" do
      asset_import("hello")
      asset_import("world")

      assert_registered_imports([
        "hello",
        "world",
        "from",
        "sub",
        "and",
        "some",
        "other",
        "module",
        "thermostat",
        "thermostat/clock",
        "thermostat/clock/static_controls",
        "thermostat/clock/live_controls"
      ])
    end

    test "current imports" do
      asset_import("hello")
      asset_import("world")

      assert_current_imports(["hello", "world"])
    end

    test "asset not found" do
      asset_import("hello")

      assert_raise CompileError, fn ->
        quote do
          asset_import("nonexistent")
        end
        |> Code.eval_quoted()
      end

      assert_current_imports(["hello"])
    end
  end

  describe "live view" do
    @tag session: %{nest: []}
    test "static render", %{conn: conn} do
      conn = get(conn, "/thermo")
      assert html_response(conn, 200) =~ "The temp is: 0"

      {:ok, _view, html} = live(conn)
      assert html =~ "The temp is: 1"

      assert_current_imports([
        "thermostat",
        "thermostat/clock",
        "thermostat/clock/static_controls"
      ])
    end

    test "live render", %{conn: conn} do
      conn = get(conn, "/thermo")
      assert html_response(conn, 200) =~ "The temp is: 0"

      {:ok, _view, html} = live(conn)
      assert html =~ "The temp is: 1"

      assert_current_imports([
        "thermostat"
      ])
    end
  end

  test "asset_script_files/0 and asset_style_files/0" do
    asset_import("hello")
    asset_import("world")

    assert_current_imports(["hello", "world"])
    assert [_, _, _, _] = asset_script_files()
    assert [_] = asset_style_files()
  end

  defp assert_current_imports(expected_names) do
    expected_assets =
      Enum.reduce(expected_names, MapSet.new(), &MapSet.put(&2, hash(name_to_file(&1))))

    assert expected_assets == AssetImport.current_imports()
  end

  defp assert_registered_imports(expected_names) do
    expected_assets =
      expected_names
      |> Enum.reduce(%{}, fn name, acc ->
        file = name_to_file(name)
        Map.put(acc, hash(file), file)
      end)

    assert {:ok, expected_assets} == AssetImport.registered_imports(AssetImportTest.Assets)
  end

  defp name_to_file(name) do
    File.cwd!()
    |> Path.join("assets")
    |> Path.join(name)
    |> Path.relative_to(
      :asset_import
      |> Application.get_env(AssetImportTest.Assets)
      |> Keyword.get(:assets_path)
    )
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
