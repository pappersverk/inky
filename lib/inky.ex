defmodule Inky do
  @moduledoc """
  The Inky module provides the public API for interacting with the display.
  """

  use GenServer

  defmodule State do
    @moduledoc false
    @enforce_keys [:display, :hal_state]
    defstruct type: nil,
              hal_state: nil,
              display: nil,
              wait_type: :nowait,
              pixels: %{}
  end

  require Integer
  require Logger

  alias Inky.Commands
  alias Inky.Displays.Display
  alias Inky.PixelUtil

  @push_timeout 5000

  @color_map_black %{black: 0, miss: 1}
  @color_map_accent %{red: 1, yellow: 1, accent: 1, miss: 0}

  #
  # API
  #

  @doc """
  Start a GenServer that deals with the HAL state (initialization of and communication with the display) and pushing pixels to the physical display. This function will do some of the necessary preparation to prepare communication with the display.

  ## Parameters

    - type: Atom for either :phat or :what
    - accent: Accent color, the color the display supports aside form white and black. Atom, :black, :red or :yellow.
  """
  def start_link(args \\ %{}) do
    opts = if(args[:name], do: [name: args[:name]], else: [])
    GenServer.start_link(__MODULE__, args, opts)
  end

  @doc """
  `set_pixels(pid | name, pixels | painter, opts \\ %{push: :await})` set pixels and draw to display (or not!), with data or a painter function.

  set_pixels updates the internal state either with specific pixels or by calling `painter.(x,y)` for all points in the screen, in an undefined order. Currently, `set_pixels` only accepts a `:push` option with one of the following values, but whichever you use, the internal state will be updated.

  Valid `:push` values are:

  - `:await`: Busy wait until you can push to display. This is the default.
  - `:once`: Push to the display if it is not busy, otherwise, report that it was busy. If there has been a timeout previously set, but that has yet to fire, it will be set again.
  - `{:timeout, :await}`: Use genserver timeouts to avoid multiple updates. When the timeout triggers, await device with a busy wait and then push to the display.
  - `{:timeout, :once}`: Use genserver timeouts to avoid multiple updates. When the timeout triggers, update the display if not busy.
  - `:skip`: Do not push to display. If there has been a timeout previously set, but that has yet to fire, it will be set again.
  """
  def set_pixels(pid, arg, opts \\ %{push: :await}),
    do: GenServer.call(pid, {:set_pixels, arg, opts}, :infinity)

  # TODO: rename to push?
  def show(server, opts \\ %{}) do
    if opts[:async] === true,
      do: GenServer.cast(server, :push),
      else: GenServer.call(server, :push, :infinity)
  end

  #
  # GenServer callbacks
  #

  @impl GenServer
  def init(args) do
    type = args[:type]
    accent = args[:accent]

    display = Display.spec_for(type, accent)
    hal_state = Commands.init_io()

    {:ok, %State{display: display, hal_state: hal_state}}
  end

  # GenServer calls

  @impl GenServer
  def handle_call({:set_pixels, arg, opts}, _from, state) do
    state = %State{state | pixels: update_pixels(arg, state)}
    dispatch_push(opts[:push], state)
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
    push(state, :await)
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
    display = %Display{width: w, height: h, rotation: r} = state.display

    black_bits = PixelUtil.pixels_to_bits(state.pixels, w, h, r, @color_map_black)
    accent_bits = PixelUtil.pixels_to_bits(state.pixels, w, h, r, @color_map_accent)

    Commands.update(state.hal_state, display, black_bits, accent_bits, push_policy)
  end
end
