defmodule Inky.HAL.PhatIL91874Test do
  @moduledoc false

  use ExUnit.Case

  alias Inky.Display
  alias Inky.HAL.PhatIL91874
  alias Inky.TestIO

  import Inky.TestUtil, only: [gather_messages: 0, pos2col: 2]
  import Inky.TestVerifier, only: [load_spec: 2, check: 2]

  defp init_pixels(display) do
    for i <- 0..(display.width - 1),
        j <- 0..(display.height - 1),
        do: {{i, j}, pos2col(i, j)},
        into: %{}
  end

  setup_all do
    pixels =
      Display.spec_for(:phat_il91874, :black)
      |> init_pixels()

    %{pixels: pixels}
  end

  describe "happy paths" do
    test "that init dispatches properly" do
      display = Display.spec_for(:phat_il91874, :black)
      # act
      PhatIL91874.init(%{
        display: display,
        io_args: [],
        io_mod: TestIO
      })

      # assert
      assert_received {:init, [spi_mod: Circuits.SPI, gpio_mod: Circuits.GPIO]}
      refute_receive _
    end

    test "that update dispatches properly when the device is never busy", ctx do
      # arrange, read_busy always returns 0
      display = Display.spec_for(:phat_il91874, :black)

      init_args = %{
        display: display,
        io_args: [
          read_busy: 0
        ],
        io_mod: TestIO
      }

      state = PhatIL91874.init(init_args)

      # act
      :ok = PhatIL91874.handle_update(ctx.pixels, display.accent, :await, state)

      # assert
      assert_received {:init, _}
      assert TestIO.assert_expectations() == :ok
      spec = load_spec("data/success1.dat", __DIR__)
      mailbox = gather_messages()
      assert check(spec, mailbox) == {:ok, 30}
    end

    test "that update dispatches properly when the device is a little busy", ctx do
      # arrange, read_busy is a little busy each time, we expect two wait-loops.
      display = Display.spec_for(:phat_il91874, :black)

      init_args = %{
        display: display,
        io_args: [
          read_busy: [1, 1, 1, 0, 1, 1, 0]
        ],
        io_mod: TestIO
      }

      state = PhatIL91874.init(init_args)

      # act
      :ok = PhatIL91874.handle_update(ctx.pixels, display.accent, :await, state)

      # assert
      assert_received {:init, _}
      assert TestIO.assert_expectations() == :ok
      spec = load_spec("data/success2.dat", __DIR__)
      mailbox = gather_messages()
      assert check(spec, mailbox) == {:ok, 40}
    end

    defp get_border_command() do
      Enum.filter(gather_messages(), fn
        {:send_command, {0x3C, _}} -> true
        _ -> false
      end)
    end

    defp get_vhs_and_vhl_voltage_command() do
      Enum.filter(gather_messages(), fn
        {:send_command, {0x04, _}} -> true
        _ -> false
      end)
    end

    test "test border, black accent", ctx do
      display = Display.spec_for(:phat_il91874, :black)
      init_black = %{display: display, io_args: [read_busy: 0], io_mod: TestIO}
      black_state = PhatIL91874.init(init_black)

      # black accent, black border
      :ok = PhatIL91874.handle_update(ctx.pixels, :black, :await, black_state)
      assert get_border_command() == [send_command: {60, 0}]

      # black accent, white border
      :ok = PhatIL91874.handle_update(ctx.pixels, :white, :await, black_state)
      assert get_border_command() == [send_command: {60, 49}]
    end

    test "red accent, red border", ctx do
      # arrange
      display = Display.spec_for(:phat_il91874, :red)
      init_red = %{display: display, io_args: [read_busy: 0], io_mod: TestIO}
      red_state = PhatIL91874.init(init_red)

      # act, explicit border
      :ok = PhatIL91874.handle_update(ctx.pixels, :red, :await, red_state)
      assert get_border_command() == [send_command: {60, 115}]

      # act, implicit border
      :ok = PhatIL91874.handle_update(ctx.pixels, :accent, :await, red_state)
      assert get_border_command() == [send_command: {60, 115}]
    end

    test "yellow accent, yellow border", ctx do
      # arrange
      display = Display.spec_for(:phat_il91874, :yellow)
      init_yellow = %{display: display, io_args: [read_busy: 0], io_mod: TestIO}
      yellow_state = PhatIL91874.init(init_yellow)

      # act, explicit border
      :ok = PhatIL91874.handle_update(ctx.pixels, :yellow, :await, yellow_state)
      assert get_border_command() == [send_command: {60, 51}]

      # act, implicit border
      :ok = PhatIL91874.handle_update(ctx.pixels, :accent, :await, yellow_state)
      assert get_border_command() == [send_command: {60, 51}]
    end

    test "yellow display, what", ctx do
      # arrange
      display = Display.spec_for(:what, :yellow)
      init_red = %{display: display, io_args: [read_busy: 0], io_mod: TestIO}
      red_state = PhatIL91874.init(init_red)

      :ok = PhatIL91874.handle_update(ctx.pixels, :accent, :await, red_state)
      assert get_vhs_and_vhl_voltage_command() == [send_command: {0x04, 0x07}]
    end

    test "yellow display, phat", ctx do
      # arrange
      display = Display.spec_for(:phat_il91874, :yellow)
      init_red = %{display: display, io_args: [read_busy: 0], io_mod: TestIO}
      red_state = PhatIL91874.init(init_red)

      :ok = PhatIL91874.handle_update(ctx.pixels, :accent, :await, red_state)
      assert get_vhs_and_vhl_voltage_command() == [send_command: {0x04, 0x07}]
    end

    test "red accent, what display", ctx do
      # arrange
      display = Display.spec_for(:what, :red)
      init_red = %{display: display, io_args: [read_busy: 0], io_mod: TestIO}
      red_state = PhatIL91874.init(init_red)

      :ok = PhatIL91874.handle_update(ctx.pixels, :red, :await, red_state)
      assert get_vhs_and_vhl_voltage_command() == [send_command: {0x04, <<0x30, 0xAC, 0x22>>}]
    end
  end
end
