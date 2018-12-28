local value = {}

make_ast = enum("value")
value.number = make_ast("number", {"value"})
value.cell = make_ast("cell", {"left", "right"})
value.face = make_ast("face", {"bind", "value"})
value.lark = make_ast("lark", {"axis"})

function value.from_ast(val)
    expect_type(val,"val","ast")
    if val.tag == "val" then
        expect(type(val.value) == "number")
        return value.number { value = val.value }
    elseif val.tag == "cons" then
        return value.cell {
            left = value.from_ast(val.value.left),
            right = value.from_ast(val.value.right),
        }
    end
    print("bad from_ast")
    table.print(val)
    error("oops")
end

return value
