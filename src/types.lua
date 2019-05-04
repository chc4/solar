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
    expect_type(context, "context", "types")
    if bind == 1 then
        return {"face",axis,context}
    end
    if type(bind) == "number" then
        -- TODO: disallow larking into core contexts, variance testing
        function axis_with_axis(root, leaf)
            -- right right within right right
            while leaf ~= 1 do
                if leaf%2 == 0 then
                    root = root * 2
                    leaf = leaf / 2
                else
                    root = root * 2 + 1
                    leaf = (leaf-1)/2
                end
            end
            return root
        end
        print(axis,bind,axis_with_axis(axis,bind))
        table.print(context)
        return {"face",axis_with_axis(axis,bind),types.lark(context,bind)}
    end

    -- this is gross - basically want to test if it's in form "abc.def"
    local multipart = bind:match("^(.+)%.(.+)$")
    if multipart then
        local val = nil
        for node in bind:reverse():gmatch("[^\\.]+") do
            local node = node:reverse()
            if val == nil then
                local ax = types.axis_of(context, node, axis)
                expect(ax[1] == "face", "multipart path root not face")
                val = ax[2]
                context = ax[3]
            else
                -- this is not entirely how hoon does it:
                -- `=<  test.a  ^=  a  |%  ++  test  1  --`     => 1
                -- `=<  test.a  ^=  a  |%  ++  test  |.(1)  --` => <core>
                -- `=<  $.test.a  ^=  a  |%  ++  test  |.(1)  --` => fail
                -- `=<  $:test.a  ^=  a  |%  ++  test  |.(1)  --` => 1
                -- seems like it lets you only eval up to one arm in a path?
                -- idk wtf is going on here, ask someone later
                -- do i need to support this? no one ever uses $.a instead of $:a
                -- they *do* use +<.$, but forcing people to use `this` is better
                -- i want to allow `..add`, maybe
                local ax = types.axis_of(context, node, val)
                expect(ax[1] == "face", "multipart path fragment `"..node.."` not face")
                val = ax[2]
                context = ax[3]
            end
        end
        expect(val, "nil path in fetch?")
        return {"face", val, context}
    end

    if context.tag == "face" then
        if context.bind == bind then
            return {"face", axis, context.value}
        else
            return nil --types.axis_of(types.vase(context.v.value,context.t),bind,axis)
        end
    elseif context.tag == "cell" then
        local r = types.axis_of(context.left, bind, axis*2)
        if r then
            return r
        else
            return types.axis_of(context.right, bind, axis*2+1)
        end
    elseif context.tag == "fork" then
        local r = nil
        local r_fork = {}
        for i,v in next,context.variants do
            local v_axis = types.axis_of(v, bind, axis)
            if not r then
                print("initial fork find set")
                table.print(v_axis)
                assert(v_axis[1] == "face")
                r = v_axis
                table.insert(r_fork, v_axis[3])
            else
                print("testing fork find variant")
                table.print(v_axis)
                -- TODO: checking core fork arm fetches?
                assert(v_axis[1] == "face")
                assert(v_axis[2] == r[2])
                table.insert(r_fork, v_axis[3])
            end
        end
        table.print(r_fork)
        r[3] = types.fork { variants = r_fork }
        return r
    elseif context.tag == "core" then
        -- TODO: allow indexing into core sample
        local r = types.axis_of(context.context, bind, axis*2)
        if r then
            print("found "..bind.." in core context")
            table.print(r)
            return r
        else
            local arm = nil
            for _,v in next,context.arms do
                if v[1] == bind then
                    arm = v
                end
            end
            expect(arm, "no arm "..bind.." in core")
            table.print(arm)
            return {"core", arm[2], arm[3], axis, context}
        end
    end
    table.print(context)
    print("can't find "..bind.." in context")
    return nil
end

-- this is where profunctor lenses would come in use
-- TODO: do we want to allow axis changes? probably not?
function types.change(obj,changes)
    expect_type(obj, "obj", "types")
    local tab = {
        ["face"] = function()
            table.print(obj)
            if changes[obj.bind] then
                local v = types.face { bind = obj.bind, value = changes[obj.bind] }
                changes[obj.bind] = nil
                return v
            else
                obj.value = types.change(obj.value, changes)
                return obj
            end
        end,
        ["atom"] = function()
            return obj
        end,
        ["cell"] = function()
            obj.left = types.change(obj.left, changes)
            obj.right = types.change(obj.right, changes)
            return obj
        end,
        ["core"] = function()
            local tr = {}
            for i,v in next,changes do
                if i%2 == 1 or i==1 then
                    error("attempted to change core battery")
                else
                    tr[i/2] = v
                end
            end
            obj.context = types.change(obj.context, tr)
            return obj
        end
    }
    if tab[obj.tag] then
        return tab[obj.tag]()
    else
        table.print(obj)
        table.print(changes)
        error("cant change "..obj.tag)
    end
end

function types.lark(context,axis)
    if axis == 1 then
        return context
    elseif axis % 2 == 0 then
        if context.tag == "core" then
            print("lark core context")
            table.print(context.context)
            return types.lark(context.context,axis/2)
        elseif context.type == "vase" then
            return types.vase_go("left",types.lark(context,axis/2))
        else
            return types.lark(context.left, axis/2)
        end
    else
        if context.tag == "core" then
            error("attempted to lark into core battery!")
        elseif context.type == "vase" then
            return types.vase_go("right",types.lark(context,(axis-1)/2))
        else
            return types.lark(context.right, (axis-1)/2)
        end
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
                -- [context=2 arm=3]
                -- [context=2 [arm=6 arm=7]]
                -- [context=2 [arm=6 arm=14 arm=15]]
                -- [context=2 [arm=6 arm=14 arm=30 31]]
                arms = {
                    {arm[1],3,arm[2]}
                }
            else
                for i,arm in next,ast.arms do
                    local axis
                    if i ~= 1 then
                        --7
                        axis = math.pow(2, (#ast.arms - i + 3)) - 2
                    else
                        axis = math.pow(2, (#ast.arms - i + 2)) - 1
                    end
                    print(axis)
                    arms[i] = {arm[1],axis,arm[2]}
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
                print("type_ast val lark")
                table.print(context)
                table.print(ast)
                return types.lark(context.t,ast.value.axis)
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
        end,
        ["change"] = function()
            local obj = table.copy(types.type_ast(context, ast.value))
            table.print(obj)
            -- TODO: check that no axises are within changed axises!
            -- change [a=1 c=4], a=[2 b=2], b=3 should fail!
            local changes = {}
            for _,patch in next,ast.changes do
                local ax = types.axis_of(obj, patch[1])
                expect(ax ~= nil, "change "..patch[1].." is nil")
                expect(ax[1] == "face", "change "..patch[1].." cant change arms")
                local ty = types.type_ast(context, patch[2])
                expect(ty ~= nil, "invalid type for "..patch[1])
                changes[ patch[1] ] = ty
                --obj = types.change(obj, patch[1], ty)
            end
            obj = types.change(obj, changes)
            table.print(obj)
            return obj
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
