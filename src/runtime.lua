require "src/ast"
require "src/types"
local runtime = {}

function runtime.eval(context, val)
    assert(context.type == "vase")
    assert(val.type == "ast")
    local tab= ({
        ["let"] = function()
            local e = runtime.eval(context,val.value)
            local new_con = context.v:add(e)
            -- i think this is wrong - should at least be types.val(e)
            -- and then always fetching via axis
            local new_con_ty =
                types.cell(types.face(val.bind,e),context.t)
            return runtime.eval(types.vase(new_con,new_con_ty), val.rest)
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
                error()
            end
        end,
        ["val"] = function()
            return value.from_ast(val)
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
            elseif ty.type == "types" then
                -- fetch via axis
                error('not implemented')
            else
                print("fetch gave back type "..ty.type)
            end
        end
    });
    assert(tab[val.tag] ~= nil or print("bad eval "..val.tag))
    return tab[val.tag]()
end

return runtime
