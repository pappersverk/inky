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

    for y <- 0..state.height,
        do: for(x <- 0..state.width, do: ^state = Inky.set_pixel(x, y, state.red))
  end
end
