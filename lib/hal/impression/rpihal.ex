defmodule Inky.Impression.RpiHAL do
  use Bitwise

  @default_io_mod Inky.Impression.RpiIO

  @moduledoc """
  An `Inky.HAL` implementation responsible for sending commands to the Inky
  screen. It delegates to whatever IO module its user provides at init, but
  defaults to #{inspect(@default_io_mod)}
  """

  @behaviour Inky.HAL

  @color_map %{black: 0, white: 1, green: 2, blue: 3, red: 4, yellow: 5, orange: 6, miss: 1}
  @colors %{
    :black => 0,
    :white => 1,
    :green => 2,
    :blue => 3,
    :red => 4,
    :yellow => 5,
    :orange => 6,
    # Not a color, but is used to clear the display
    :clear => 7
  }

  # PANEL SETTING
  @psr 0x00
  # POWER SETTING
  @pwr 0x01
  # POWER OFF
  @pof 0x02
  # POWER OFF SEQUENCE SETTING
  @pofs 0x03
  # POWER ON
  @pon 0x04

  # BTST1
  @btst1 0x05
  @btst2 0x06
  # @dslp 0x07
  @btst3 0x08

  # DATA START TRANSMISSION 1
  @dtm 0x10
  # DISPLAY REFRESH
  @drf 0x12

  #?
  @ipc 0x13

  #?
  @tse 0x41

  # VCOM AND DATA INTERVAL SETTING
  # This command indicates the interval of Vcom and data output. When setting
  # the vertical back porch, the total blanking will be kept (20 Hsync).
  @cdi 0x50
  # TCON SETTING
  # This command defines non-overlap period of Gate and Source.
  @tcon 0x60
  # RESOLUTION SETTING  (TRES)
  # This command defines alternative resolution and this setting is of higher priority than the RES[1:0] in R00H (PSR).
  @tres 0x61
  # SPI FLASH CONTROL
  # This command defines MCU host direct access external memory mode.
  # This might allow us to specify our own lookup tables! Which might mean our own colors!
  @dam 0x65

  # New in impression_7_3
  @vdcs 0x82
  @t_vdcs 0x84
  @agid 0x86
  @cmdh 0xAA
  # @ccset 0xE0

  @ccset 0xE0
  @pws 0xE3
  @tsset 0xE6

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
    Logger.info("push_policy: #{inspect(push_policy, pretty: true)}")
    display = %Display{width: w, height: h, rotation: r} = state.display
    buffer = PixelUtil.pixels_to_bits(pixels, w, h, r, @color_map, 4)
    reset(state)

    case pre_update(state, push_policy) do
      :cont -> do_update(state, display, border, buffer)
      :halt -> {:error, :device_busy}
    end
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

  defp do_update(state, _display, _border, buffer) do
    state
    |> set_cmdh()
    |> set_power_pwr()
    |> set_panel_psr()
    |> power_off_sequence_pofs()
    |> write_command(@btst1, [0x40, 0x1F, 0x1F, 0x2C])
    |> write_command(@btst2, [0x6F, 0x1F, 0x16, 0x25])
    |> write_command(@btst3, [0x6F, 0x1F, 0x1F, 0x22])
    |> write_command(@ipc, [0x00, 0x04])
    |> set_pll_clock_frequency()
    |> write_command(@tse, [0x00])
    # border?
    # TODO: Combine with `set_vcom_data_interval_setting`
    |> write_command(@cdi, [0x3F])
    |> write_command(@tcon, [0x02, 0x00])
    # resolution?
    |> write_command(@tres, [0x03, 0x20, 0x01, 0xE0])
    # |> set_resolution(display.packed_resolution)
    # cont
    |> write_command(@vdcs, [0x1E])
    |> write_command(@t_vdcs, [0x00])
    |> write_command(@agid, [0x00])
    |> write_command(@pws, [0x2F])
    |> write_command(@ccset, [0x00])
    |> write_command(@tsset, [0x00])

    # End of setup
    # TODO: Need to force white somehow?
    # The python driver is doing some bit manipulation before this call
    # https://github.com/pimoroni/inky/blob/98383c5d47928b90ee3951ed72576b7064e573e7/library/inky/inky_ac073tc1a.py#L300
    |> push_pixel_buffer(buffer)
    |> pon()
    |> await_device()
    |> drf()
    |> await_device()
    |> pof()
    |> await_device()


    # |> set_vcom_data_interval_setting(border)
    # |> set_gate_source_non_overlap_period()
    # |> disable_external_flash()
    # |> set_pws_whatever_that_means()
    # |> power_off_sequence_pofs()
    # |> push_pixel_buffer(buffer)
    # |> await_device()
    # |> pon()
    # |> await_device()
    # |> drf()
    # |> await_device()
    # |> pof()
    # |> await_device()

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
    |> set_reset(0)
    |> sleep(100)
    |> set_reset(1)
    |> sleep(100)
    # busy wait?
  end

  # >HH struct.pack, so big-endian, unsigned-short * 2
  # defp set_resolution(state, packed_resolution),
  #   do: write_command(state, @tres, packed_resolution)

  # Panel Setting
  # 0b11000000 = Resolution select, 0b00 = 640x480, our panel is 0b11 = 600x448
  # 0b00100000 = LUT selection, 0 = ext flash, 1 = registers, we use ext flash
  # 0b00010000 = Ignore
  # 0b00001000 = Gate scan direction, 0 = down, 1 = up (default)
  # 0b00000100 = Source shift direction, 0 = left, 1 = right (default)
  # 0b00000010 = DC-DC converter, 0 = off, 1 = on
  # 0b00000001 = Soft reset, 0 = Reset, 1 = Normal (Default)
  defp set_panel_psr(state), do: write_command(state, @psr, [0x5F, 0x69])

  defp set_cmdh(state), do: write_command(state, @cmdh, [0x49, 0x55, 0x20, 0x08, 0x09, 0x18])

  defp set_power_pwr(state), do: write_command(state, @pwr, [0x3F, 0x00, 0x32, 0x2A, 0x0E, 0x2A])

  # Set the PLL clock frequency to 50Hz
  # 0b11000000 = Ignore
  # 0b00111000 = M
  # 0b00000111 = N
  # PLL = 2MHz * (M / N)
  # PLL = 2MHz * (7 / 4)
  # PLL = 2,800,000 ???
  defp set_pll_clock_frequency(state), do: write_command(state, [0x02])

  # defp set_vcom_data_interval_setting(state, border),
  #   do: write_command(state, @cdi, [bor(@colors[border] <<< 5, 0x17)])

  # defp set_gate_source_non_overlap_period(state), do: write_command(state, @tcon, 0x22)
  # defp disable_external_flash(state), do: write_command(state, @dam, 0x00)
  # defp set_pws_whatever_that_means(state), do: write_command(state, @pws, 0xAA)
  defp power_off_sequence_pofs(state), do: write_command(state, @pofs, [0x00, 0x54, 0x00, 0x44])
  defp push_pixel_buffer(state, buffer), do: write_command(state, @dtm, buffer)
  defp pon(state), do: write_command(state, @pon)
  defp drf(state), do: write_command(state, @drf, [0x00])
  defp pof(state), do: write_command(state, @pof, [0x00])

  #
  # waiting
  #

  # busy_wait
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
