Code.require_file("test/support/testhal.exs")

defmodule Inky.InkyTimerTest do
  @moduledoc false

  use ExUnit.Case

  require Logger

  alias Inky.TestHAL
  alias Inky.TestUtil

  doctest Inky

  setup_all do
    init_args = %{accent: :red, hal_mod: TestHAL, type: :test_small}
    {:ok, inited_state} = Inky.init(init_args)

    receive do
      {TestHAL, :init} -> :ok
    end

    %{inited_state: inited_state, init_args: init_args}
  end

  # AWAIT, timer cleared

  describe "Inky update with :await policy leaves timer cleared" do
    test "by default", %{inited_state: is} do
      TestHAL.on_update(:ok)

      {:reply, :ok, state} = Inky.handle_call({:set_pixels, %{}, %{}}, :from, is)

      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, :ok}}]
    end

    test "explicitly set", %{inited_state: is} do
      TestHAL.on_update(:ok)

      {:reply, :ok, state} = Inky.handle_call({:set_pixels, %{}, %{push: :await}}, :from, is)

      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, :ok}}]
    end

    test ":once timer set", %{inited_state: is} do
      TestHAL.on_update(:ok)
      is = %Inky.State{is | wait_type: :once}

      {:reply, :ok, state} = Inky.handle_call({:set_pixels, %{}, %{push: :await}}, :from, is)

      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, :ok}}]
    end

    test ":await timer set", %{inited_state: is} do
      TestHAL.on_update(:ok)
      is = %Inky.State{is | wait_type: :await}

      {:reply, :ok, state} = Inky.handle_call({:set_pixels, %{}, %{push: :await}}, :from, is)

      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, :ok}}]
    end
  end

  # ONCE, device ready

  describe "Inky update with :once policy, device ready" do
    test "no timer", %{inited_state: is} do
      TestHAL.on_update(:ok)

      {:reply, :ok, state} = Inky.handle_call({:set_pixels, %{}, %{push: :once}}, :from, is)

      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, :ok}}]
    end

    test ":once timer", %{inited_state: is} do
      TestHAL.on_update(:ok)
      is = %Inky.State{is | wait_type: :once}

      {:reply, :ok, state} = Inky.handle_call({:set_pixels, %{}, %{push: :once}}, :from, is)

      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, :ok}}]
    end

    test ":await timer", %{inited_state: is} do
      TestHAL.on_update(:ok)
      is = %Inky.State{is | wait_type: :await}

      {:reply, :ok, state} = Inky.handle_call({:set_pixels, %{}, %{push: :once}}, :from, is)

      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, :ok}}]
    end
  end

  # ONCE, device busy

  describe "Inky update with :once policy, device busy" do
    test "no timer", %{inited_state: is} do
      TestHAL.on_update(:busy)

      {:reply, {:error, :device_busy}, state} =
        Inky.handle_call({:set_pixels, %{}, %{push: :once}}, :from, is)

      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, {:error, :device_busy}}}]
    end

    test ":once timer", %{inited_state: is} do
      TestHAL.on_update(:busy)
      is = %Inky.State{is | wait_type: :once}

      {:reply, {:error, :device_busy}, state} =
        Inky.handle_call({:set_pixels, %{}, %{push: :once}}, :from, is)

      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == [{TestHAL, {:update, {:error, :device_busy}}}]
    end

    test ":await timer", %{inited_state: is} do
      TestHAL.on_update(:busy)
      is = %Inky.State{is | wait_type: :await}

      {:reply, {:error, :device_busy}, state, _timeout} =
        Inky.handle_call({:set_pixels, %{}, %{push: :once}}, :from, is)

      assert state.wait_type == :await
      assert TestUtil.gather_messages() == [{TestHAL, {:update, {:error, :device_busy}}}]
    end
  end

  # SKIP

  describe "Inky update with skip policy" do
    test "no timer set", %{inited_state: is} do
      {:reply, :ok, state} = Inky.handle_call({:set_pixels, %{}, %{push: :skip}}, :from, is)

      assert state.wait_type == :nowait
      assert TestUtil.gather_messages() == []
    end

    test ":once timer set", %{inited_state: is} do
      is = %Inky.State{is | wait_type: :once}

      {:reply, :ok, state, _timeout} =
        Inky.handle_call({:set_pixels, %{}, %{push: :skip}}, :from, is)

      assert state.wait_type == :once
      assert TestUtil.gather_messages() == []
    end

    test ":await timer set", %{inited_state: is} do
      is = %Inky.State{is | wait_type: :await}

      {:reply, :ok, state, _timeout} =
        Inky.handle_call({:set_pixels, %{}, %{push: :skip}}, :from, is)

      assert state.wait_type == :await
      assert TestUtil.gather_messages() == []
    end
  end

  # TIMEOUT

  describe "Inky update with timeout" do
    test ":once timer set", %{inited_state: is} do
      {:reply, :ok, state, _timeout} =
        Inky.handle_call({:set_pixels, %{}, %{push: {:timeout, :once}}}, :from, is)

      assert state.wait_type == :once
      assert TestUtil.gather_messages() == []
    end

    test ":await timer set", %{inited_state: is} do
      {:reply, :ok, state, _timeout} =
        Inky.handle_call({:set_pixels, %{}, %{push: {:timeout, :await}}}, :from, is)

      assert state.wait_type == :await
      assert TestUtil.gather_messages() == []
    end

    test ":once timer not dropped", %{inited_state: is} do
      is = %Inky.State{is | wait_type: :once}

      {:reply, :ok, state, _timeout} =
        Inky.handle_call({:set_pixels, %{}, %{push: {:timeout, :once}}}, :from, is)

      assert state.wait_type == :once
      assert TestUtil.gather_messages() == []
    end

    test ":await timer not overridden by :once", %{inited_state: is} do
      is = %Inky.State{is | wait_type: :await}

      {:reply, :ok, state, _timeout} =
        Inky.handle_call({:set_pixels, %{}, %{push: {:timeout, :once}}}, :from, is)

      assert state.wait_type == :await
      assert TestUtil.gather_messages() == []
    end

    test ":once timer replaced by :await", %{inited_state: is} do
      is = %Inky.State{is | wait_type: :once}

      {:reply, :ok, state, _timeout} =
        Inky.handle_call({:set_pixels, %{}, %{push: {:timeout, :await}}}, :from, is)

      assert state.wait_type == :await
      assert TestUtil.gather_messages() == []
    end
  end
end
