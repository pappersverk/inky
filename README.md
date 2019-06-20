# Inky

[![CircleCI](https://circleci.com/gh/pappersverk/inky.svg?style=svg)](https://circleci.com/gh/pappersverk/inky) [![hex.pm](https://img.shields.io/hexpm/v/inky.svg)](https://hex.pm/packages/inky)

This is a port of Pimoroni's [python Inky library](https://github.com/pimoroni/inky) written in Elixir. This library is intended to support both Inky pHAT and wHAT, but since we only have pHATs, the wHAT support may not be fully functional.

See the [documentation](https://hexdocs.pm/inky/api-reference.html) for details regarding how to use the functionality provided.

See [testrun.exs](./testrun.exs) for some simple usage examples.

The inky_host_dev library is underway for allowing host-side development, but until that is finished you can not see results without using a physical device.

A basic driver for scenic is in the works, check it out at https://github.com/pappersverk/scenic_driver_inky, to follow how it is progressing.

## Getting started

Inky is available on Hex. Add inky to your mix.exs deps:

```elixir
{:inky, "~> 0.0.1"},
```

Run `mix deps.get` to get the new dep.

In typical usage this would be inside a nerves project. If Inky is installed in your application you can do the following to test it and your display (note the config in init, adjust accordingly):

```elixir
# Quadrants (one striped)
state = Inky.init(:phat, :red)

state =
  Enum.reduce(0..(state.display.height - 1), state, fn y, state ->
    Enum.reduce(0..(state.display.width - 1), state, fn x, state ->
      x_big = x >= width / 2
      y_big = y >= height / 2

      color =
        case {x_big, y_big} do
          {true, true} -> :accent
          {true, false} when rem(x, 2) == 0 -> :black
          {true, false} -> :white
          {false, true} -> :black
          {false, false} -> :white
        end
      Inky.set_pixel(state, x, y, color)
    end)
  end)

state = Inky.show(state)
```
