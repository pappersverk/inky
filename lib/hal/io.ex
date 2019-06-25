defmodule Inky.InkyIO do
  @moduledoc """
  A behaviour for defining how IO is performed on a specific platform.
  """

  @type init_opt :: {:pin_mappings, map()}

  @type io_state :: any()
  @type io_bit :: 0 | 1
  @type io_command :: non_neg_integer()
  @type io_data :: integer() | binary() | [integer() | binary()]

  @callback init(opts :: [init_opt()]) :: io_state()

  @callback handle_sleep(state :: io_state(), sleep_time :: non_neg_integer()) :: :ok
  @callback handle_read_busy(state :: io_state()) :: io_bit()
  @callback handle_reset(state :: io_state(), value :: io_bit()) :: :ok
  @callback handle_command(state :: io_state(), command :: io_command()) ::
              {:ok, binary()} | {:error, any()}
  @callback handle_command(state :: io_state(), command :: io_command(), data :: io_data()) ::
              {:ok, binary()} | {:error, any()}
end
