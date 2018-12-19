local types = {}

make_type = enum("types")
types.face = make_type("face",{"bind","value"})
types.fork = make_type("fork",{"variants"}) -- TODO: normalize
types.atom = make_type("atom",{"value","aura","example"})
types.cell = make_type("cell",{"left","right"})
types.void = make_type("void",{})

function types.vase(v, t)
    assert(v and t)
    return {type="vase",v=v,t=t}
end

function types.vase_go(name,vas)
    if vas.type ~= "vase" or not vas.v or not vas.t or not vas.v[name] or not vas.t[name] then
        table.print(vas)
        print("attempted to go to "..name)
        error()
    end
    return types.vase(vas.v[name],vas.t[name])
end

function types.vase_cons(left,right)
    local c = types.cell(left.t,right.t)
    return types.vase(value.cell(left.v,left.v),c)
end

-- should probably be doing visitor tbh
function types.axis_of(context,bind,axis)
    axis = axis or 1
    print("bind:",bind)
    table.print(context)
    assert(context.type == "vase")
    if bind == 1 then
        return axis,context.t
    end
    if context.t.tag == "face" then
        if context.t.bind == bind then
            return axis,context.t.value
        else
            return nil --types.axis_of(types.vase(context.v.value,context.t),bind,axis)
        end
    elseif context.t.tag == "cell" then
        local n_axis, ty = types.axis_of(types.vase_go("left",context),bind,axis*2)
        if ty then
            return n_axis,ty
        else
            return types.axis_of(types.vase_go("right",context),bind,axis*2+1)
        end
    end
    table.print(context)
    error("can't find "..bind.." in context")
end

function types.type_ast(context,ast)
    assert(context.type == "vase")
    assert(ast.type == "ast")
    local tab = {
        ["val"] = function()
            if type(ast.value) == "number" then
                return types.atom(ast.value, nil, ast.value)
            end
            table.print(ast.value)
            error("unhandled typing val "..type(ast.value))
        end,
        ["if"] = function()
            table.print(ast)
            local vars = {}
            table.insert(vars, types.type_ast(context, ast.if_true))
            table.insert(vars, types.type_ast(context, ast.if_false))
            return types.fork(vars)
        end,
        ["let"] = function()
            local new_context = context.v:add(ast.value) --ast.bind, ast.value)
            local new_context_ty =
                types.cell(types.face(ast.bind,types.type_ast(context,ast.value)),context.t)
            assert(new_context)
            return types.type_ast(
                types.vase(new_context, new_context_ty)
            , ast.rest)
        end,
        ["fetch"] = function()
            local axis,ty = types.axis_of(context,ast.bind)
            if not axis or not ty then
                print("fetch "..ast.bind.." failed!")
                error()
            end
            table.print(ty)
            assert(type(axis) == "number" and ty.type == "types")
            return ty
        end
    }
    if not tab[ast.tag] then
        table.print(ast)
        error("unhandled tag variant in types_ast")
    end
    return tab[ast.tag]()
end

return types
