defmodule Inky do
  @moduledoc """
  The Inky module provides the public API for interacting with the display.
  """

  defmodule State do
    @moduledoc """
    The State struct is used throughout the inky library to provide a structure
    for the different pieces of data required to run the display.
    """

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

  @doc """
  Initializes a display of the given configuration. This function will do some
  of the necessary preparation to prepare communication with the display.

  ## Parameters

    - type: Atom for either :phat or :what
    - accent: Accent color, the color the display supports aside form white and black. Atom, :black, :red or :yellow.
  """
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

    black_bytes = PixelUtil.pixels_to_bitstring(pixels, display, :black)
    accent_bytes = PixelUtil.pixels_to_bitstring(pixels, display, :accent)

    Commands.update(state.hal_state, display, black_bytes, accent_bytes)
    state
  end
end
