defmodule AssetImport.EndpointsWriter do
  @moduledoc """
  This server is required to make the write at the end of the compile process.
  It monitors a compiler process and performs write (and stops itself) when compiler process exits.
  """
  use GenServer

  def write(pid) do
    GenServer.start(__MODULE__, pid, name: __MODULE__)
  end

  def init(pid) do
    {:ok, pid, {:continue, :more_init}}
  end

  def handle_continue(:more_init, pid) do
    {:noreply, {pid, Process.monitor(pid)}}
  end

  def handle_info({:DOWN, _, :process, _, _}, state) do
    do_write()
    {:stop, :normal, state}
  end

  defp do_write do
    content = Jason.encode!(AssetImport.get_asset_imports(), pretty: true)
    file_path = Application.get_env(:asset_import, :assets_path) |> Path.join("entrypoints.json")

    case File.read(file_path) do
      {:ok, ^content} ->
        :ok

      _ ->
        :ok = File.write(file_path, content)
    end
  end
end
