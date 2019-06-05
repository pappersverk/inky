defmodule Inky.InkyIO do
  @type init_opt :: {:pin_mappings, map()}

  @type io_state :: any()
  @type io_bit :: 0 | 1
  @type io_command :: non_neg_integer()
  @type io_data :: integer() | binary() | [integer() | binary()]

  @callback init([init_opt()]) :: io_state()

  @callback sleep(io_state(), non_neg_integer()) :: :ok
  @callback read_busy(io_state()) :: io_bit()
  @callback write_reset(io_state(), io_bit()) :: :ok
  @callback send_command(io_state(), io_command()) ::
              {:ok, binary()} | {:error, any()}
  @callback send_command(io_state(), io_command(), io_data()) ::
              {:ok, binary()} | {:error, any()}
end
