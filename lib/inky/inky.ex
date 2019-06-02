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

    %State{display: display, pins: pins}
    |> do_reset()
    |> do_compute_packed_height()
    |> do_soft_reset()
    |> do_await_device()
  end

  def set_pixel(state = %State{}, x, y, value) when value in [:white, :black, :red, :yellow] do
    pixels = put_in(state.pixels, [{x, y}], value)
    %State{state | pixels: pixels}
  end

  def show(state = %State{}) do
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
    display = state.display

    aspect_ratio_changed =
      (display.rotation / 90)
      |> Kernel.trunc()
      |> Integer.is_odd()

    actual_height =
      if aspect_ratio_changed do
        display.width
      else
        display.height
      end

    # Little endian, unsigned short
    packed_height = [:binary.encode_unsigned(actual_height, :little), <<0x00>>]
    %State{state | packed_height: packed_height}
  end

  defp do_reset(state) do
    InkyIO.reset(state.pins)
    state
  end

  def do_soft_reset(state) do
    Commands.soft_reset(state.pins)
    state
  end

  def do_await_device(state) do
    Commands.await_device(state.pins)
    state
  end

  # MISC

  def log_grid(state = %State{}) do
    grid =
      Enum.reduce(0..(state.height - 1), "", fn y, grid ->
        row =
          Enum.reduce(0..(state.width - 1), "", fn x, row ->
            color_value = Map.get(state.pixels, {x, y}, 0)

            row <>
              case color_value do
                0 -> "W"
                1 -> "B"
                2 -> "R"
              end
          end)

        grid <> row <> "\n"
      end)

    IO.puts(grid)
    state
  end

  def try_get_state() do
    state = Inky.init(:phat, :red)

    Enum.reduce(0..(state.height - 1), state, fn y, state ->
      Enum.reduce(0..(state.width - 1), state, fn x, state ->
        Inky.set_pixel(state, x, y, state.red)
      end)
    end)
  end

  def try(state) do
    Inky.show(state)
  end
end
