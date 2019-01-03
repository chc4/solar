require "src/ast"
require "src/types"
local runtime = {}

runtime.jets = {}

function runtime.jets.add(a,b,...)
    expect(a and b, "not enough args for add")
    expect(select('#',...) == 0, "too many args for add")
    expect(a.tag == "number", "a isnt a number")
    expect(b.tag == "number", "b isnt a number")
    return value.atom { value = a + b, aura = "u", example = 0 }
end

function runtime.eval(context, val)
    expect_type(context,"context","vase")
    assert(val.type == "ast")
    local tab= ({
        ["_let"] = function()
            local e = runtime.eval(context,val.value)
            local new_con = context.v:add(e)
            -- this is wrong - should be type_ast(context,val.value)
            -- and then always fetching via axis
            local new_con_ty =
                types.cell(types.face(val.bind,e),context.t)
            return runtime.eval(types.vase(new_con,new_con_ty), val.rest)
        end,
        ["cons"] = function()
            return value.cell {
                left = runtime.eval(context, val.left),
                right = runtime.eval(context, val.right)
            }
        end,
        ["face"] = function()
            return runtime.eval(context, val.value)
            --[[
            return value.face {
                bind = val.bind,
                value = runtime.eval(context,val.value)
            }
            ]]
        end,
        ["in"] = function()
            local ctx = types.vase(
                runtime.eval(context, val.context),
                types.type_ast(context,val.context)
            )
            return runtime.eval(ctx, val.code)
        end,
        ["if"] = function()
            local c = runtime.eval(context, val.cond)
            if c.value then
                if c.value == 1 then
                    return runtime.eval(context, val.if_true)
                else
                    return runtime.eval(context, val.if_false)
                end
            else
                print("bad if cond")
                table.print(c)
            end
        end,
        ["val"] = function()
            table.print(val)
            if type(val.value) == "number" then
                return value.number { value = val.value }
            elseif val.value.tag == "lark" then
                return types.lark(context, val.value.axis).v
            end
            error("fall through")
        end,
        ["fetch"] = function()
            print("rt.eval fetch of "..val.bind)
            local axis, ty = types.axis_of(context, val.bind)
            table.print(ty)
            --assert(type(axis) == "number" and ty.type == "types")
            print("found "..val.bind.." at "..axis)
            if ty.type == "ast" or ty.type == "value" then
                return ty
                --return runtime.eval(context, ty)
            elseif ty.type == "vase" then
                -- fetch via axis
                table.print(ty)
                return ty.v
            else
                error("fetch gave back type "..ty.type)
            end
        end,
        ["bump"] = function()
            local at = runtime.eval(context, val.atom)
            expect(at.tag == "number","bump an atom not "..at.tag)
            return value.number({value = 1+at.value})
        end
    });
    table.print(val)
    expect(tab[val.tag], "bad eval on `"..val.tag.."`")
    local ret = tab[val.tag]()
    --expect_type(ret,"ret","value")
    if not ret or not (ret.type == "value" or ret.type == "context") then
        table.print(ret)
        error("bad runtime.eval return type")
    end
    return ret
end

return runtime
