state = Inky.setup(nil, :phat, :red)
state = Enum.reduce(0..(state.height - 1), state, fn y, state ->Enum.reduce(0..(state.width - 1), state, fn x, state ->Inky.set_pixel(state, x, y, state.white)end)end)
Inky.show(state)

state = Inky.setup(nil, :phat, :red)
state = Enum.reduce(0..(state.height - 1), state, fn y, state ->
    Enum.reduce(0..(state.width - 1), state, fn x, state ->
        color = state.white
        if x < 32 do
            color = state.red
        end

        if x < 16 do
            color = state.black
        end
        # color = case x do
        #     0 -> state.black
        #     1 -> state.black
        #     2 -> state.black
        #     3 -> state.black
        #     4 -> state.red
        #     5 -> state.red
        #     6 -> state.red
        #     7 -> state.red
        #     _ -> state.white
        # end
        Inky.set_pixel(state, x, y, color)
    end)
end)
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
