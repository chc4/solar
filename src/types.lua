local types = {}

make_type = enum("types")
types.face = make_type("face",{"bind","value"})
types.fork = make_type("fork",{"variants"}) -- TODO: normalize
types.atom = make_type("atom",{"value","aura","example"})
types.cell = make_type("cell",{"left","right"})
--- core arms are {"name",axis,twig}
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
-- returns {"face",axis,type} or {"core",name,twig,axis,core}
function types.axis_of(context,bind,axis)
    axis = axis or 1
    print("bind:",bind)
    table.print(context)
    assert(context.type == "types")
    if bind == 1 then
        return {"face",axis,context}
    end
    if context.tag == "face" then
        if context.bind == bind then
            return {"face",axis,context}
        else
            return nil --types.axis_of(types.vase(context.v.value,context.t),bind,axis)
        end
    elseif context.tag == "cell" then
        local r = types.axis_of(context.left,bind,axis*2)
        if r then
            return r
        else
            return types.axis_of(context.right,bind,axis*2+1)
        end
    elseif context.tag == "core" then
        -- TODO: allow indexing into core sample
        local arm = context.arms[bind]
        if not arm then return nil end
        return {"core",arm[1],arm[2],axis,context}
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
        return types.vase_go("left",types.lark(context,axis/2))
    else
        return types.vase_go("right",types.lark(context,(axis-1)/2))
    end
end

function types.type_ast(context,ast)
    expect_type(context,"context","vase")
    expect(ast.type == "ast","ast isnt ast, "..ast.type)
    local tab = {
        ["core"] = function()
            local arms = {}
            if #ast.arms == 1 then
                local arm = ast.arms[1]
                -- [[
                -- PROBLEM:
                -- core arms can refer to other core arms, or even themselves
                -- it should be something like type_ast(ast,arm[2]) -
                -- that is, arms being typed in the context of the entire containing
                -- core. this is recursive.
                -- solution are:
                -- * having all arms be %holds. %hold evaluation is lazy, and checks
                --   for loops. a:core would evaluate the a hold with the entire lazy
                --   self, and crash if it tries to evaluate itself again.
                --   pros: can cache typing of arms, explicit crashes
                -- * don't type arms. hoon (and watt) does this, only putting the
                --   twig in the core type. a:core then only types at the call-site,
                --   and will type each arm only as it visit them
                --   cons: easier, how watt does it, can just expand other arms to %hold
                --    and avoid infinite loops at type-check (more powerful metaprogramming?)
                --   (think go with this one: recursive functions still need to refer to themselves,
                --    just in a bounded form, and so need %holds no matter what. also allows
                --    wet cores to be implemented at callsite.)
                -- ]]
                arms = {
                    [arm[1]] = {2,arm[2]}
                }
            else
                for i,arm in next,ast.arms do
                    local axis
                    if i ~= 1 then
                        axis = 6 * (math.pow(2, (#ast.arms - i))) - 2
                    else
                        axis = 6 * (math.pow(2, (i + 1))) - 1
                    end
                    arms[arm[1]] = {axis,arm[2]}
                end
            end
            return types.core {
                context = context.t,
                arms = arms
            }
        end,
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
            local ax = types.axis_of(context.t,ast.bind)
            if not ax then
                print("fetch "..ast.bind.." failed!")
                error()
            end
            table.print(context)
            --assert(type(axis) == "number" and ty.type == "types")
            if ax[1] == "face" then
                return ax[3]
            else
                -- fetch core arm
                print("fetch arm")
                table.print(ax)
                local core = types.lark(context,ax[4])
                return types.type_ast(core,ax[3])
            end
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
