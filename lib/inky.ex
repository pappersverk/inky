defmodule Inky do
  @moduledoc """
  Documentation for Inky.
  """

  defmodule State do
    @moduledoc false

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

    # TODO: make a single function to do these things(?) and return {:ok, {buf_black, buf_accent}}
    black_bytes = PixelUtil.pixels_to_bitstring(pixels, display, :black)
    accent_bytes = PixelUtil.pixels_to_bitstring(pixels, display, :accent)

    Commands.update(state.hal_state, display, black_bytes, accent_bytes)
    state
  end
end
