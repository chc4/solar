ast = {}
local context = require "src/context"
local value = require "src/value"
-- i really wish lua had better lambda syntax
--
make_ast = enum("ast")
ast.let = make_ast("let", {"bind", "value", "rest"})
ast.face = make_ast("face", {"bind","value"})
ast["if"] = make_ast("if", {"cond","if_true", "if_false"})
ast.core = make_ast("core",{"arms"}) -- arms are {"name", ast}
ast.val = make_ast("val", {"value"})
ast.fetch = make_ast("fetch",{"bind"})
ast.cons = make_ast("cons",{"left","right"})
ast["in"] = make_ast("in",{"context","code"})
ast["bump"] = make_ast("bump",{"atom"})
ast["change"] = make_ast("change", {"value", "changes"}) -- changes are {"binding", ast}
ast["gate"] = make_ast("gate", {"arg", "body"})
ast["call"] = make_ast("call", {"value", "args"})

function open_node(tag, members)
    return function(node)
        expect_type(node,"node","ast")
        expect(node.tag == tag,"expect `"..tag.."` got `"..node.tag.."`")
        local members_set = {}
        for _,v in next,members do
            members_set[v] = true
        end
        local ret = {}
        for k,v in next,node do
            -- if it's a member to open, then open
            if members_set[k] then
                ret[k] = ast.open(v)
            else
                ret[k] = v
            end
        end
        expect(ret.tag == tag)
        return ret
    end
end

function ast.lark(axis)
    return ast.val { value = value.lark { axis = axis } }
end


function ast.open(node)
    expect(node ~= nil, "node is nil")
    table.print(node)
    expect_type(node,"node","ast")
    local tab = {
        ["let"] = function()
            -- `=/  a  1  .` becomes `=>  [a=1 .]  .`
            return ast["in"] {
                context = ast.cons {
                    left = ast.face { bind = node.bind, value = ast.open(node.value) },
                    right = ast.lark(1)
                },
                code = ast.open(node.rest)
            }
        end,
        ["cons"] = open_node("cons",{"left","right"}),
        ["in"] = open_node("in",{"context","code"}),
        ["val"] = open_node("val",{}),
        ["bump"] = open_node("bump",{"atom"}),
        ["fetch"] = open_node("fetch",{}),
        ["face"] = open_node("face",{"value"}),
        ["core"] = function()
            for i,arm in next,node.arms do
                node.arms[i] = {arm[1], ast.open(arm[2])}
            end
            return node
        end,
        ["if"] = open_node("if",{"cond","if_true","if_false"}),
        ["change"] = function()
            local changes = {}
            for _,v in next,node.changes do
                table.insert(changes, {v[1], ast.open(v[2])})
            end
            return ast.change {
                value = ast.open(node.value),
                changes = changes,
            }
        end,
        ["call"] = function()
            -- we dont have to check that function calls typecheck here:
            -- `changes` does core variance sample checking in general, not
            -- specific to `call`.
            --
            -- `(f 1 2)` becomes --`=+  f(+< [1 2])  $:-`
            -- `:*  p  q  [r]  ==`  becomes  `=+  q  %=(p:- r:+)`
            local relative_changes = nil
            for _,change in next,node.args do
                expect_type(change, "change", "ast")
                -- we have the function we're changing on the top of the context
                -- and so need to change all the function arguments to use the "regular"
                -- context instead. additionally, (f 1 2 3) is sugar for (f [1 [2 3]]).
                change = ast["in"] { code = change, context = ast.lark(3) }
                if relative_changes == nil then
                    relative_changes = change
                else
                    relative_changes = ast.cons { left = change, right = relative_changes }
                end
            end
            return ast.open(ast["in"] {
                -- eval arm
                code = ast.fetch { bind = "$" },
                context =
                ast["in"] {
                    -- put copy of function on top of context, to change
                    context = ast.cons {
                        left = node.value,
                        right = ast.lark(1)
                    },
                    -- change +< in - to out arguments
                    code = ast.change {
                        value = ast.lark(2),
                        changes = {{4, relative_changes}}
                    }
                }
            })
        end,
        ["gate"] = function()
            return ast["in"] {
                context = ast.cons {
                    left = ast.open(node.arg),
                    right = ast.val { value = value.lark { axis = 1 } }
                },
                code = ast.core {
                    arms = {{"$", ast.open(node.body)}}
                }
            }
        end
    }
    if not tab[node.tag] then
        error("cant open `"..node.tag.."`")
    end
    local at = tab[node.tag](node)
    if table.equal(node, at) then
        return at
    else
        --return ast.open(at)
        return at
    end
end

return ast
