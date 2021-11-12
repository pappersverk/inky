defmodule Inky.Impression.RpiHAL do
  @default_io_mod Inky.Impression.RpiIO

  @moduledoc """
  An `Inky.HAL` implementation responsible for sending commands to the Inky
  screen. It delegates to whatever IO module its user provides at init, but
  defaults to #{inspect(@default_io_mod)}
  """

  @behaviour Inky.HAL

  @colors %{
    :black => 0,
    :white => 1,
    :green => 2,
    :blue => 3,
    :red => 4,
    :yellow => 5,
    :orange => 6,
    # Not a color, but is used to clear the display
    :clean => 7
  }

  @psr 0x00
  @pwr 0x01
  @pof 0x02
  @pfs 0x03
  @pon 0x04
  @btst 0x06
  @dslp 0x07
  @dtm1 0x10
  @dsp 0x11
  @drf 0x12
  @ipc 0x13
  @pll 0x30
  @tsc 0x40
  @tse 0x41
  @tws 0x42
  @tsr 0x43
  @cdi 0x50
  @lpd 0x51
  @tcon 0x60
  @tres 0x61
  @dam 0x65
  @rev 0x70
  @flg 0x71
  @amv 0x80
  @vv 0x81
  @vdcs 0x82
  @pws 0xE3
  @tsset 0xE5

  require Logger

  alias Inky.Display
  alias Inky.HAL
  alias Inky.PixelUtil

  defmodule State do
    @moduledoc false

    @state_fields [:display, :io_mod, :io_state, :setup?]

    @enforce_keys @state_fields
    defstruct @state_fields
  end

  #
  # API
  #

  @impl HAL
  def init(args) do
    display = args[:display] || raise(ArgumentError, message: ":display missing in args")
    io_mod = args[:io_mod] || @default_io_mod

    io_args = args[:io_args] || []
    io_args = if :gpio_mod in io_args, do: io_args, else: [gpio_mod: Circuits.GPIO] ++ io_args
    io_args = if :spi_mod in io_args, do: io_args, else: [spi_mod: Circuits.SPI] ++ io_args

    %State{
      display: display,
      io_mod: io_mod,
      io_state: io_mod.init(io_args),
      setup?: false
    }
  end

  @impl HAL
  def handle_update(pixels, border, push_policy, state = %State{}) do
    display = %Display{width: w, height: h, rotation: r} = state.display
    Logger.info("display: #{inspect(display)}")
    IO.puts("Generating buffer2...")

    # I think this buffer is being generated incorrectly
    # The resolution isn't right
    # Also only the black is actually solid, it's like black is being interspersed with the other colors
    # In the python library this is a uint8 which is an unsigned 8-bit integer,
    # which should be similar to a byte in elixir...
    # buffer = gen_buf()
    buffer =
      for y <- 0..(h - 1), x <- 0..(w - 1), into: <<>> do
        cond do
          #x > 150 && y > 200 -> <<@colors[:orange]>>
          # x > 160 -> <<@colors[:black]>>
          x > 160 -> <<@colors[:blue]::4, @colors[:blue]::4>>
          # y > 115 -> <<@colors[:green]>>
          true -> <<@colors[:white]::4, @colors[:white]::4>>
          # true -> <<rem(y + 1, @colors[:orange] + 1)>>
        end
        # color = floor(0 / w * 7)

        # <<@colors[:yellow]>>
        # <<7::4,7::4>>
      end

    # log("Generated buffer of size: #{byte_size(buffer)}")

    log("Resetting device")
    reset(state)

    case pre_update(state, push_policy) do
      :cont -> do_update(state, display, border, buffer)
      :halt -> {:error, :device_busy}
    end
  end

  def gen_buf do
    IO.puts("Start generating buffer")
    w = 600
    h = 448

    buffer =
      for y <- 0..(h - 1), x <- 0..(w - 1), into: <<>> do
        cond do
          #x > 150 && y > 200 -> <<@colors[:orange]>>
          # x > 160 -> <<@colors[:black]>>
          # y > 115 -> <<@colors[:green]>>
          x > 300 -> <<@colors[:black]>>
          y > 224 -> <<@colors[:green]>>
          true -> <<rem(y, @colors[:orange] + 1)>>
        end
        # color = floor(0 / w * 7)
      end

    log("Generated buffer of size: #{byte_size(buffer)}")
    log("buffer: #{inspect(buffer)}")

    buffer = prep_buffer(buffer)

    log("Generated buffer of size: #{byte_size(buffer)}")
    log("buffer: #{inspect(buffer)}")
    buf_list = :binary.bin_to_list(buffer)
    |> Enum.chunk_every(448)
    |> IO.inspect(label: "buf_list (rpihal.ex:150)")
    # IO.inspect(buffer, label: "buffer (rpihal.ex:149)", limit: :infinity)
    buf_list
  end

  defp prep_buffer(buffer) do
    import Bitwise

    buf_list = :binary.bin_to_list(buffer)

    # Python
    # buf = ((buf[::2] << 4) & 0xF0) | (buf[1::2] & 0x0F)
    # Takes every second byte of `buf`, multiplies it by 2^4 (16) and bytewise ands it with 0xF0
    # 2 << 4 is equivalent to Bitwise.<<<(2, 4)
    # 17 & 0xF0 is equivalent to Bitwise.&&&(17, 0xF0)
    # 16 | 0xF is equivalent to Bitwise.|||(16, 0xF)
    # buf[::2] takes every second byte (starting at index 0)
    # buf[1::2] takes every second byte (starting at index 1)

    # buf[::2] and buf[1::2]
    IO.puts("before split")
    {buf_a, buf_b} = split_buf_list(buf_list)
    IO.puts("after split")
    IO.inspect(buf_a, label: "buf_a (rpihal.ex:168)")
    IO.inspect(buf_b, label: "buf_b (rpihal.ex:169)")

    # (buf[::2] << 4) & 0xF0
    # high_bytes = (buf_a <<< 4) &&& 0xF0

    high_bytes = for <<byte <- buf_a>>, into: <<>> do
      <<(byte <<< 4) &&& 0xF0>>
    end
    IO.inspect(high_bytes, label: "high_bytes (rpihal.ex:180)")

    # (buf[1::2] & 0x0F)
    low_bytes = for <<byte <- buf_b>>, into: <<>> do
      <<byte && 0x0F>>
    end
    IO.inspect(low_bytes, label: "low_bytes (rpihal.ex:186)")


    # buf = ((buf[::2] << 4) & 0xF0) | (buf[1::2] & 0x0F)
    binary_bitwise_or(high_bytes, low_bytes)
    |> :binary.list_to_bin()

    # ((buf[::2] << 4) & 0xF0) | (buf[1::2] & 0x0F)
    # (|
    #   (& )
    #   (buf[::2] << 4) & 0xF0)
    #   (buf[1::2] & 0x0F)

    # buf = ((buf[::2] << 4) & 0xF0) | (buf[1::2] & 0x0F)
  end

  def bitwise_map(bin, op) when is_binary(bin) do
    IO.inspect(bin, label: "bin (rpihal.ex:201)")
    IO.inspect(op, label: "op (rpihal.ex:202)")
    for <<byte <- bin>>, into: <<>> do
      <<op.(byte)>>
    end
  end

  def binary_bitwise_or(<<>>, <<>>), do: []
  def binary_bitwise_or(<<a, rest_a::binary>>, <<b, rest_b::binary>>) do
    import Bitwise
    byte = a ||| b
    [byte | binary_bitwise_or(rest_a, rest_b)]
  end

  def split_buf_list(buf_list) do
    {list_a, list_b} =
    buf_list
    |> Enum.with_index()
    |> Enum.split_with(fn {_val, index} -> rem(index, 2) == 0 end)

    {list_a, _indexes} = Enum.unzip(list_a)
    {list_b, _indexes} = Enum.unzip(list_b)

    {:binary.list_to_bin(list_a), :binary.list_to_bin(list_b)}
  end

  #
  # procedures
  #

  defp pre_update(state, :await) do
    await_device(state)
    :cont
  end

  defp pre_update(state, :once) do
    case read_busy(state) do
      1 -> :cont
      0 -> :halt
    end
  end

  defp log(msg) when is_binary(msg) do
    IO.puts(msg)
    Logger.info(msg)
  end

  defp log(state, msg) when is_binary(msg) do
    IO.puts(msg)
    Logger.info(msg)
    state
  end

  defp do_update(state, display, border, buffer) do
    Logger.info("border: #{inspect(border)}")
    border = :red

    state
    |> log("setting resolution")
    |> set_resolution(display.packed_resolution)
    |> log("setting panel")
    |> set_panel()
    |> log("setting power")
    |> set_power()
    |> log("setting pll")
    |> set_pll_clock_frequency()
    |> log("set tse register")
    |> set_tse_register()
    |> log("set vcom")
    |> set_vcom_data_interval_setting(border)
    |> log("set gate")
    |> set_gate_source_non_overlap_period()
    |> log("disable external flash")
    |> disable_external_flash()
    |> log("set pws")
    |> set_pws_whatever_that_means()
    |> log("power off seq")
    |> power_off_sequence()
    |> log("push pixels")
    |> push_pixel_buffer(buffer)
    |> log("await")
    |> await_device()
    |> log("pon")
    |> pon()
    |> log("await")
    |> await_device()
    |> log("drf")
    |> drf()
    |> log("await")
    |> await_device()
    |> log("pof")
    |> pof()
    |> log("await")
    |> await_device()
    |> log("done")

    {:ok, %State{state | setup?: true}}
  end

  #
  # "routines" and serial commands
  #

  defp reset(state) do
    state
    |> set_reset(0)
    |> sleep(100)
    |> set_reset(1)
    |> sleep(100)
  end

  defp soft_reset(state), do: write_command(state, 0x12)

  # >HH struct.pack, so big-endian, unsigned-sort * 2
  defp set_resolution(state, packed_resolution),
    do: write_command(state, @tres, packed_resolution)

  # Panel Setting
  # 0b11000000 = Resolution select, 0b00 = 640x480, our panel is 0b11 = 600x448
  # 0b00100000 = LUT selection, 0 = ext flash, 1 = registers, we use ext flash
  # 0b00010000 = Ignore
  # 0b00001000 = Gate scan direction, 0 = down, 1 = up (default)
  # 0b00000100 = Source shift direction, 0 = left, 1 = right (default)
  # 0b00000010 = DC-DC converter, 0 = off, 1 = on
  # 0b00000001 = Soft reset, 0 = Reset, 1 = Normal (Default)
  defp set_panel(state), do: write_command(state, @psr, [0b11101111, 0x08])

  defp set_power(state),
    do:
      write_command(state, @pwr, [
        Bitwise.bor(
          Bitwise.bor(
            Bitwise.bor(
              # ??? - not documented in UC8159 datasheet
              Bitwise.<<<(0x06, 3),
              # SOURCE_INTERNAL_DC_DC
              Bitwise.<<<(0x01, 2)
            ),
            # GATE_INTERNAL_DC_DC
            Bitwise.<<<(0x01, 1)
          ),
          # LV_SOURCE_INTERNAL_DC_DC
          0x01
        ),
        # VGx_20V
        0x00,
        # UC8159_7C
        0x23,
        # UC8159_7C
        0x23
      ])

  # Set the PLL clock frequency to 50Hz
  # 0b11000000 = Ignore
  # 0b00111000 = M
  # 0b00000111 = N
  # PLL = 2MHz * (M / N)
  # PLL = 2MHz * (7 / 4)
  # PLL = 2,800,000 ???
  defp set_pll_clock_frequency(state), do: write_command(state, 0x3C)

  defp set_tse_register(state), do: write_command(state, 0x00)

  defp set_vcom_data_interval_setting(state, border),
    do: write_command(state, @cdi, [Bitwise.bor(Bitwise.<<<(@colors[border], 5), 0x17)])

  defp set_gate_source_non_overlap_period(state), do: write_command(state, @tcon, 0x22)
  defp disable_external_flash(state), do: write_command(state, @dam, 0x00)
  defp set_pws_whatever_that_means(state), do: write_command(state, @pws, 0xAA)
  defp power_off_sequence(state), do: write_command(state, @pfs, 0x00)
  defp push_pixel_buffer(state, buffer), do: write_command(state, @dtm1, buffer)
  defp pon(state), do: write_command(state, @pon)
  defp drf(state), do: write_command(state, @drf)
  defp pof(state), do: write_command(state, @pof)

  #
  # waiting
  #

  defp await_device(state) do
    case read_busy(state) do
      0 ->
        sleep(state, 10)
        await_device(state)

      1 ->
        state
    end
  end

  #
  # pipe-able wrappers
  #

  defp sleep(state, sleep_time) do
    io_call(state, :handle_sleep, [sleep_time])
    state
  end

  defp set_reset(state, value) do
    io_call(state, :handle_reset, [value])
    state
  end

  defp read_busy(state) do
    io_call(state, :handle_read_busy)
  end

  defp write_command(state, command) do
    io_call(state, :handle_command, [command])
    state
  end

  defp write_command(state, command, data) do
    io_call(state, :handle_command, [command, data])
    state
  end

  #
  # Behaviour dispatching
  #

  # Dispatch to the IO callback module that's held in state, using the previously obtained state
  defp io_call(state, op, args \\ []) do
    apply(state.io_mod, op, [state.io_state | args])
  end
end
