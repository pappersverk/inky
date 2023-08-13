defmodule Inky.IO.PhatTest do
  @moduledoc false

  use ExUnit.Case

  alias Inky.{TestGPIO, TestSPI}

  import Inky.TestUtil, only: [gather_messages: 0]

  test "spi_write only sets the dc pin once" do
    state = Inky.IO.Phat.init()
    # NOTE: discard init messages
    gather_messages()
    Inky.IO.Phat.handle_command(state, 0x42, [0x1, 0x2, 0x4])

    assert gather_messages() == [
             {TestGPIO, {{:gpio, :write}, {{:pid, 22}, 0}}},
             {TestSPI, {{:spi, :transfer}, {{:pid, "spidev0.0"}, <<0x42>>}}},
             {TestGPIO, {{:gpio, :write}, {{:pid, 22}, 1}}},
             {TestSPI, {{:spi, :transfer}, {{:pid, "spidev0.0"}, <<0x1, 0x2, 0x4>>}}}
           ]
  end
end
