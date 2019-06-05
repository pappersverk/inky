defmodule Inky do
  @moduledoc """
  Documentation for Inky.
  """

  defmodule State do
    @enforce_keys [:display, :hal_state]
    defstruct type: nil,
              hal_state: nil,
              display: nil,
              pixels: %{}
  end

  require Integer

  alias Inky.Commands
  alias Inky.Displays.Display
  alias Inky.PixelUtil

  # API

  def init(type, accent)
      when type in [:phat, :what] and accent in [:black, :red, :yellow] do
    display = Display.spec_for(type, accent)
    hal_state = Commands.init_io()

    %State{display: display, hal_state: hal_state}
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
    pins = state.pins

    black_bytes = PixelUtil.pixels_to_bitstring(pixels, display, :black)
    accent_bytes = PixelUtil.pixels_to_bitstring(pixels, display, :accent)

    Commands.update(pins, display, black_bytes, accent_bytes)
    %{state | requires_reset: true}
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
