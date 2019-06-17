# InkyZeroNerves

[![CircleCI](https://circleci.com/gh/pappersverk/inky.svg?style=svg)](https://circleci.com/gh/pappersverk/inky)

This is a library that is capable of setting pixels and updating the Inky PHAT and WHAT displays. It is a port of the python library at https://github.com/pimoroni/inky

Check out testrun.exs for some simple examples.

It currently only runs on-device aside from the testing. The inky_host_dev library is underway for allowing host-side development.

A basic driver for scenic is in the works. Check it out at https://github.com/pappersverk/scenic_driver_inky

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
      x_big = x > width / 2
      y_big = y > height / 2

      color =
        case {x_big, y_big} do
          {true, true} -> :accent
          {true, false} when rem(x, 2) == 0 -> :white
          {true, false} -> :black
          {false, true} -> :black
          {false, false} -> :white
        end
      Inky.set_pixel(state, x, y, color)
    end)
  end)

state = Inky.show(state)
```

Some other variants are available in testrun.exs.