defmodule Inky.InkyWhat do
  alias Inky.State
  @width 400
  @height 300

  @white 0
  @black 1
  @red 2
  @yellow 2

  @resolution_data [400, 300, 0]

  def update_state(state = %State{}) do
    %{
      state
      | type: :what,
        width: @width,
        height: @height,
        white: @white,
        black: @black,
        red: @red,
        yellow: @yellow,
        resolution_data: @resolution_data,
        columns: Enum.fetch!(@resolution_data, 0),
        rows: Enum.fetch!(@resolution_data, 1),
        rotation: Enum.fetch!(@resolution_data, 2)
    }
  end
end
