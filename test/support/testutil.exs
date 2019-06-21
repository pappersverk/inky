defmodule Inky.TestUtil do
  @moduledoc false

  def gather_messages(acc \\ []) do
    receive do
      msg -> gather_messages([msg | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  def pos2col(_i, j) do
    r = rem(j, 3)

    cond do
      r == 0 -> :white
      r == 1 -> :black
      r == 2 -> :red
    end
  end
end
