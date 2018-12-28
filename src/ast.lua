ast = {}
local context = require "src/context"
local value = require "src/value"
-- i really wish lua had better lambda syntax
--
make_ast = enum("ast")
ast.let = make_ast("let", {"bind", "value", "rest"})
ast.face = make_ast("face", {"bind","value"})
ast["if"] = make_ast("if", {"cond","if_true", "if_false"})
ast.core = function(...) return {tag = "core", arms = {...}} end
ast.val = make_ast("val", {"value"})
ast.fetch = make_ast("fetch",{"bind"})
ast.cons = make_ast("cons",{"left","right"})
ast["in"] = make_ast("in",{"context","code"})

function ast.open(node)
    assert(node.type == "ast")
    local tab = {
        ["let"] = function()
            -- `=/  a  1  .` becomes `=>  [a=1 .]  .`
            return ast["in"] {
                context = ast.cons {
                    left = ast.face { bind = node.bind, value = node.value },
                    right = ast.val { value = value.lark { axis = 1 } }
                },
                code = node.rest
            }
        end
    }
    if not tab[node.tag] then
        return node
    end
    return ast.open(tab[node.tag]())
end

return ast
