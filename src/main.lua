require "src/util"
local ast = require "src/ast"
local context = require "src/context"
local parser = require "src/parser"
local types = require "src/types"
local rt = require "src/runtime"

local input = io.open("test.sol","r"):read("*a")

local tree = ast.let("a", ast["if"] (
        ast.val(2),
        ast.val(2),
        ast.val(3)
    ),
    ast.fetch("a")
)

local context_vase = types.vase(context.new(),types.void())
local ty = types.type_ast(context_vase,tree)
print("RET TYPE")
table.print(ty)

local eval = rt.eval(context_vase, tree)
table.print(eval)
