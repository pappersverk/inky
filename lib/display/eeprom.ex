defmodule Inky.EEPROM do
  @moduledoc false

  @eep_address 0x50

  @display_variants {
    :unknown,
    "Red pHAT (High-Temp)",
    "Yellow wHAT",
    "Black wHAT",
    "Black pHAT",
    "Yellow pHAT",
    "Red wHAT",
    "Red wHAT (High-Temp)",
    "Red wHAT",
    :unknown,
    "Black pHAT (SSD1608)",
    "Red pHAT (SSD1608)",
    "Yellow pHAT (SSD1608)",
    :unknown,
    "7-Color (UC8159)"
  }

  @colors {:unknown, :black, :red, :yellow, :unknown, :seven_color}

  @fields [:width, :height, :color, :pcb_variant, :display_variant, :timestamp]

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{}

  @doc """
  Reads the device info from the EEPROM. This operation seems to work successfully only once.

  ## Examples

      iex> Inky.EEPROM.read()
      {:ok,
      %Inky.EEPROM{
        color: :red,
        display_variant: "Red pHAT (SSD1608)",
        height: 104,
        pcb_variant: 12,
        timestamp: "2021-03-30 08:58:28.9",
        width: 212
      }}

  """
  @spec read(atom()) :: {:ok, Inky.EEPROM.t()} | {:error, any()}
  def read(i2c_mod \\ Circuits.I2C) do
    with {:ok, ref} <- i2c_mod.open("i2c-1"),
         {:ok, data} <- i2c_mod.write_read(ref, @eep_address, <<0>>, 29) do
      i2c_mod.close(ref)
      parse_data(data)
    end
  end

  @doc """
  Parses data from Inky's EEPROM.
  """
  @spec parse_data(<<_::232>>) :: {:ok, t()} | {:error, {:invalid_data, any()}}
  def parse_data(
        <<width::little-16, height::little-16, color, pcb_variant, display_variant, _,
          timestamp::binary>>
      )
      when color in 0..5 and display_variant in 0..14 do
    {:ok,
     __struct__(
       width: width,
       height: height,
       color: elem(@colors, color),
       pcb_variant: pcb_variant,
       display_variant: elem(@display_variants, display_variant),
       timestamp: timestamp
     )}
  end

  def parse_data(data) do
    {:error, {:invalid_data, data}}
  end
end
