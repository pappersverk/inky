defmodule Inky.Displays.Display do
  alias Inky.Displays.LookupTables

  @enforce_keys [:type, :width, :height, :rotation, :accent, :luts]
  defstruct type: nil,
            width: 0,
            height: 0,
            rotation: 0,
            accent: :black,
            luts: <<>>

  def spec_for(type, accent \\ :black)

  def spec_for(:phat, accent) do
    %__MODULE__{
      type: :phat,
      width: 212,
      height: 104,
      rotation: -90,
      accent: accent,
      luts: LookupTables.get_luts(accent)
    }
  end

  def spec_for(:what, accent) do
    %__MODULE__{
      type: :what,
      width: 400,
      height: 300,
      rotation: 0,
      accent: accent,
      luts: LookupTables.get_luts(accent)
    }
  end
end
