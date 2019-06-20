Code.require_file("test/support/testhal.exs")

defmodule Inky.InkyTest do
  @moduledoc false

  use ExUnit.Case

  alias Inky.TestHAL

  doctest Inky

  setup_all do
    %{
      init_args: %{
        accent: :red,
        hal_mod: TestHAL,
        type: :test_small
      }
    }
  end

  describe "Inky init" do
    test "init()", ctx do
      {:ok, _state} = Inky.init(ctx.init_args)

      assert_received {TestHAL, :init}
    end
  end

  describe "Inky updates" do
    test "update pixel data when empty", ctx do
      {:ok, state} = Inky.init(ctx.init_args)
      assert_received {TestHAL, :init}

      Process.put(:update, :ok)
      pixels = %{{0, 0} => :black, {2, 3} => :red}
      {:reply, :ok, state} = Inky.handle_call({:set_pixels, pixels, %{}}, self(), state)

      TestHAL.assert_expectations()
      assert state.pixels == pixels
    end

    test "update pixel data when already set", ctx do
      {:ok, state} = Inky.init(ctx.init_args)
      assert_received {TestHAL, :init}

      Process.put(:update, :ok)
      pixels = %{{0, 0} => :black, {2, 3} => :red}
      {:reply, :ok, state} = Inky.handle_call({:set_pixels, pixels, %{}}, self(), state)
      pixels = %{{1, 2} => :white}
      {:reply, :ok, state} = Inky.handle_call({:set_pixels, pixels, %{}}, self(), state)

      TestHAL.assert_expectations()
      assert state.pixels == %{{1, 2} => :white, {0, 0} => :black, {2, 3} => :red}
    end

    # TODO: painter tests
  end

  describe "Inky update push policies" do
    # TODO: write tests for the internal dispatch_push/2 function
  end
end
