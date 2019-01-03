require "src/util"
local ast = require "src/ast"
local context = require "src/context"
local parser = require "src/parser"
local types = require "src/types"
local rt = require "src/runtime"

function testcase_two()
    return ast.let {
        bind = "a",
        value = ast.bump { atom = ast["if"] {
            cond = ast.val {value=1},
            if_true = ast.val {value=2},
            if_false = ast.val {value=3}
        }},
        rest = ast.bump { atom = ast.face { bind = "c", value = ast.fetch {bind="a"} } }
    }
end

function testcase_one()
    return ast.let {
        bind = "a",
        value = ast.val { value = 1 },
        rest = ast.fetch { bind = "a" }
    }
end

local input = io.open("test.sol","r"):read("*a")

local tree = testcase_two()
tree = ast.open(tree)

local context_vase = types.vase(context.new(),types.atom {value=0, aura = "z", example = 0})
local ty = types.type_ast(context_vase,tree)
print("RET TYPE")
table.print(ty)

local eval = rt.eval(context_vase, tree)
table.print(eval)
