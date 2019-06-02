defmodule Inky do
  @moduledoc """
  Documentation for Inky.
  """

  @doc """
  Hello world.

  ## Examples

      iex> alias Inky
      iex> state = Inky.setup(nil, :phat, :red)
      iex> state = Enum.reduce(0..(state.height - 1), state, fn y, state ->Enum.reduce(0..(state.width - 1), state, fn x, state ->Inky.set_pixel(state, x, y, state.red)end)end)
      iex> Inky.show(state)

  """

  use GenServer

  require Integer

  alias Inky.Commands
  alias Inky.Displays.Display
  alias Inky.InkyIO
  alias Inky.State

  # Used in logo example
  # inkyphat and inkywhat classes
  # color constants: RED, BLACK, WHITE
  # dimension constants: WIDTH, HEIGHT
  # PIL: putpixel(value)
  # set_image
  # show

  # SPI bus options include:
  # * `mode`: This specifies the clock polarity and phase to use. (0)
  # * `bits_per_word`: bits per word on the bus (8)
  # * `speed_hz`: bus speed (1000000)
  # * `delay_us`: delay between transaction (10)

  # API

  def init(type, accent)
      when type in [:phat, :what] and accent in [:black, :red, :yellow] do
    display = init_state_display(type, accent)
    pins = InkyIO.init_pins()

    state =
      %State{display: display, pins: pins}
      |> do_reset()
      |> do_compute_packed_height()
      |> do_soft_reset()
      |> do_await_device()

    {:ok, state}
  end

  # Handle a list of color atoms.
  def handle_call({:set_pixels, pixels}, state) when is_list(pixels) do
    new_pixels =
      Enum.reduce(pixels, {{0, 0}, state}, fn color, {{x, y}, state} ->
        # Ignore unknown colors, ignore drawing outside the size of the screen
        {_, state} =
          if color in [:white, :black, state.display.accent] and x < state.display.width and
               y < state.display.height do
            set_pixel(state, x, y, color)
          end

        x =
          cond do
            x >= state.display.width -> 0
            true -> x + 1
          end

        # It is fine if the silly caller wants to overflow the drawable area
        y = y + 1

        {{x, y}, state}
      end)

    state = %{state | pixels: new_pixels}
    show(state)
    {:noreply, state}
  end

  # Handle a map of coordinate tuples (matches internal representation)
  def handle_call({:set_pixels, pixels}, state) when is_map(pixels) do
    state = %{state | pixels: pixels}
    show(state)
    {:noreply, state}
  end

  defp set_pixel(state = %State{}, x, y, value) when value in [:white, :black, :red, :yellow] do
    pixels = put_in(state.pixels, [{x, y}], value)
    %State{state | pixels: pixels}
  end

  defp show(state = %State{}) do
    # Not implemented: vertical flip
    # Not implemented: horizontal flip

    # Note: Rotation handled when converting to bitstring
    pixels = state.pixels
    display = state.display
    accent = display.accent
    pins = state.pins

    # TODO: (???) consider replacing :black with :on
    black_bytes =
      Commands.pixels_to_bitstring(pixels, display, fn
        :black -> 0
        _ -> 1
      end)

    accent_bytes =
      Commands.pixels_to_bitstring(pixels, display, fn
        ^accent -> 1
        _ -> 0
      end)

    Commands.update(pins, display, state.packed_height, black_bytes, accent_bytes)
  end

  # init helpers

  defp init_state_display(type, accent) do
    Display.spec_for(type, accent)
  end

  defp do_compute_packed_height(state) do
    rows = get_rows(state.display)
    # Little endian, unsigned short
    packed_height = [:binary.encode_unsigned(rows, :little), <<0x00>>]
    %State{state | packed_height: packed_height}
  end

  defp get_rows(display) do
    case display.type do
      :phat -> display.width
      :what -> display.height
    end
  end

  defp do_reset(state) do
    InkyIO.reset(state.pins)
    state
  end

  defp do_soft_reset(state) do
    Commands.soft_reset(state.pins)
    state
  end

  defp do_await_device(state) do
    Commands.await_device(state.pins)
    state
  end
end
