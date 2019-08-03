defmodule Inky.PixelData do
  @moduledoc """
  A struct for representing combinations of painters and accumulated pixel updates.
  """
  defstruct overlay: nil,
            painter: nil,
            rotation: 0

  def new(rotation), do: %__MODULE__{rotation: normalised_rotation(rotation)}

  def update(data, painter) when is_function(painter, 4),
    do: %__MODULE__{data | painter: painter, overlay: nil}

  def update(data, pixels) when is_map(pixels) do
    %__MODULE__{data | overlay: Map.merge(data.overlay || %{}, pixels)}
  end

  @doc """
  Only exposed for testing purposes. Do not use.

      iex> Enum.map(
      ...>     [-360, -270, -180, -90, 0, 90, 180, 270, 360, 450],
      ...>     &Inky.PixelData.normalised_rotation/1
      ...> )
      [0, 1, 2, 3, 0, 1, 2, 3, 0, 1]
  """
  def normalised_rotation(degrees) do
    r = degrees |> div(90) |> rem(4)
    if(r < 0, do: r + 4, else: r)
  end
end
