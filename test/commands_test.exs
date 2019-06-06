defmodule Inky.CommandsTest do
  use ExUnit.Case

  alias Inky.Commands
  alias Inky.TestIO

  import Inky.TestUtil

  describe "happy paths" do
    test "that init dispatches properly" do
      # act
      Commands.init_io(TestIO, [])

      # assert
      assert_received {:init, []}
    end

    test "that update dispatches properly" do
      # arrange
      display = Inky.Displays.Display.spec_for(:phat)

      pixels =
        for i <- 0..(display.width - 1),
            j <- 0..(display.height - 1),
            do: {{i, j}, pos2col(i, j)},
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
      # first drop the init, because we're not testing that.
      assert_received {:init, init_opts}

      spec = Inky.TestVerifier.load("data/success.dat", __DIR__)
      mailbox = gather_messages()
      assert Inky.TestVerifier.check(spec, mailbox) == {:ok, 41}
      # Inky.TestVerifier.store(mailbox, "data/success.dat")
    end
  end
end
