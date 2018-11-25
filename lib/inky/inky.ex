defmodule Inky do
  @moduledoc """
  Documentation for Inky.
  """

  @doc """
  Hello world.

  ## Examples

      iex> Inky.hello()
      :world

  """

  alias ElixirALE.SPI
  alias ElixirALE.GPIO
  alias Inky.InkyPhat
  alias Inky.InkyWhat
  alias Inky.State
  # alias Inky.Pixel

  @reset_pin 27
  @busy_pin 17
  @dc_pin 22

  # @mosi_pin 10
  # @sclk_pin 11
  @cs0_pin 0

  # @spi_chunk_size 4096
  @spi_command 0
  @spi_data 1

  # Used in logo example
  # inkyphat and inkywhat classes
  # color constants: RED, BLACK, WHITE
  # dimension constants: WIDTH, HEIGHT
  # PIL: putpixel(value)
  # set_image
  # show

  # SPI bus options include:
  # * `mode`: This specifies the clock polarity and phase to use. (0)
  # * `bits_per_word`: bits per word on the bus (8)
  # * `speed_hz`: bus speed (1000000)
  # * `delay_us`: delay between transaction (10)

  def setup(state \\ nil, type) when type in [:phat, :what] do
    state =
      case state do
        %State{} ->
          state

        nil ->
          {:ok, dc_pid} = GPIO.start_link(@dc_pin, :output, start_value: 0)
          {:ok, reset_pid} = GPIO.start_link(@reset_pin, :output, start_value: 1)
          {:ok, busy_pid} = GPIO.start_link(@busy_pin, :input)
          # GPIO.write(gpio_pid, 1)
          {:ok, spi_pid} = SPI.start_link("spidev0." <> to_string(@cs0_pin), speed_hz: 488_000)
          # Use binary pattern matching to pull out the ADC counts (low 10 bits)
          # <<_::size(6), counts::size(10)>> = SPI.transfer(spi_pid, <<0x78, 0x00>>)
          %State{
            dc_pid: dc_pid,
            reset_pid: reset_pid,
            busy_pid: busy_pid,
            spi_pid: spi_pid,
            color: :black
          }
      end

    GPIO.write(state.reset_pid, 0)
    :timer.sleep(100)
    GPIO.write(state.reset_pid, 1)
    :timer.sleep(100)

    state =
      case type do
        :phat -> InkyPhat.update_state(state)
        :what -> InkyWhat.update_state(state)
      end

    soft_reset(state)
    state
  end

  def set_pixel(state = %State{}, x, y, value) do
    state =
      if value in [state.white, state.black, state.red, state.yellow] do
        put_in(state.pixels[{x, y}], value)
        # %{state | pixels: %{state.pixels | {x, y}: value} }
      else
        state
      end

    state
  end

  def show(state = %State{}) do
    # Not implemented: vertical flip
    # Not implemented: horizontal flip
    # Not implemented: rotation

    black_bytes = pixels_to_bytestring(state, state.black)
    red_bytes = pixels_to_bytestring(state, state.red)
    update(state, black_bytes, red_bytes)
  end

  # Private functionality

  defp busy_wait(state) do
    busy = GPIO.read(state.busy_pid)

    case busy do
      0 ->
        state

      false ->
        state

      1 ->
        :timer.sleep(10)
        busy_wait(state)

      true ->
        :timer.sleep(10)
        busy_wait(state)
    end
  end

  defp update(state, buffer_a, buffer_b) do
    setup(state, state.type)

    ## Straight ported from python library, I know very little what I'm doing here

    # little endian, unsigned short
    packed_height = [:binary.encode_unsigned(Enum.fetch!(state.resolution_data, 1), :little)]

    # Skipped map ord thing for packed_height..
    IO.puts("Starting to send shit..")

    # Set analog block control
    send_command(state, 0x74, 0x54)
    # Set digital block control
    send_command(state, 0x7E, 0x3B)

    # Gate setting
    send_command(state, 0x01, :binary.list_to_bin(packed_height ++ [0x00]))

    # Gate driving voltage
    send_command(state, 0x03, [0b10000, 0b0001])

    # Dummy line period
    send_command(state, 0x3A, 0x07)
    # Gate line width
    send_command(state, 0x3B, 0x04)
    # Data entry mode setting 0x03 = X/Y increment
    send_command(state, 0x11, 0x03)

    # Power on
    send_command(state, 0x04)
    # VCOM Register, 0x3c = -1.5v?
    send_command(state, 0x2C, 0x3C)

    send_command(state, 0x3C, 0x00)

    # Always black border
    send_command(state, 0x3C, 0x00)

    # Set LUTs
    send_command(state, 0x32, get_luts(:red))

    # Set RAM X Start/End
    send_command(state, 0x44, :binary.list_to_bin([0x00, trunc(state.columns / 8) - 1]))
    # Set RAM Y Start/End
    send_command(state, 0x45, :binary.list_to_bin([0x00, 0x00] ++ packed_height))

    # 0x24 == RAM B/W, 0x26 == RAM Red/Yellow/etc
    for data <- [{0x24, buffer_a}, {0x26, buffer_b}] do
      {cmd, buffer} = data

      # Set RAM X Pointer start
      send_command(state, 0x4E, 0x00)
      # Set RAM Y Pointer start
      send_command(state, 0x4F, <<0x00, 0x00>>)
      send_command(state, cmd, buffer)
    end

    # Display Update Sequence
    send_command(state, 0x22, 0xC7)
    # Trigger Display Update
    send_command(state, 0x20)

    :timer.sleep(50)
    busy_wait(state)
    send_command(state, 0x10, 0x01)
  end

  def pixels_to_bytestring(state = %State{}, color_value) do
    for i <-
          Enum.flat_map(0..(state.height - 1), fn y ->
            Enum.map(0..(state.width - 1), fn x ->
              case state.pixels[{x, y}] do
                ^color_value -> 1
                _ -> 0
              end
            end)
          end),
        do: <<i::1>>,
        into: <<>>
  end

  defp soft_reset(state = %State{}) do
    send_command(state, 0x12)
  end

  defp send_command(state = %State{}, command) when is_binary(command) do
    IO.inspect("send_command/2 binary")
    spi_write(state, @spi_command, command)
  end

  defp send_command(state = %State{}, command) do
    IO.inspect("send_command/2")
    spi_write(state, @spi_command, <<command>>)
  end

  defp send_command(state = %State{}, command, data) do
    IO.inspect("send_command/3")
    send_command(state, <<command>>)
    send_data(state, data)
  end

  defp send_data(state = %State{}, data) when is_integer(data) do
    IO.inspect("send_data/2 int")
    spi_write(state, @spi_data, <<data>>)
  end

  defp send_data(state = %State{}, data) do
    IO.inspect("send_command/2")
    spi_write(state, @spi_data, data)
  end

  defp spi_write(state = %State{}, data_or_command, values) do
    IO.inspect("spi_write/3")
    GPIO.write(state.dc_pid, data_or_command)
    SPI.transfer(state.spi_pid, values)
    state
  end

  def try_get_state() do
    state = Inky.setup(nil, :phat)

    Enum.reduce(0..(state.height - 1), state, fn y, state ->
      Enum.reduce(0..(state.width - 1), state, fn x, state ->
        Inky.set_pixel(state, x, y, state.red)
      end)
    end)
  end

  def try(state) do
    Inky.show(state)
  end

  defp get_luts(:black) do
    <<
      # Phase 0     Phase 1     Phase 2     Phase 3     Phase 4     Phase 5     Phase 6
      # A B C D     A B C D     A B C D     A B C D     A B C D     A B C D     A B C D
      # LUT0 - Black
      0b01001000,
      0b10100000,
      0b00010000,
      0b00010000,
      0b00010011,
      0b00000000,
      0b00000000,
      # LUTT1 - White
      0b01001000,
      0b10100000,
      0b10000000,
      0b00000000,
      0b00000011,
      0b00000000,
      0b00000000,
      # IGNORE
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      # LUT3 - Red
      0b01001000,
      0b10100101,
      0b00000000,
      0b10111011,
      0b00000000,
      0b00000000,
      0b00000000,
      # LUT4 - VCOM
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,

      # Duration            |  Repeat
      # A   B     C     D   |
      # 0 Flash
      16,
      4,
      4,
      4,
      4,
      # 1 clear
      16,
      4,
      4,
      4,
      4,
      # 2 bring in the black
      4,
      8,
      8,
      16,
      16,
      # 3 time for red
      0,
      0,
      0,
      0,
      0,
      # 4 final black sharpen phase
      0,
      0,
      0,
      0,
      0,
      # 5
      0,
      0,
      0,
      0,
      0,
      # 6
      0,
      0,
      0,
      0,
      0
    >>
  end

  defp get_luts(:red) do
    <<
      # Phase 0     Phase 1     Phase 2     Phase 3     Phase 4     Phase 5     Phase 6
      # A B C D     A B C D     A B C D     A B C D     A B C D     A B C D     A B C D
      # LUT0 - Black
      0b01001000,
      0b10100000,
      0b00010000,
      0b00010000,
      0b00010011,
      0b00000000,
      0b00000000,
      # LUTT1 - White
      0b01001000,
      0b10100000,
      0b10000000,
      0b00000000,
      0b00000011,
      0b00000000,
      0b00000000,
      # IGNORE
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      # LUT3 - Red
      0b01001000,
      0b10100101,
      0b00000000,
      0b10111011,
      0b00000000,
      0b00000000,
      0b00000000,
      # LUT4 - VCOM
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,

      # Duration            |  Repeat
      # A   B     C     D   |
      # 0 Flash
      64,
      12,
      32,
      12,
      6,
      # 1 clear
      16,
      8,
      4,
      4,
      6,
      # 2 bring in the black
      4,
      8,
      8,
      16,
      16,
      # 3 time for red
      2,
      2,
      2,
      64,
      32,
      # 4 final black sharpen phase
      2,
      2,
      2,
      2,
      2,
      # 5
      0,
      0,
      0,
      0,
      0
    >>
  end

  defp get_luts(:yellow) do
    <<
      # Phase 0     Phase 1     Phase 2     Phase 3     Phase 4     Phase 5     Phase 6
      # A B C D     A B C D     A B C D     A B C D     A B C D     A B C D     A B C D
      # LUT0 - Black
      0b11111010,
      0b10010100,
      0b10001100,
      0b11000000,
      0b11010000,
      0b00000000,
      0b00000000,
      # LUTT1 - White
      0b11111010,
      0b10010100,
      0b00101100,
      0b10000000,
      0b11100000,
      0b00000000,
      0b00000000,
      # IGNORE
      0b11111010,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      0b00000000,
      # LUT3 - Yellow (or Red)
      0b11111010,
      0b10010100,
      0b11111000,
      0b10000000,
      0b01010000,
      0b00000000,
      0b11001100,
      # LUT4 - VCOM
      0b10111111,
      0b01011000,
      0b11111100,
      0b10000000,
      0b11010000,
      0b00000000,
      0b00010001,

      # Duration            | Repeat
      # A   B     C     D   |
      64,
      16,
      64,
      16,
      8,
      8,
      16,
      4,
      4,
      16,
      8,
      8,
      3,
      8,
      32,
      8,
      4,
      0,
      0,
      16,
      16,
      8,
      8,
      0,
      32,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0,
      0
    >>
  end
end
