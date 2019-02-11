require "src/util"
local ast = require "src/ast"
local context = require "src/context"
local parser = require "src/parser"
local types = require "src/types"
local rt = require "src/runtime"
local jit = require "src/jit"

function test_atom()
    return ast.val { value = 8 }
end

function test_nouns()
    return ast.cons {
        left = ast.val { value = 9 },
        right = ast.val { value = 10 }
    }
end

function test_nested()
    return ast.cons {
        left = ast.val { value = 1 },
        right = ast.cons {
            left = ast.val { value = 2 },
            right = ast.val { value = 3 }
        }
    }
end

function test_fetch()
    return ast.fetch { bind = "solar" }
end

function test_lark()
    return ast.val { value = value.lark { axis = 1 } }
end

function test_bump()
    return ast.bump { atom = ast.val { value = 1 } }
end

function test_if()
    return ast["if"] {
        cond = ast.val { value = 1 },
        if_true = ast.val { value = 2 },
        if_false = ast.val { value = 3 }
    }
end

function test_fork_context()
    return ast["in"] {
        context = ast["if"] {
            cond = ast.val { value = 1 },
            if_true = ast.face { bind = "a", value = ast.val { value = 2 } },
            if_false = ast.face { bind = "a", value = ast.val { value = 3 } },
        },
        code = ast.fetch { bind = "a" }
    }
end

function test_core()
    return ast.core {
        arms = {
            {"a", ast.val { value = 1 }}
        }
    }
end

function test_arm()
    return ast["in"] {
        context = ast.core {
            arms = {
                {"a", ast.val { value = 2 }},
                {"b", ast.val { value = 3 }}
            }
        },
       code = ast.fetch { bind = "a" }
   }
end

function test_core_context()
    return ast.let {
        bind = "foo",
        value = ast.val { value = 10 },
        rest = ast["in"] {
            context = ast.core {
                arms = {
                    {"a", ast.fetch { bind = "foo" }},
                    {"b", ast.fetch { bind = "a" }},
                    {"c", ast.fetch { bind = "b" }}
                }
            },
            code = ast.fetch { bind = "b" }
        }
    }
end

function test_change()
    -- TODO: change? hoon has `change` take a binding and fetches+updates at once.
    -- this would let you do `change [b=1 .], b 1` but would need two-pass: initial
    -- memcpy of root, then update changed nodes.
    -- might change "bindings" to be ast.vals? this doesnt let you do `change a, . 2`
    return ast.let {
        bind = "a",
        value = ast.cons {
            left = ast.face { bind = "b", value = ast.val { value = 1 } },
            right = ast.face { bind = "c", value = ast.val { value = 2 } },
        },
        rest = ast.cons {
            left = ast.fetch { bind = "a" },
            right = ast.change { value = ast.fetch { bind = "a" }, changes = {{"b", ast.val { value = 3 }}} },
        }
    }
end

function testcase_one()
    return ast.let {
        bind = "a",
        value = ast.val { value = 1 },
        rest = ast.fetch { bind = "a" }
    }
end

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

function testcase_three()
    return ast["in"] {
        context = ast.core {
            arms = {
                {"a", ast.val { value = 1 }},
                {"b", ast.val { value = 2 }},
                {"c", ast.val { value = 3 }},
                {"d", ast.cons {
                    left = ast.fetch { bind = "a" },
                    right = ast.cons {
                        left = ast.fetch { bind = "b" },
                        right = ast.fetch { bind = "c" }
                    }
                }}
            }
        },
        code = ast.fetch { bind = "d" }
    }
end

local input = io.open("test.sol","r"):read("*a")

local tree = test_change()
tree = ast.open(tree)

local context_vase = types.vase(context.new(), types.face { bind = "solar", value = types.atom {value=0, aura = "z", example = 0} })
local ty = types.type_ast(context_vase,tree)
print("RET TYPE")
table.print(ty)

local use_llvm = true
if not use_llvm then
    local eval = rt.eval(context_vase, tree)
    table.print(eval)
else
    local cont = jit()
    local m = cont:run(tree, context_vase)
    cont:dispose()
end
