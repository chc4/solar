require "src/ast"
require "src/types"
require "src/value"
runtime = {}

runtime.jets = {}

function runtime.jets.add(a,b,...)
    expect(a and b, "not enough args for add")
    expect(select('#',...) == 0, "too many args for add")
    expect(a.tag == "number", "a isnt a number")
    expect(b.tag == "number", "b isnt a number")
    return value.atom { value = a + b, aura = "u", example = 0 }
end

function runtime.fetch(context,axis)
    if axis == 1 then
        return context
    elseif axis % 2 == 0 then
        return runtime.fetch(context,axis / 2).left
    else
        return runtime.fetch(context,(axis - 1) / 2).right
    end
end

function runtime.change(context, axis, val)
    if axis == 1 then
        return val
    elseif axis % 2 == 0 then
        context.left = runtime.change(context,axis / 2, val)
        return context
    else
        context.right = runtime.fetch(context,(axis - 1) / 2, val)
        return context
    end
end

function runtime.eval(context, val)
    expect_type(context,"context","vase")
    expect_type(val,"val","ast")
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
            return value.repr(context,val)
        end,
        ["core"] = function()
            return value.repr(context,val)
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
            return value.repr(context,val)
        end,
        ["fetch"] = function()
            print("rt.eval fetch of "..val.bind)
            table.print(context)
            local ax = types.axis_of(context.t, val.bind)
            table.print(ax)
            --assert(type(axis) == "number" and ty.type == "types")
            print("found "..val.bind.." at "..ax[2])
            if ax[1] == "face" then
                -- fetch via axis
                table.print(context)
                return runtime.fetch(context.v,ax[2])
            elseif ax[1] == "core" then
                -- resolves to an arm - need to call .*[arm core]
                local core = runtime.fetch(context.v,ax[4])
                table.print(context.v)
                print("arm axis is "..ax[2])
                local arm = runtime.fetch(core,ax[2])
                return runtime.eval(types.vase(core,ax[5]),arm)
            else
                error("fetch gave back type "..ty.type)
            end
        end,
        ["bump"] = function()
            local at = runtime.eval(context, val.atom)
            expect(at.tag == "number","bump an atom not "..at.tag)
            return value.number({value = 1+at.value})
        end,
        ["change"] = function()
            local obj = table.copy(runtime.eval(context, val.value))
            local ty = types.type_ast(context, val.value)
            -- TODO: this is wrong! ty should be updated each time
            for _,patch in next,val.changes do
                local ax = types.axis_of(ty, patch[1])
                local val = runtime.eval(context, patch[2])
                obj = runtime.change(obj, ax[2], val)
            end
            return obj
        end
    });
    table.print(val)
    expect(tab[val.tag], "bad eval on `"..val.tag.."`")
    local ret = tab[val.tag]()
    --expect_type(ret,"ret","value")
    if not ret or not (ret.type == "value" or ret.type == "context") then
        print(val.tag)
        print(ret.tag)
        table.print(ret)
        error("bad runtime.eval return type")
    end
    return ret
end

return runtime
