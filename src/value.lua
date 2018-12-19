local value = {}

make_ast = enum("value")
value.number = make_ast("number", {"value"})
value.cell = make_ast("cell", {"left", "right"})

function value.from_ast(val)
    assert(val.tag == "val" or print("bad from_ast",val.tag))
    if type(val.value) == "number" then
        return value.number(val.value)
    end
    print("bad from_ast")
    table.print(val)
end

return value
