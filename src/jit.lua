require "src/util"
require "src/types"

local ll = require "lualvm"
require "lib/lclass/class"

class "jit"

i32 = ll.Int32Type()
i32p = ll.Int32Type():Pointer(0)
i8p = ll.Int8Type():Pointer(0)
void = ll.VoidType()
voidp = ll.VoidType():Pointer(0)

function jit:jit()
    self:initialize()

    local main_ty = ll.FunctionType(i32, {}) -- what do i put here lmao
    self.main = self.M:AddFunction("main", main_ty)
    local entry = self.main:AppendBasicBlock "entry"
    self.B = self.C:Builder()
    self.B:PositionAtEnd(entry)

    self:add_atom()
    self:add_cell()

    self:add_intrinsics()
    print("jit construct")
end

function jit:dispose()
    print("llvm cleanup")
    self.M:Dispose()
end

function jit:initialize()
    ll.InitializeNativeTarget()
    ll.InitializeNativeAsmPrinter()
    ll.LinkInMCJIT()

    self.C = ll.GetGlobalContext()
    assert(self.C)
    self.M = self.C.Module("solar",self.C)
    assert(self.M)
    print("module init")
end

function jit:add_intrinsics()
    print("entered add_instrinsics")
    local puts_ty = ll.FunctionType (i32, { i8p })
    self.puts = self.M:AddFunction("puts", puts_ty)

    local printf_ty = ll.FunctionType (i32, { i8p }, 2, true)
    self.printf = self.M:AddFunction("printf", printf_ty)

    self.atom_format = self.B:GlobalStringPtr("%d\n", "main.atom_format")
    self.cell_format = self.B:GlobalStringPtr("[%d %d]\n", "main.cell_format")
    print("added intrinsics")
end

function jit:add_atom()
end

function jit:add_cell()
    self.cell = ll.LLVMStructCreateNamed(self.C,"struct.cell")
    ll.LLVMStructSetBody(self.cell, {i32p, i32p}, 2, false)
    print(self.cell)
    print("registered %struct.cell")
end

function jit:lark(axis)
    if axis == 1 then
        return self.context
    elseif axis % 2 == 0 then
        expect(self.context.t.tag,"cell")
        local left_ptr = self.B:ExtractValue(self.context, 0, "lark.left_ptr")
        local left = self.B:Load(left_ptr,"lark.left")
        return types.vase(self.context.t.left, left)
    else
        expect(self.context.t.tag,"cell")
        local right_ptr = self.B:ExtractValue(self.context, 1, "lark.right_ptr")
        local right = self.B:Load(right_ptr,"lark.right")
        return types.vase(self.context.t.right, right)
    end
end

function jit:repr(noun)
    local tab = {
        ["val"] = function()
            if type(noun.value) == "number" then
                local n = self.B:Malloc(i32,"atom."..tostring(noun.value))
                self.B:Store(ll.ConstInt(i32, noun.value), n)
                return types.vase(n,
                    types.atom { value = noun.value, aura = "d", example = noun.value })
            elseif noun.value.tag == "lark" then
                return self:lark(noun.value.axis)
            end
            error("emit types.val."..noun.value.tag)
        end,
        ["number"] = function()
            return self:repr(ast.val { value = noun.value })
            --return types.vase(ll.ConstInt(i32, noun.value),
            --    types.atom { value = noun.value, aura = "d", example = noun.value })
        end
    }
    if tab[noun.tag] then
        return tab[noun.tag]()
    else
        error("can't repr noun."..nount.tag)
    end
end

function jit:emit(ast)
    expect_type(ast, "ast", "ast")
    local tab = {
        ["val"] = function()
            local r = self:repr(ast)
            return r
        end,
        ["cons"] = function()
            local left = self:emit(ast.left)
            local right = self:emit(ast.right)
            print("made left and right")
            local c = self.B:Malloc(self.cell, "cell")

            local c_t = self.B:Load(c, "cell.temp")
            left = self.B:InsertValue(c_t, left.v, 0, "")
            right = self.B:InsertValue(left, right.v, 1, "")
            self.B:Store(right, c)
            return types.vase(
                c,
                types.cell {
                    left = types.type_ast(self.context, ast.left),
                    right = types.type_ast(self.context, ast.right),
                }
            )
        end,
        ["fetch"] = function()
            local axis = types.axis_of(self.context.t, ast.bind)
            table.print(axis)
            if axis[1] == "face" then
                return self:lark(axis[2])
            end
            error()
        end
    }
    if tab[ast.tag] then
        return tab[ast.tag]()
    else
        error("missing emit for "..ast.tag)
    end
end

function jit:print(noun)
    local tab = {
        ["atom"] = function()
            local atom = self.B:Load(noun.v, "atom")
            self.B:Call(self.printf, { self.M:AddAlias(i8p, self.atom_format, 'oi?'), atom }, '_')
        end,
        ["cell"] = function()
            table.print(noun)
            print(self.M)
            local c = self.B:Load(noun.v, "cell.temp")
            local left_ptr = self.B:ExtractValue(c, 0, "left_ptr")
            local left = self.B:Load(left_ptr,"left")
            local right_ptr = self.B:ExtractValue(c, 1, "right_ptr")
            local right = self.B:Load(right_ptr,"right")
            print("extracted left and right")
            self.B:Call(self.printf, { self.M:AddAlias(i8p, self.cell_format, 'oi?'), left, right}, '_')
        end,
        ["face"] = function()
            table.print(noun)
            local binding = self.B:GlobalStringPtr(noun.t.bind.."=", "binding."..noun.t.bind)
            self.B:Call(self.printf, { binding }, '_')
            self:print(noun.v)
        end
    }
    if tab[noun.t.tag] then
        return tab[noun.t.tag]()
    else
        error("can't print noun."..noun.t.tag)
    end
end

--[[
--  hash cores, emit structs that corrospond with this cores that have a vtable for their arms
--  calling core arms makes sure they line up and then calls function from vtable
--
--  do we want to emit sample shape testing prologue for arms? (add 1 [2 3]) should be compile time
--  asserted impossible, preferably, but if we have type system holes...?
--  if we don't, then have to only allow core sample modifications that nest within the established
--  core type - dont see why we would allow otherwise
--
--  - declare dumb atom/cell datatypes
--  - have jit.repr that constructs those datatypes
--  - ast.if emits branch and two blocks for either case
--  - translate "type system axis" to "llvm address" somehow for fetches
--  - add calls for core arms
--  - switch to bignums
--  - switch to reference counting
--]]

function jit:run(ast,context)
    if false then return end
    --local hello_str = self.B:GlobalStringPtr("Hello world!", 'main.str')
    --self.B:Call(self.puts, { self.M:AddAlias(i8p, hello_str, 'oi?') }, '_')

    self.context = types.vase(self:repr(context.v),context.t)
    ret = self:emit(ast)
    assert(ret)
    self:print(ret)

    self.B:Ret(ll.ConstInt(i32,0))

    self.M:PrintToFile("output.ll")


end

return jit
