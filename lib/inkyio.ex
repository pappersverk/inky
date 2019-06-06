defmodule Inky.InkyIO do
  @type init_opt :: {:pin_mappings, map()}

  @type io_state :: any()
  @type io_bit :: 0 | 1
  @type io_command :: non_neg_integer()
  @type io_data :: integer() | binary() | [integer() | binary()]

  @callback init([init_opt()]) :: io_state()

  @callback handle_sleep(io_state(), non_neg_integer()) :: :ok
  @callback handle_read_busy(io_state()) :: io_bit()
  @callback handle_reset(io_state(), io_bit()) :: :ok
  @callback handle_command(io_state(), io_command()) ::
              {:ok, binary()} | {:error, any()}
  @callback handle_command(io_state(), io_command(), io_data()) ::
              {:ok, binary()} | {:error, any()}
end
