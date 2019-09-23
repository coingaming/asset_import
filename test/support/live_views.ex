alias AssetImportTest.{ClockLive, ClockControlsLive}

defmodule AssetImportTest.ThermostatLive do
  use Phoenix.LiveView, container: {:article, class: "thermo"}, namespace: AssetImportTest
  use AssetImportTest.Assets

  def render(assigns) do
    ~L"""
    <% asset_import "thermostat" %>
    The temp is: <%= @val %><%= @greeting %>
    <button phx-click="dec">-</button>
    <button phx-click="inc">+</button><%= if @nest do %>
      <%= live_render(@socket, ClockLive, [id: :clock] ++ @nest) %>
      <%= for user <- @users do %>
        <i><%= user.name %> <%= user.email %></i>
      <% end %>
    <% end %>
    """
  end

  def mount(session, socket) do
    nest = Map.get(session, :nest, false)
    users = session[:users] || []
    val = if connected?(socket), do: 1, else: 0

    {:ok,
     assign(socket,
       val: val,
       nest: nest,
       redir: session[:redir],
       users: users,
       greeting: nil
     )}
  end

  @key_i 73
  @key_d 68
  def handle_event("key", @key_i, socket) do
    {:noreply, update(socket, :val, &(&1 + 1))}
  end

  def handle_event("key", @key_d, socket) do
    {:noreply, update(socket, :val, &(&1 - 1))}
  end

  def handle_event("save", %{"temp" => new_temp} = params, socket) do
    {:noreply, assign(socket, val: new_temp, greeting: inspect(params["_target"]))}
  end

  def handle_event("save", new_temp, socket) do
    {:noreply, assign(socket, :val, new_temp)}
  end

  def handle_event("redir", to, socket) do
    {:stop, redirect(socket, to: to)}
  end

  def handle_event("inactive", msg, socket) do
    {:noreply, assign(socket, :greeting, "Tap to wake – #{msg}")}
  end

  def handle_event("active", msg, socket) do
    {:noreply, assign(socket, :greeting, "Waking up – #{msg}")}
  end

  def handle_event("noop", _, socket), do: {:noreply, socket}

  def handle_event("inc", _, socket), do: {:noreply, update(socket, :val, &(&1 + 1))}

  def handle_event("dec", _, socket), do: {:noreply, update(socket, :val, &(&1 - 1))}

  def handle_info(:noop, socket), do: {:noreply, socket}

  def handle_info({:redir, to}, socket) do
    {:stop, redirect(socket, to: to)}
  end

  def handle_call({:set, var, val}, _, socket) do
    {:reply, :ok, assign(socket, var, val)}
  end
end

defmodule AssetImportTest.ClockLive do
  use Phoenix.LiveView, container: {:section, class: "clock"}
  use AssetImportTest.Assets

  def render(assigns) do
    ~L"""
    <% asset_import "thermostat/clock" %>
    time: <%= @time %> <%= @name %>
    <%= live_render(@socket, ClockControlsLive, id: :"#{String.replace(@name, " ", "-")}-controls") %>
    """
  end

  def mount(session, socket) do
    {:ok, assign(socket, time: "12:00", name: session[:name] || "NY")}
  end

  def handle_info(:snooze, socket) do
    {:noreply, assign(socket, :time, "12:05")}
  end

  def handle_info({:run, func}, socket) do
    func.(socket)
  end

  def handle_call({:set, new_time}, _from, socket) do
    {:reply, :ok, assign(socket, :time, new_time)}
  end
end

defmodule AssetImportTest.ClockControlsLive do
  use Phoenix.LiveView
  use AssetImportTest.Assets

  def render(assigns = %{connected: false}) do
    ~L"""
    <% asset_import "thermostat/clock/static_controls" %>
    <button phx-click="snooze">+</button>
    """
  end

  def render(assigns = %{connected: true}) do
    ~L"""
    <% asset_import "thermostat/clock/live_controls" %>
    <button phx-click="snooze">+</button>
    """
  end

  def mount(_session, socket), do: {:ok, socket |> assign(:connected, connected?(socket))}

  def handle_event("snooze", _, socket) do
    send(socket.parent_pid, :snooze)
    {:noreply, socket}
  end
end
