local types = {}

make_type = enum("types")
types.face = make_type("face",{"bind","value"})
types.fork = make_type("fork",{"variants"}) -- TODO: normalize
types.atom = make_type("atom",{"value","aura","example"})
types.cell = make_type("cell",{"left","right"})
types.core = make_type("core",{"context","arms"}) -- TODO: variance
types.hold = make_type("hold",{"type","twig"})
types.void = make_type("void",{})

function types.vase(v, t)
    assert(v and t)
    return {type="vase",tag="vase",v=v,t=t}
end

function types.vase_go(name,vas)
    expect(vas.type == "vase","vas isnt vase")
    table.print(vas.v)
    --expect(vas.v.type == "value","vas.v isnt value")
    expect(vas.t.type == "types","vas.t isnt type")
    -- nagivate faces?
    return types.vase(vas.v[name],vas.t[name])
end

function types.vase_cons(left,right)
    local c = types.cell { left = left.t, right = right.t }
    expect(left.v, "no left.v")
    expect(right.v, "no right.v")
    return types.vase(value.cell { left = left.v, right = right.v},c)
end

-- should probably be doing visitor pattern tbh
function types.axis_of(context,bind,axis)
    axis = axis or 1
    print("bind:",bind)
    table.print(context)
    assert(context.type == "vase")
    if bind == 1 then
        return axis,context
    end
    if context.t.tag == "face" then
        if context.t.bind == bind then
            return axis,context
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

-- this is where profunctor lenses would come in use
-- bump wants to increment edge nodes but keep structure
-- %= wants to replace axises but keep structure
-- probably have to refactor this so it can be used for runtime?
function types.replace(context,pred,axis,f)
end

function types.lark(context,axis)
    if axis == 1 then
        return context
    elseif axis % 2 == 0 then
        return types.lark(types.vase_go("left",context),axis/2)
    else
        return types.lark(types.vase_go("right",context),(axis-1)/2)
    end
end

function types.type_ast(context,ast)
    expect_type(context,"context","vase")
    expect(ast.type == "ast","ast isnt ast, "..ast.type)
    local tab = {
        ["face"] = function()
            return types.face { bind = ast.bind, value = types.type_ast(context,ast.value) }
        end,
        ["val"] = function()
            --table.print(ast)
            if type(ast.value) == "number" then
                return types.atom { value = ast.value, aura = "u", example = ast.value }
            elseif ast.value.tag == "lark" then
                -- TODO: loses all type info!!!
                -- context should be vase and fetch should use vase_go
                return types.lark(context,ast.value.axis).t
            end
            table.print(ast.value)
            error("unhandled typing val "..type(ast.value))
        end,
        ["cons"] = function()
            return types.cell {
                left = types.type_ast(context, ast.left),
                right = types.type_ast(context, ast.right)
            }
        end,
        ["if"] = function()
            table.print(ast)
            local vars = {}
            table.insert(vars, types.type_ast(context, ast.if_true))
            table.insert(vars, types.type_ast(context, ast.if_false))
            return types.fork { variants = vars }
        end,
        ["in"] = function()
            return types.type_ast(
                types.vase(ast.context, types.type_ast(context, ast.context)),
                ast.code
            )
        end,
        ["_let"] = function()
            local new_context = context.v:add(ast.value) --ast.bind, ast.value)
            local new_context_ty =
                types.cell { left = types.face(ast.bind,types.type_ast(context,ast.value)),
                    right = context.t }
            assert(new_context)
            return types.type_ast(
                types.vase(new_context, new_context_ty)
            , ast.rest)
        end,
        ["fetch"] = function()
            local axis,ty = types.axis_of(context,ast.bind)
            if not axis or not ty then
                print("fetch "..ast.bind.." failed!")
                --error()
            end
            table.print(context)
            --assert(type(axis) == "number" and ty.type == "types")
            return ty.t
        end,
        ["bump"] = function()
            -- TODO: check nest(at, atom), bump edge value nodes at type-level
            local at = types.type_ast(context, ast.atom)
            expect(types.nest(at,types.atom({value = 0,aura = "t",example = 0})))
            return at
        end
    }
    if not tab[ast.tag] then
        table.print(ast)
        error("unhandled tag variant `"..ast.tag.."` in types_ast")
    end
    local ret = tab[ast.tag]()
    expect_type(ret,"ret","types",delay(table.print,ast))
    return ret
end

-- test that `source` is a structural subtype of `target`
function types.nest(source, target)
    expect_type(source,"source","types")
    expect_type(target,"target","types")
    local tab = {
        ["fork"] = function()
            for _,variant in next,source.variants do
                if not types.nest(variant, target) then
                    return false
                end
            end
            return true
        end,
        ["face"] = function()
            return types.nest(source.value, target)
        end,
        ["atom"] = function()
            return target.tag == "atom"
        end
    }
    if tab[source.tag] then
        return tab[source.tag]()
    else
        print("nest")
        table.print(source)
        return table.equals(source, target)
    end
end

return types
