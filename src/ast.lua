ast = {}
local context = require "src/context"
local value = require "src/value"
-- i really wish lua had better lambda syntax
--
make_ast = enum("ast")
ast.let = make_ast("let", {"bind", "value", "rest"})
ast.face = make_ast("face", {"bind","value"})
ast["if"] = make_ast("if", {"cond","if_true", "if_false"})
ast.core = make_ast("core",{"arms"}) -- arms are {"name",twig}
ast.val = make_ast("val", {"value"})
ast.fetch = make_ast("fetch",{"bind"})
ast.cons = make_ast("cons",{"left","right"})
ast["in"] = make_ast("in",{"context","code"})
ast["bump"] = make_ast("bump",{"atom"})

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
        return ret
    end
end


function ast.open(node)
    expect_type(node,"node","ast")
    table.print(node)
    local tab = {
        ["let"] = function()
            -- `=/  a  1  .` becomes `=>  [a=1 .]  .`
            return ast["in"] {
                context = ast.cons {
                    left = ast.face { bind = node.bind, value = ast.open(node.value) },
                    right = ast.val { value = value.lark { axis = 1 } }
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
                node.arms[i] = {arm[1],ast.open(arm[2])}
            end
            return node
        end,
        ["if"] = open_node("if",{"cond","if_true","if_false"})
    }
    if not tab[node.tag] then
        error("cant open `"..node.tag.."`")
    end
    local at = tab[node.tag](node)
    if table.equal(ast, at) then
        return at
    else
        --return ast.open(at)
        return at
    end
end

return ast
