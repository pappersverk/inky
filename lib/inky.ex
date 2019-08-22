defmodule Inky do
  @moduledoc """
  The Inky module provides the public API for interacting with the display.
  """

  use GenServer

  require Integer
  require Logger

  @typedoc "The Inky process name"
  @type name :: atom | {:global, term} | {:via, module, term}

  @default_border :black
  @push_timeout 5000

  defmodule State do
    @moduledoc false

    @enforce_keys [:display, :hal_state]
    defstruct border: :black,
              display: nil,
              hal_mod: Inky.RpiHAL,
              hal_state: nil,
              pixel_data: nil,
              # pixels: %{},
              type: nil,
              wait_type: :nowait

    def wait_type(wait_type, state), do: %State{state | wait_type: wait_type}
  end

  #
  # API
  #

  @doc """
  Helper function to start Inky from a supervisor spec
  """
  def start_link([type, accent, opts]), do: start_link(type, accent, opts)

  @doc """
  Start an Inky GenServer for a display of type `type`, with the color `accent`
  using the optionally provided options `opts`.

  The GenServer deals with the HAL state and pushing pixels to the physical
  display.

  ## Parameters

    - `type` - An atom, representing the display type, either `:phat` or `:what`
    - `accent` - An atom, representing the display's third color, one of
      `:black`, `:red` or `:yellow`.

  ## Options

    - `border` - Atom for the border color, defaults to `:black`
    - `name` - GenServer name option for naming the process

  See `GenServer.start_link/3` for return values.
  """
  def start_link(type, accent, opts \\ %{}) do
    genserver_opts = if(opts[:name], do: [name: opts[:name]], else: [])
    GenServer.start_link(__MODULE__, [type, accent, opts], genserver_opts)
  end

  @doc """
  `set_pixels` sets pixels and draws to the display (or not!), with new pixel
  data or a painter function.

  Returns:
  - `:ok` - If no push was requested or if it was and it worked, or
  - `{:error, :device_busy}` - If a push to the device was requested but could
    not be performed due to the device reporting a busy status.

  ## Parameters

  - `pid` - A pid or valid `name` option that can be provided to GenServer.
  - `arg` - A map of pixels or a painter function.
    - `pixels :: map()`, a map of pixels to merge into the current state. The map use the structure `%{{x, y}: color}` to indicate pixel coordinates and a color atom.
    - `painter :: (x, y, width, height, pixels)`, a function that will be
      invoked to pick a color for all points in the screen, in an undefined
      order. Should return a color atom.

  ## The color atoms

  - `:white`
  - `:black`
  - `:accent` - The third color for a display. Usually red och yellow.
  - `:red` - Equivalent to `:accent`.
  - `:yellow` - Equivalent to `:accent`.

  ## Options

  - `:border` - Atom for the border color.
  - `:push` - Represents the minimum pixel pushing policy the caller wishes to
     apply for their request. Valid values are listed and explained below.

      NOTE: the internal state of Inky will still be updated, regardless of
     which pushing policy is employed.

      - `:await` - Perform a blocking wait until the display is ready and you can push to it. Clears any
        previously set timeout. *This is the default.*
      - `:once` - Push to the display if it is not busy, otherwise, report that
        it was busy. `:await` timeouts are reset if a `:once` push has failed.
      - `{:timeout, :await}` - Use genserver timeouts to avoid multiple updates.
        When the timeout triggers, await device with a blocking wait and then push
        to the display. If the timeout previously was :once, it is replaced.
      - `{:timeout, :once}` - Use genserver timeouts to avoid multiple updates.
        When the timeout triggers, update the display if not busy. Does not
        downgrade a previously set `:await` timeout.
      - `:skip` - Do not push to display. If there has been a timeout previously
        set, but that has yet to fire, it will remain set.
  """
  @spec set_pixels(pid :: pid() | name(), arg :: map() | function(), opts :: map()) ::
          :ok | {:error, :device_busy}
  def set_pixels(pid, arg, opts \\ %{}),
    do: GenServer.call(pid, {:set_pixels, arg, opts}, :infinity)

  @doc """
  Shows the internally buffered pixels on the display.

  If `opts[:async]` is `true`, the call will be asynchronous.

  Returns `:ok`.
  """
  def show(server, opts \\ %{}) do
    if opts[:async] === true,
      do: GenServer.cast(server, :push),
      else: GenServer.call(server, :push, :infinity)
  end

  @doc """
  Stops `server`.

  Returns `:ok`.
  """
  def stop(server) do
    GenServer.stop(server)
  end

  #
  # GenServer callbacks
  #

  @impl GenServer
  def init([type, accent, opts]) do
    border = opts[:border] || @default_border
    hal_mod = opts[:hal_mod] || Inky.RpiHAL

    display = Inky.Display.spec_for(type, accent)
    pixel_data = Inky.PixelData.new(display.rotation)
    hal_state = hal_mod.init(%{display: display})

    {:ok,
     %State{
       border: border,
       display: display,
       hal_mod: hal_mod,
       hal_state: hal_state,
       pixel_data: pixel_data
     }}
  end

  # GenServer calls

  @impl GenServer
  def handle_call({:set_pixels, arg, opts}, _from, state = %State{wait_type: wt}) do
    state = do_set_pixels(arg, opts, state)

    case opts[:push] || :await do
      :await -> push(:await, state) |> reply(:nowait, state)
      :once -> push(:once, state) |> handle_push(state)
      :skip when wt == :nowait -> reply(:ok, :nowait, state)
      :skip -> reply_timeout(wt, state)
      {:timeout, :await} -> reply_timeout(:await, state)
      {:timeout, :once} when wt == :await -> reply_timeout(:await, state)
      {:timeout, :once} -> reply_timeout(:once, state)
    end
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

  defp do_set_pixels(arg, opts, state) do
    %State{
      state
      | pixel_data: Inky.PixelData.update(state.pixel_data, arg),
        border: pick_border(opts[:border], state)
    }
  end

  defp pick_border(nil, %State{border: b}), do: b
  defp pick_border(border, _state), do: border

  # GenServer replies

  defp handle_push(e = {:error, :device_busy}, state = %State{wait_type: :await}),
    do: reply_timeout(e, :await, state)

  defp handle_push(response, state), do: reply(response, :nowait, state)

  defp reply(response, timeout_policy, state),
    do: {:reply, response, State.wait_type(timeout_policy, state)}

  defp reply_timeout(response \\ :ok, timeout_policy, state),
    do: {:reply, response, State.wait_type(timeout_policy, state), @push_timeout}

  # Internals

  defp push(push_policy, state) when not (push_policy in [:await, :once]), do: push(:await, state)

  defp push(push_policy, state) do
    hm = state.hal_mod
    hm.handle_update(state.pixel_data, state.border, push_policy, state.hal_state)
  end
end
