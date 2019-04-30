state = Inky.setup(nil, :phat, :red)
state = Enum.reduce(0..(state.height - 1), state, fn y, state ->Enum.reduce(0..(state.width - 1), state, fn x, state ->Inky.set_pixel(state, x, y, state.red)end)end)
Inky.show(state)


Enum.reduce(
    0..(state.height - 1),
    state,
    fn y, state ->
        Enum.reduce(
            0..(state.width - 1),
            state,
            fn x, state ->
                IO.inspect({x, y})
                state
            end
        )
    end
)

grid = Enum.reduce(0..(state.height-1), "", fn y, grid ->
        row = Enum.reduce(0..(state.width-1), "", fn x, row ->
                color_value = Map.get(state.pixels, {x, y}, 0)
                row <> case color_value do
                    0 -> "W"
                    1 -> "B"
                    2 -> "R"
                end
        end)
        grid <> row <> "\n"
end)
