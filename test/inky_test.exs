defmodule Inky.InkyTest do
  @moduledoc false

  use ExUnit.Case

  import ExUnit.CaptureLog

  alias Inky.TestHAL
  alias Inky.TestUtil

  doctest Inky

  setup_all do
    init_args = {:test_small, [accent: :red, hal_mod: TestHAL]}
    {:ok, inited_state} = Inky.init(init_args)

    receive do
      {TestHAL, :init} -> :ok
    end

    %{
      inited_state: inited_state,
      init_args: init_args
    }
  end

  describe "Inky init" do
    test "init()", ctx do
      {:ok, _state} = Inky.init(ctx.init_args)
      assert_received {TestHAL, :init}
    end
  end

  describe "Inky updates" do
    test "update pixel data when empty", %{inited_state: is} do
      TestHAL.on_update(:ok)
      pixels = %{{0, 0} => :black, {2, 3} => :red}
      {:reply, :ok, state} = Inky.handle_call({:set_pixels, pixels, %{}}, :from, is)
      TestHAL.assert_expectations()
      assert state.pixels == pixels
    end

    test "update pixel data when already set", %{inited_state: is} do
      TestHAL.on_update(:ok)
      pixels = %{{0, 0} => :black, {2, 3} => :red}
      {:reply, :ok, state} = Inky.handle_call({:set_pixels, pixels, %{}}, :from, is)
      pixels = %{{1, 2} => :white}
      {:reply, :ok, state} = Inky.handle_call({:set_pixels, pixels, %{}}, :from, state)
      TestHAL.assert_expectations()
      assert state.pixels == %{{1, 2} => :white, {0, 0} => :black, {2, 3} => :red}
    end

    test "assert that painter works", %{inited_state: is} do
      TestHAL.on_update(:ok)

      painter = fn x, y, w, h, _pixels_so_far ->
        wh = w / 2
        hh = h / 2

        case {x >= wh, y >= hh} do
          {true, true} -> :red
          {false, true} -> if(rem(x, 2) == 0, do: :black, else: :white)
          {true, false} -> :black
          {false, false} -> :white
        end
      end

      {:reply, :ok, state} =
        Inky.handle_call({:set_pixels, painter, %{border: :white}}, :from, is)

      # Flip a few pixels
      pixels = %{{0, 0} => :black, {3, 49} => :red, {23, 4} => :white}
      {:reply, :ok, state} = Inky.handle_call({:set_pixels, pixels, %{}}, :from, state)

      expected_pixels = %{
        {0, 0} => :black,
        {3, 49} => :red,
        {23, 4} => :white,
        {0, 1} => :white,
        {0, 2} => :black,
        {0, 3} => :black,
        {1, 0} => :white,
        {1, 1} => :white,
        {1, 2} => :white,
        {1, 3} => :white,
        {2, 0} => :black,
        {2, 1} => :black,
        {2, 2} => :red
      }

      assert state.pixels == expected_pixels
    end
  end

  describe "Inky timeout" do
    test ":once when device ready", %{inited_state: is} do
      TestHAL.on_update(:ok)
      is = %Inky.State{is | wait_type: :once}
      {:noreply, state} = Inky.handle_info(:timeout, is)
      TestHAL.assert_expectations()
      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, :ok}}]
    end

    test ":once when device busy", %{inited_state: is} do
      TestHAL.on_update(:busy)
      is = %Inky.State{is | wait_type: :once}

      capture_log(fn ->
        {:noreply, state} = Inky.handle_info(:timeout, is)
        TestHAL.assert_expectations()
        assert state.wait_type == :nowait
        assert TestUtil.gather_messages() == [{TestHAL, {:update, {:error, :device_busy}}}]
      end)
    end

    test ":await", %{inited_state: is} do
      TestHAL.on_update(:ok)
      is = %Inky.State{is | wait_type: :await}
      {:noreply, state} = Inky.handle_info(:timeout, is)
      TestHAL.assert_expectations()
      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, :ok}}]
    end
  end
end
