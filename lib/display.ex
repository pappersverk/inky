defmodule Inky.Displays.Display do
  @moduledoc """
  Display creates specifications for displays and accent colors
  """

  alias Inky.Displays.LookupTables

  @enforce_keys [:type, :width, :height, :packed_dimensions, :rotation, :accent, :luts]
  defstruct type: nil,
            width: 0,
            height: 0,
            packed_dimensions: %{},
            rotation: 0,
            accent: :black,
            luts: <<>>

  @spec spec_for(:phat | :what, :black | :red | :yellow) :: Inky.Displays.Display.t()
  def spec_for(type, accent \\ :black)

  def spec_for(type = :phat, accent) do
    %__MODULE__{
      type: type,
      width: 212,
      height: 104,
      packed_dimensions: packed_dimensions(type, 212, 104),
      rotation: -90,
      accent: accent,
      luts: LookupTables.get_luts(accent)
    }
  end

  def spec_for(type = :what, accent) do
    %__MODULE__{
      type: type,
      width: 400,
      height: 300,
      packed_dimensions: packed_dimensions(type, 400, 300),
      rotation: 0,
      accent: accent,
      luts: LookupTables.get_luts(accent)
    }
  end

  defp packed_dimensions(type, width, height),
    do: %{
      width: packed_width(type, width, height),
      height: packed_height(type, width, height)
    }

  defp packed_width(type, width, height) do
    columns =
      case type do
        :what -> width
        :phat -> height
      end

    <<trunc(columns / 8) - 1>>
  end

  defp packed_height(type, width, height) do
    rows =
      case type do
        :what -> height
        :phat -> width
      end

    # Little endian, unsigned short
    <<rows::unsigned-little-integer-16>>
  end
end
