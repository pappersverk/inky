defmodule Inky.ImpressionButtons do
  @moduledoc """
  Adds support for the 4 buttons on the Inky Impressions

  The 4 buttons are monitored independently of the display and can be started in the
  supervison tree.

  Supply the `:handler` option as an atom, a pid, or `{module, function, args}` tuple
  specifying where to send events to. If no handler is supplied, events are simply logged.

  ```elixir
  Inky.ImpressionButtons.start_link(handler: self())
  ```

  You can also query the current value of a button at any time

  ```elixir
  Inky.ImpressionButtons.get_value(:a)
  ```
  """

  use GenServer

  alias Circuits.GPIO

  require Logger

  @typedoc """
  Button name for Inky Impression button

  These are labelled A, B, X, and Y on the board.
  """
  @type name() :: :a | :b | :x | :y

  defmodule Event do
    @moduledoc """
    Represents an event from the buttons
    """
    defstruct [:action, :name, :value, :timestamp]

    @type t :: %Event{
            action: :pressed | :released,
            name: Inky.ImpressionsButtons.name(),
            value: 1 | 0,
            timestamp: non_neg_integer()
          }
  end

  @pin_a 5
  @pin_b 6
  @pin_x 16
  @pin_y 24

  @doc """
  Start a GenServer to watch the buttons on the Inky Impression

  Options:

  * `:handler` - pass an atom a pid, or an MFA to receive button events
                 MFA stands for Module Function Args, here's an example MFA that would print out the events `{IO, :inspect, []}`
                 Note: the event will be prepended to the argument list
  """
  @spec start_link(keyword) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Return the current state of the button

  `0` - released
  `1` - pressed
  """
  @spec get_value(name()) :: 0 | 1
  def get_value(button) do
    GenServer.call(__MODULE__, {:get_value, button})
  end

  @impl GenServer
  def init(opts) do
    {:ok, %{button_to_ref: %{}, pin_to_button: %{}, handler: opts[:handler]}, {:continue, :init}}
  end

  @impl GenServer
  def handle_continue(:init, state) do
    {:ok, a} = GPIO.open(@pin_a, :input, pull_mode: :pullup)
    {:ok, b} = GPIO.open(@pin_b, :input, pull_mode: :pullup)
    {:ok, x} = GPIO.open(@pin_x, :input, pull_mode: :pullup)
    {:ok, y} = GPIO.open(@pin_y, :input, pull_mode: :pullup)
    :ok = GPIO.set_interrupts(a, :both)
    :ok = GPIO.set_interrupts(b, :both)
    :ok = GPIO.set_interrupts(x, :both)
    :ok = GPIO.set_interrupts(y, :both)

    button_to_ref = %{a: a, b: b, x: x, y: y}

    pin_to_button = %{
      @pin_a => :a,
      @pin_b => :b,
      @pin_x => :x,
      @pin_y => :y
    }

    {:noreply, %{state | button_to_ref: button_to_ref, pin_to_button: pin_to_button}}
  end

  @impl GenServer
  def handle_call({:get_value, name}, _from, state) do
    inverted_value = GPIO.read(state.button_to_ref[name])
    value = 1 - inverted_value

    {:reply, value, state}
  end

  @impl GenServer
  def handle_info({:circuits_gpio, pin, timestamp, inverted_value}, state) do
    value = 1 - inverted_value
    action = if value != 0, do: :pressed, else: :released

    event = %Event{
      action: action,
      name: state.pin_to_button[pin],
      value: value,
      timestamp: timestamp
    }

    _ = send_event(state.handler, event)

    {:noreply, state}
  end

  def handle_info(_other, state), do: {:noreply, state}

  defp send_event(handler, event) when is_atom(handler), do: send(handler, event)

  defp send_event(handler, event) when is_pid(handler), do: send(handler, event)

  defp send_event({m, f, a}, event) when is_atom(m) and is_atom(f) and is_list(a) do
    apply(m, f, [event | a])
  end

  defp send_event(_, event) do
    Logger.info("[Inky] unhandled button event - #{inspect(event)}")
  end
end
