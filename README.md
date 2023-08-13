# Inky

[![CircleCI](https://circleci.com/gh/pappersverk/inky.svg?style=svg)](https://circleci.com/gh/pappersverk/inky)
[![hex.pm](https://img.shields.io/hexpm/v/inky.svg)](https://hex.pm/packages/inky)

This is a port of Pimoroni's [python Inky
library](https://github.com/pimoroni/inky) written in Elixir. This library is
intended to support the Inky pHAT and Inky Impression. Eventually it will support the Inky wHAT as well but it is not currently supported.

See the [API reference](https://hexdocs.pm/inky/api-reference.html) for details
on how to use the functionality provided.

### Host Development

An [inky host development](https://github.com/pappersverk/inky_host_dev) library
is underway for allowing host-side development, but until that is finished you
can not see results without using a physical device.

### Scenic Driver

There is [basic driver](https://github.com/pappersverk/scenic_driver_inky) for use with
[scenic](https://github.com/ScenicFramework/scenic).

## Getting started

Inky is available on Hex. Add inky to your mix.exs deps:

```elixir
{:inky, "~> 1.0.2"},
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
type = :phat_il91874
{:ok, pid} = Inky.start_link(type, accent: :red, name: InkySample)

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

Inky.set_pixels(InkySample, painter, border: :white)

# Flip a few pixels
Inky.set_pixels(pid, %{{0,0}: :black, {3,49}: :red, {23, 4}: white})
```

## Figuring out the value to pass for `type`

- Inky pHAT ordered roughly before 2019 -> `:phat_il91874`
- Inky pHAT ordered roughly after 2019 -> `:phat_ssd1608`
- Inky Impression 4" -> `:impression_4`
- Inky Impression 5.7" -> `:impression_5_7`
- Inky Impression 7.3" -> `:impression_7_3`
- Inky wHAT: **Not currently supported**
