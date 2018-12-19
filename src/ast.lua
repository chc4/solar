ast = {}
local context = require "src/context"
local value = require "src/value"
-- i really wish lua had better lambda syntax
--
make_ast = enum("ast")
ast.let = make_ast("let", {"bind", "value", "rest"})
ast["if"] = make_ast("if", {"cond","if_true", "if_false"})
ast.core = function(...) return {tag = "core", arms = {...}} end
ast.val = make_ast("val", {"value"})
ast.fetch = make_ast("fetch",{"bind"})

return ast
