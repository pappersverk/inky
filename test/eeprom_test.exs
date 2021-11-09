defmodule Inky.EEPROMTest do
  @moduledoc false

  use ExUnit.Case
  import Inky.EEPROM

  describe "parse_data/1" do
    test "returns correct struct for Inky pHAT SSD1608" do
      inky_ssd1608_eeprom =
        <<212, 0, 104, 0, 1, 12, 10, 21, 50, 48, 50, 49, 45, 48, 55, 45, 49, 50, 32, 49, 48, 58,
          49, 49, 58, 52, 57, 46, 56>>

      assert {:ok,
              %Inky.EEPROM{
                color: :black,
                display_variant: "Black pHAT (SSD1608)",
                height: 104,
                pcb_variant: 12,
                timestamp: "2021-07-12 10:11:49.8",
                width: 212
              }} = parse_data(inky_ssd1608_eeprom)
    end

    test "returns correct struct for Inky Impression" do
      inky_impression_eeprom =
        <<88, 2, 192, 1, 0, 12, 14, 21, 50, 48, 50, 49, 45, 48, 56, 45, 50, 53, 32, 49, 55, 58,
          49, 50, 58, 49, 48, 46, 51>>

      assert {:ok,
              %Inky.EEPROM{
                color: :unknown,
                display_variant: "7-Color (UC8159)",
                height: 448,
                pcb_variant: 12,
                timestamp: "2021-08-25 17:12:10.3",
                width: 600
              }} = parse_data(inky_impression_eeprom)
    end
  end
end
