defmodule Inky do
  @moduledoc """
  The Inky module provides the public API for interacting with the display.
  """

  use GenServer

  require Integer
  require Logger

  alias Inky.Displays.Display
  alias Inky.RpiCommands

  @push_timeout 5000

  defmodule State do
    @moduledoc false
    @enforce_keys [:display, :hal_state]
    defstruct type: nil,
              hal_state: nil,
              display: nil,
              wait_type: :nowait,
              pixels: %{},
              hal_mod: RpiCommands
  end

  #
  # API
  #

  @doc """
  Start a GenServer that deals with the HAL state (initialization of and communication with the display) and pushing pixels to the physical display. This function will do some of the necessary preparation to enable communication with the display.

  ## Parameters

    - type: Atom for either :phat or :what
    - accent: Accent color, the color the display supports aside form white and black. Atom, :black, :red or :yellow.
  """
  def start_link(args \\ %{}) do
    opts = if(args[:name], do: [name: args[:name]], else: [])
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  `set_pixels(pid | name, pixels | painter, opts \\ %{push: :await})` set
  pixels and draw to display (or not!), with data or a painter function.

  set_pixels updates the internal state either with specific pixels or by
  calling `painter.(x,y,w,h,current_pixels)` for all points in the screen, in
  an undefined order.

  Currently, the only option checked is `:push`, which represents the minimum
  pixel pushing policy the caller wishes to apply for their request. Valid
  values are listed and explained below.

  NOTE: the internal state of Inky will still be updated, regardless of which
  pushing policy is employed.

  - `:await`: Busy wait until you can push to display, clearing any previously
    set timeout. This is the default.
  - `:once`: Push to the display if it is not busy, otherwise, report that it
    was busy. Only `:await` timeouts are reset if a `:once` push has failed.
  - `{:timeout, :await}`: Use genserver timeouts to avoid multiple updates.
    When the timeout triggers, await device with a busy wait and then push to
    the display. If the timeout previously was :once, it is replaced.
  - `{:timeout, :once}`: Use genserver timeouts to avoid multiple updates. When
    the timeout triggers, update the display if not busy. Does not downgrade a
    previously set `:await` timeout.
  - `:skip`: Do not push to display. If there has been a timeout previously
    set, but that has yet to fire, it will remain set.
  """
  def set_pixels(pid, arg, opts \\ %{}),
    do: GenServer.call(pid, {:set_pixels, arg, opts}, :infinity)

  def show(server, opts \\ %{}) do
    if opts[:async] === true,
      do: GenServer.cast(server, :push),
      else: GenServer.call(server, :push, :infinity)
  end

  def stop(server) do
    GenServer.stop(server)
  end

  #
  # GenServer callbacks
  #

  @impl GenServer
  def init(args) do
    type = Map.fetch!(args, :type)
    accent = Map.fetch!(args, :accent)
    hal_mod = args[:hal_mod] || RpiCommands

    display = Display.spec_for(type, accent)

    hal_state =
      hal_mod.init(%{
        display: display
      })

    {:ok,
     %State{
       hal_mod: hal_mod,
       display: display,
       hal_state: hal_state
     }}
  end

  # GenServer calls

  @impl GenServer
  def handle_call({:set_pixels, arg, opts}, _from, state) do
    state = %State{state | pixels: update_pixels(arg, state)}
    dispatch_push(opts[:push] || :await, state)
  end

  def handle_call(:push, _from, state) do
    {:reply, push(:await, state), state}
  end

  def handle_call(request, from, state) do
    Logger.warn("Dropping unexpected call #{inspect(request)} from #{inspect(from)}")
    {:reply, :ok, state}
  end

  # GenServer casts

  @impl GenServer
  def handle_cast(:push, state) do
    push(:await, state)
    {:noreply, state}
  end

  def handle_cast(request, state) do
    Logger.warn("Dropping unexpected cast #{inspect(request)}")
    {:noreply, state}
  end

  # GenServer messages

  @impl GenServer
  def handle_info(:timeout, state) do
    case push(state.wait_type, state) do
      {:error, reason} -> Logger.error("Failed to push graph on timeout: #{inspect(reason)}")
      :ok -> :ok
    end

    {:noreply, %State{state | wait_type: :nowait}}
  end

  def handle_info(msg, state) do
    Logger.error("Dropping unexpected info message #{inspect(msg)}")
    {:noreply, state}
  end

  #
  # Internal
  #

  # Set pixels

  defp update_pixels(arg, state) do
    case arg do
      arg when is_map(arg) ->
        handle_set_pixels_map(arg, state)

      arg when is_function(arg, 5) ->
        handle_set_pixels_fun(arg, state)
    end
  end

  defp handle_set_pixels_map(pixels, state) do
    Map.merge(state.pixels, pixels)
  end

  defp handle_set_pixels_fun(painter, state) do
    %Display{width: w, height: h} = state.display

    stream_points(w, h)
    |> Enum.reduce(state.pixels, fn {x, y}, acc ->
      Map.put(acc, {x, y}, painter.(x, y, w, h, acc))
    end)
  end

  defp stream_points(w, h) do
    Stream.resource(
      fn -> {{0, 0}, {w - 1, h - 1}} end,
      fn
        {{w, h}, {w, h}} -> {:halt, {w, h}}
        {{w, y}, {w, h}} -> {[{w, y}], {{0, y + 1}, {w, h}}}
        {{x, y}, {w, h}} -> {[{x, y}], {{x + 1, y}, {w, h}}}
      end,
      fn _ -> :ok end
    )
  end

  defp dispatch_push(push_policy, state) do
    case {push_policy, state.wait_type} do
      # attempt until successful
      {:await, _} -> push_await(state)
      # attempt once, then re-set timer if device was busy
      {:once, :await} -> push(push_policy, state) |> push_once_await(state)
      # attempt once, then clear timer, as that was the intention
      {:once, :once} -> push_once(state)
      # attempt once, then give up
      {:once, :nowait} -> push_once(state)
      # no attempt to push
      {:skip, :nowait} -> reply_only(:ok, state)
      # elevate timeout type or respect the one previously set
      {:skip, wt} -> reply_timeout(:ok, wt, state)
      {{:timeout, :await}, _} -> reply_timeout(:ok, :await, state)
      {{:timeout, :once}, _} -> reply_timeout(:ok, :once, state)
    end
  end

  defp push_await(state) do
    push(:await, state) |> reply_only(state)
  end

  defp push_once_await(res = {:error, :device_busy}, state), do: reply_timeout(res, :await, state)
  defp push_once_await(res, state), do: reply_only(res, state)

  defp push_once(state) do
    push(:once, state) |> reply_only(state)
  end

  defp reply_only(response, state), do: {:reply, response, %State{state | wait_type: :nowait}}

  defp reply_timeout(response, timeout_policy, state) do
    {:reply, response, %State{state | wait_type: timeout_policy}, @push_timeout}
  end

  # Internals

  defp push(push_policy, state) do
    hm = state.hal_mod
    hm.handle_update(state.pixels, push_policy, state.hal_state)
  end
end
