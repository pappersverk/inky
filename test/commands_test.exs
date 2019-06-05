defmodule Inky.CommandsTest do
  use ExUnit.Case

  alias Inky.InkyIO
  alias Inky.Commands
  alias Inky.TestIO

  describe "happy paths" do
    defmodule TestIO do
      @behaviour InkyIO

      def init(args) do
        args[:read_busy] && Process.put(:read_busy, args[:read_busy])
        send(self(), {:init, args})
        {:init, args}
      end

      def sleep({:init, _}, duration_ms), do: send(self(), {:sleep, duration_ms})

      # TODO: make this stateful by looking at args in init and proccess dictionary trickery
      def read_busy({:init, _}) do
        busy_sequence = Process.get(:read_busy, :value_missing)
        busy = hd(busy_sequence)

        Process.put(:read_busy, tl(busy_sequence))
        send(self(), {:read_busy, busy})

        busy
      end

      def write_reset({:init, _}, bit), do: send(self(), {:write_reset, bit})
      def send_command({:init, _}, command), do: {send(self(), {:send_command, command}), ""}

      def send_command({:init, _}, command, data),
        do: {send(self(), {:send_command, {command, data}}), ""}
    end

    def gather_messages(acc \\ []) do
      receive do
        msg -> gather_messages([msg | acc])
      after
        0 -> Enum.reverse(acc)
      end
    end

    test "that init dispatches properly" do
      Commands.init_io(TestIO, [])

      assert_received {:init, []}
    end

    test "that update dispatches properly" do
      # arrange
      pos2col = fn _i, j ->
        r = rem(j, 3)

        cond do
          r == 0 -> :white
          r == 1 -> :black
          r == 2 -> :red
        end
      end

      display = Inky.Displays.Display.spec_for(:phat)

      pixels =
        for i <- 0..(display.width - 1),
            j <- 0..(display.height - 1),
            do: {{i, j}, pos2col.(i, j)},
            into: %{}

      init_opts = [read_busy: [1, 1, 1, 0, 1, 1, 0]]
      state = Commands.init_io(TestIO, init_opts)

      # TODO: replace these with meaningful, _MINIMAL_ binaries (test display required?)
      buf_black = Inky.PixelUtil.pixels_to_bitstring(pixels, display, :black)
      buf_red = Inky.PixelUtil.pixels_to_bitstring(pixels, display, :red)
      Inky.PixelUtil.pixels_to_bitstring(pixels, display, :red)

      # act
      :ok = Commands.update(state, display, buf_black, buf_red)

      # assert
      assert_received {:init, init_opts}
      mailbox = gather_messages()

      # TODO: write an interaction verifier
      #       - that ignores pixel bitstrings (PixelUtil should be tested...)
      #       - that checks read_busy counts look good
      # TODO: assert instead of inspecting when there is a verifier in place
      IO.inspect(mailbox,
        label: "TestIO sent:",
        width: 90,
        limit: :infinity,
        # :infinity when you want to get the whole thing
        printable_limit: 100
      )
    end
  end
end
