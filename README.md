# Inky

[![CircleCI](https://circleci.com/gh/pappersverk/inky.svg?style=svg)](https://circleci.com/gh/pappersverk/inky)
[![hex.pm](https://img.shields.io/hexpm/v/inky.svg)](https://hex.pm/packages/inky)

This is a port of Pimoroni's [python Inky
library](https://github.com/pimoroni/inky) written in Elixir. This library is
intended to support both Inky pHAT and wHAT, but since we only have pHATs, the
wHAT support may not be fully functional.

See the [API reference](https://hexdocs.pm/inky/api-reference.html) for details
on how to use the functionality provided.

### Host Development

An [inky host development](https://github.com/pappersverk/inky_host_dev) library
is underway for allowing host-side development, but until that is finished you
can not see results without using a physical device.

### Scenic Driver

A [basic driver](https://github.com/pappersverk/scenic_driver_inky) for scenic
is in the works, check it out, to follow how it is progressing.

## Getting started

Inky is available on Hex. Add inky to your mix.exs deps:

```elixir
{:inky, "~> 1.0.0"},
```

Run `mix deps.get` to get the new dep.

## Usage

A sample for Inky only, both host development and on-device is available as [pappersverk/sample_inky](https://github.com/pappersverk/sample_inky).

A sample for using it with Scenic both for host development and on-device is available as [pappersverk/sample_scenic_inky](https://github.com/pappersverk/sample_scenic_inky).

## Brief example

In typical usage this would be inside a nerves project. If Inky is installed in
your application you can do the following to test it and your display (note the
config in init, adjust accordingly):

```elixir
# Start your Inky process ...
{:ok, pid} = Inky.start_link(:phat, :red, %{name: InkySample})

painter = fn x, y, w, h ->
  wh = w / 2
  hh = h / 2

  case {x >= wh, y >= hh} do
    {true, true} -> :red
    {false, true} -> if(rem(x, 2) == 0, do: :black, else: :white)
    {true, false} -> :black
    {false, false} -> :white
  end
end

Inky.set_pixels(InkySample, painter, border: :white)

# Flip a few pixels
Inky.set_pixels(pid, %{{0,0} => :black, {3,49} => :red, {140, 4} => :white})
```
