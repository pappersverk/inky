defmodule InkyZeroNervesTest do
  use ExUnit.Case
  alias Inky.State
  alias Inky.InkyPhat
  doctest InkyZeroNerves

  test "inky phat update state" do
    state = %State{}
    state = InkyPhat.update_state(state)

    assert state.width == 212
    assert state.height == 104
    assert state.white == 0
    assert state.black == 1
    assert state.red == 2
    assert state.yellow == 2
    assert state.columns == Enum.at(state.resolution_data, 0)
    assert state.rows == Enum.at(state.resolution_data, 1)
    assert state.rotation == Enum.at(state.resolution_data, 2)
  end

  test "pixels to bytestring" do
    state = InkyPhat.update_state(%State{})

    state =
      Enum.reduce(0..(state.height - 1), state, fn y, state ->
        Enum.reduce(0..(state.width - 1), state, fn x, state ->
          Inky.set_pixel(state, x, y, state.red)
        end)
      end)

    assert map_size(state.pixels) == state.width * state.height
    # IO.puts("state:")
    # IO.inspect(state)

    bytestring = Inky.pixels_to_bytestring(state, state.red)
    assert byte_size(bytestring) == state.width * state.height / 8
  end
end
