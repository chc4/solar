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

function value.repr(context,val,arm)
    expect_type(context,"context","vase")
    expect_type(val,"val","ast")
    -- returns the actual representation. should be nock for cores, but isnt
    local tab = {
        ["val"] = function()
            table.print(val)
            if type(val.value) == "number" then
                return value.number { value = val.value }
            elseif val.value.tag == "lark" then
                return types.lark(context, val.value.axis).v
            end
            error("fall through")
        end,
        ["cons"] = function()
            return value.cell {
                left = runtime.eval(context, val.left),
                right = runtime.eval(context, val.right)
            }
        end,
        ["core"] = function()
            --  cores are just [context [arms]]
            local coil = nil
            if #val.arms == 0 then
                coil = value.number { value = 0 }
            else
                for _,arm in next,val.arms do
                    local twig = arm[2]
                    expect_type(twig,"twig","ast",delay(table.print,twig))
                    -- we're emitting the ast as the other node
                    -- make sure no one can read core.right!
                    if coil == nil then
                        coil = twig
                    else
                        coil = value.cell {
                            left = twig,
                            right = coil
                        }
                    end
                end
            end
            return value.cell {
                left = table.copy(context.v),
                right = coil
            }
        end,
    }
    expect(tab[val.tag],"repr of val."..val.tag)
    return tab[val.tag]()
end


return value
