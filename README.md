# InkyZeroNerves

This is a library that is capable of setting pixels and updating the Inky PHAT and WHAT displays. It is a port of the python library at https://github.com/pimoroni/inky

Check out testrun.exs for some simple examples.

It currently only runs on-device aside from the testing.

## Getting started

Add inky to your mix.exs, we will try to get in on that sweet hex action eventually:

```elixir
{:inky, github: "lawik/inky"}
```

Run `mix deps.get` to get the new dep.

In typical usage this would be inside a nerves project. If Inky is installed in your application you can do the following to test it and your display (note the config in init, adjust accordingly):

```elixir
# Quadrants (one striped)
state = Inky.init(:phat, :red)

state =
  Enum.reduce(0..(state.display.height - 1), state, fn y, state ->
    Enum.reduce(0..(state.display.width - 1), state, fn x, state ->
      color = cond do
        x > state.display.width / 2 ->
          cond do
            y > state.display.height / 2 -> :red
            true ->
              cond do
                rem(x, 2) == 0 -> :white
                true -> :black
              end
          end
        true -> 
          cond do
            y > state.display.height / 2 ->
              :black
            true ->
              :white
          end
      end
      Inky.set_pixel(state, x, y, color)
    end)
  end)

state = Inky.show(state)
```

Some other variants are available in testrun.exs.