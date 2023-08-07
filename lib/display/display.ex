defmodule Inky.Display do
  @moduledoc """
  Display creates specifications for displays and accent colors
  """

  alias Inky.LookupTables

  @type t() :: %__MODULE__{}

  @enforce_keys [:type, :width, :height, :packed_dimensions, :rotation, :accent, :luts]
  defstruct type: nil,
            width: 0,
            height: 0,
            packed_dimensions: %{},
            packed_resolution: nil,
            rotation: 0,
            accent: :black,
            luts: <<>>

  @spec spec_for(:impression_7_3, :none) :: Inky.Display.t()
  def spec_for(type = :impression_7_3, :none) do
    width = 800
    height = 480

    %__MODULE__{
      type: type,
      width: width,
      height: height,
      packed_dimensions: %{},
      packed_resolution:
        <<width::unsigned-big-integer-size(16)>> <> <<height::unsigned-big-integer-size(16)>>,
      rotation: 0,
      accent: nil,
      luts: <<>>
    }
  end

  @spec spec_for(:impression_5_7, :none) :: Inky.Display.t()
  def spec_for(type = :impression_5_7, :none) do
    width = 600
    height = 448

    %__MODULE__{
      type: type,
      width: width,
      height: height,
      packed_dimensions: %{},
      packed_resolution:
        <<width::unsigned-big-integer-size(16)>> <> <<height::unsigned-big-integer-size(16)>>,
      rotation: 0,
      accent: nil,
      luts: <<>>
    }
  end

  # WARNING: This is untested on actual hardware
  @spec spec_for(:impression_4, :none) :: Inky.Display.t()
  def spec_for(type = :impression_4, :none) do
    width = 640
    height = 400

    %__MODULE__{
      type: type,
      width: width,
      height: height,
      packed_dimensions: %{},
      packed_resolution:
        <<width::unsigned-big-integer-size(16)>> <> <<height::unsigned-big-integer-size(16)>>,
      rotation: 0,
      accent: nil,
      luts: <<>>
    }
  end

  @spec spec_for(:phat_original | :phat_ssd1608 | :what, :black | :red | :yellow) ::
          Inky.Display.t()
  def spec_for(type = :phat_ssd1608, accent) do
    # Keep it minimal. Details are specified in `Inky.HAL.PhatSSD1608`.
    %__MODULE__{
      type: type,
      width: 250,
      height: 122,
      packed_dimensions: %{},
      rotation: -90,
      accent: accent,
      luts: <<>>
    }
  end

  def spec_for(type = :phat_original, accent) do
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

  def spec_for(type = :test_small, accent) do
    %__MODULE__{
      type: type,
      width: 3,
      height: 4,
      packed_dimensions: packed_dimensions(type, 3, 4),
      rotation: 270,
      accent: accent,
      luts: "luts"
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
        :phat_original -> height
        :test_small -> height
      end

    <<trunc(columns / 8) - 1>>
  end

  defp packed_height(type, width, height) do
    rows =
      case type do
        :what -> height
        :phat_original -> width
        :test_small -> width
      end

    # Little endian, unsigned short
    <<rows::unsigned-little-integer-16>>
  end
end
