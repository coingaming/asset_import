defmodule AssetImport.EndpointsWriter do
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
    {:noreply, state}
  end

  def do_write do
    content = Jason.encode!(AssetImport.get_asset_imports(), pretty: true)
    entrypoints_file = Application.get_env(:asset_import, :entrypoints_file)

    case File.read(entrypoints_file) do
      {:ok, ^content} ->
        :ok

      _ ->
        :ok = File.write(entrypoints_file, content)
    end
  end

end
