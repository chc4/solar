require "src/util"
require "src/types"

local ll = require "lualvm"
require "lib/lclass/class"

class "jit"

i1 = ll.Int1Type()
i8 = ll.Int8Type()
i32 = ll.Int32Type()
i32p = ll.Int32Type():Pointer(0)
i8p = ll.Int8Type():Pointer(0)
void = ll.VoidType()
voidp = ll.VoidType():Pointer(0)

zero = ll.ConstInt(i32, 0)
one = ll.ConstInt(i32, 1)

function jit:jit()
    self:initialize()

    local main_ty = ll.FunctionType(i32, {}) -- what do i put here lmao
    self.func = self.M:AddFunction("main", main_ty)
    local entry = self.func:AppendBasicBlock "entry"
    self.block = entry
    self.B = self.C:Builder()
    self.B:PositionAtEnd(entry)

    self:add_noun()
    self.cores = {}

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

    self.atom_format = self.B:GlobalStringPtr("%d", "main.atom_format")
    self.cell_format = {}
    for i,v in next,{"["," ","]"} do
        table.insert(self.cell_format, self.B:GlobalStringPtr(v, "main.cell_format."..i))
    end
    self.newline = self.B:GlobalStringPtr("\n", "main.newline")
    print("added intrinsics")
end

function jit:add_noun()
    self.noun_ty = ll.LLVMStructCreateNamed(self.C, "struct.noun")
    print("registered %struct.noun")

    self.atom_ty = ll.LLVMStructCreateNamed(self.C, "struct.atom")
    ll.LLVMStructSetBody(self.atom_ty, { i8, i32 }, 2, false)

    self.cell_ty = ll.LLVMStructCreateNamed(self.C,"struct.cell")
    ll.LLVMStructSetBody(self.cell_ty, { i8, self.noun_ty:Pointer(0), self.noun_ty:Pointer(0)}, 3, false)
    print(self.cell_ty)
    print("registered %struct.cell")

    self.core_ty = ll.LLVMStructCreateNamed(self.C,"struct.core")
    -- tag, context, vtable
    ll.LLVMStructSetBody(self.core_ty, { i8, self.noun_ty:Pointer(0), i8p }, 3, false)

    -- 0 == atom, 1 == cell, 2 == core
    -- does this break with 64bit?
    ll.LLVMStructSetBody(self.noun_ty, { i8, i8p, i8p }, 1, false)
    print(self.noun_ty)
end

function jit:make_noun(variant,noun,noun2)
    expect(type(variable),"string")
    if variant == "atom" or (variant == "dynamic" and noun:TypeOf():GetStructName() == "") then
        -- is an atom
        local n_p = self.B:Malloc(self.noun_ty, "noun.atom")
        local n = self.B:InBoundsGEP(n_p, { zero, zero }, 2, "noun.atom.tag")
        self.B:Store(ll.ConstInt(i8, 0), n)
        print("stored noun.atom tag")
        local atom = self.B:BitCast(n_p, self.atom_ty:Pointer(0), "noun.atom.cast")
        local val = self.B:InBoundsGEP(atom, { zero, one }, 2, "noun.atom.value")
        self.B:Store(noun, val)
        return n_p
    else
        local n_p = self.B:Malloc(self.noun_ty, "noun.cell")
        local n = self.B:InBoundsGEP(n_p, { zero, zero }, 2, "noun.cell.tag")
        self.B:Store(ll.ConstInt(i8, 1), n)
        print("stored noun.cell tag")
        local cell = self.B:BitCast(n_p, self.cell_ty:Pointer(0), "noun.cell.cast")
        local val = self.B:InBoundsGEP(cell, { zero, one }, 2, "noun.cell.left")
        self.B:Store(noun, val)
        local val = self.B:InBoundsGEP(cell, { zero, ll.ConstInt(i32, 2) }, 2, "noun.cell.right")
        self.B:Store(noun2, val)
        return n_p
    end
end

function jit:make_core(coil)
    print("making core")
    print(core_ty)
    local n_p = self.B:Malloc(self.noun_ty, "noun.core")
    local n = self.B:InBoundsGEP(n_p, { zero, zero }, 2, "noun.core.tag")
    self.B:Store(ll.ConstInt(i8, 2), n)
    print("stored noun.core tag")
    local core = self.B:BitCast(n_p, self.core_ty:Pointer(0), "noun.core.cast")
    local val = self.B:InBoundsGEP(core, { zero, one }, 2, "noun.core.context")
    -- TODO: reference counting
    print(self.context.v,val)
    table.print(self.context)
    print(self.B:Store(self.context.v, val))
    local val = self.B:InBoundsGEP(core, { zero, ll.ConstInt(i32, 2) }, 2, "noun.core.coil")
    local coil_cast = self.B:BitCast(coil, i8p, "noun.core.coil.cast")
    self.B:Store(coil_cast, val)
    return n_p
end

function jit:as_atom(noun)
    -- TODO: emit assert for tag
    table.print(noun)
    local atom_p = self.B:BitCast(noun, self.atom_ty:Pointer(0), "as_atom.atomptr")
    table.print(atom_p)
    local atom = self.B:Load(atom_p, "as_atom.atom")
    local val = self.B:ExtractValue(atom, 1, "as_atom.value")
    return val
end

function jit:as_cell(noun)
    -- TODO: assert
    table.print(noun)
    local cell_p = self.B:BitCast(noun, self.cell_ty:Pointer(0), "as_cell.cellptr")
    local cell = self.B:Load(cell_p, "as_cell.cell")
    local left = self.B:ExtractValue(cell, 1, "as_cell.left")
    local right = self.B:ExtractValue(cell, 2, "as_cell.right")
    return left, right
end

function jit:as_core(noun)
    table.print(noun)
    local core_p = self.B:BitCast(noun, self.core_ty:Pointer(0), "as_core.coreptr")
    local core = self.B:Load(core_p, "as_core.core")
    local context = self.B:ExtractValue(core, 1, "as_core.context")
    local coil = self.B:ExtractValue(core, 2, "as_core.coil")
    return context, coil
end


function jit:lark(context, axis)
    if axis == 1 then
        table.print(context)
        return context
    elseif axis % 2 == 0 then
        print("go left")
        table.print(context)
        local left, right = self:as_cell(context)
        print("went left")
        return self:lark(left, axis / 2)
    else
        print("go right")
        local left, right = self:as_cell(context)
        print("went right")
        return self:lark(right, (axis - 1) / 2)
    end
end

function jit:insert_block(name)
    local block = self.func:AppendBasicBlock(name)
    self.B:PositionAtEnd(block)
    self.block = block
    return block
end

function jit:repr(noun)
    local tab = {
        ["val"] = function()
            if type(noun.value) == "number" then
                local n = self
                local n = self:make_noun("atom",ll.ConstInt(i32, noun.value))
                print(n)
                assert(n)
                return n
            elseif noun.value.tag == "lark" then
                return self:lark(self.context.v, noun.value.axis)
            end
            error("emit types.val."..noun.value.tag)
        end,
        ["number"] = function()
            return self:repr(ast.val { value = noun.value })
        end
    }
    if tab[noun.tag] then
        return tab[noun.tag]()
    else
        error("can't repr noun."..nount.tag)
    end
end

function jit:llvm_core(core)
    local name = "<"
    for i,v in next,core.arms do
        name = name .. v[1]
    end
    name = name ..">"
    print(name)
    if self.cores[name] then
        print("core exists for "..name)
        return self.cores[name]
    end
    print("building core "..name)

    -- we have to construct the vtable with stubs first, so that when generating the arms
    -- the function calls resolve. messy.

    local coil_ty = {}
    local coil = {}
    for _,v in next,core.arms do
        print("initializing arm "..v[1])
        local arm_ty = ll.FunctionType(self.noun_ty:Pointer(0), { self.noun_ty:Pointer(0) }, 1, false)
        table.insert(coil_ty, arm_ty:Pointer(0))
        table.insert(coil, self.M:AddFunction("core."..name.."."..v[1], arm_ty))
    end

    local coil_struct_ty = self.C:StructType(coil_ty, #coil_ty, false)
    self.cores[name] = self.M:AddGlobal(coil_struct_ty, "struct.core."..name)
    local coil_struct = self.C:ConstStruct(coil, #coil, false)
    ll.LLVMSetInitializer(self.cores[name], coil_struct)

    for i,v in next,core.arms do
        print("finalizing arm "..core.arms[i][1])
        self:build_arm(coil[i], core.arms[i][2], core)
    end

    return self.cores[name]
end

function jit:build_arm(arm_func, arm_body, core)
    print("func",arm_func)
    local func = self.func
    local block = self.block

    self.func = arm_func
    local body = self:insert_block("entry")
    local old_context = self.context
    self.context = types.vase(self.func:GetParam(0), types.type_ast(self.context, core))
    local last = self:emit(arm_body)
    self.B:Ret(last)

    self.context = old_context
    self.func = func
    self.block = block
    self.B:PositionAtEnd(block)
end

function jit:emit(ast)
    expect_type(ast, "ast", "ast")
    local tab = {
        ["val"] = function()
            local r = self:repr(ast)
            return r
        end,
        ["cons"] = function()
            table.print(ast)
            local left = self:emit(ast.left)
            local right = self:emit(ast.right)
            print("made left and right")
            local c = self:make_noun("cell",left,right)

            return c
        end,
        ["fetch"] = function()
            print("the hell")
            table.print(ast)
            local axis = types.axis_of(self.context.t, ast.bind)
            table.print(self.context)
            if axis[1] == "face" then
                -- why does axis_of give me a type with the face still on?
                return self:lark(self.context.v, axis[2]).v
            else
                local core_p = self:lark(self.context.v, axis[4])
                print("CORE",core_p)
                local name = "<"
                for i,v in next,axis[5].arms do
                    name = name..v[1]
                end
                name = name..">"
                print(name)
                local coil_ty = self.cores[name]
                assert(coil_ty)
                local context, coil = self:as_core(core_p)
                local coil_cast = self.B:BitCast(coil, coil_ty:TypeOf(), "fetch.coil.cast")
                local slot = nil
                for i,v in next,axis[5].arms do
                    if v[1] == ast.bind then
                        slot = i - 1
                        break
                    end
                end
                assert(slot)
                local vtable = self.B:Load(coil_cast, "fetch.coil")
                print(vtable)
                local func_ptr = self.B:ExtractValue(vtable, slot, "fetch.coil.fetch")
                print("made func_ptr")
                --self.context = types.vase(core_p, axis[5])
                local ret = self.B:Call(func_ptr, { core_p }, 1, "fetch.coil.call")
                print("made call!!!!")
                return ret
            end
            error()
        end,
        ["in"] = function()
            local c = self:emit(ast.context)
            self.context = types.vase(c, types.type_ast(self.context, ast.context))
            return self:emit(ast.code)
        end,
        ["face"] = function()
            table.print(ast)
            return self:emit(ast.value)
        end,
        ["bump"] = function()
            print("emit bump")
            -- malloc new noun, load old, increment, store in new
            expect(ast.atom.tag,"atom") -- XX: check nest instead
            local noun = self:emit(ast.atom)
            print("emitted noun")
            table.print(noun)
            local bump_temp = noun
            print("bump_temp",bump_temp)
            --[[local bump = self.B:Add(bump_temp, ll.ConstInt(i32, 1), "bump")
            local bumped = self.B:Malloc(i32, "atom.bumped")
            self.B:Store(bump, bumped)]]
            print("emitted bump")
            return bump_temp
        end,
        ["if"] = function()
            print("emit if")
            local cond = self:emit(ast.cond)
            assert(cond)
            print("emitted cond")
            local cond_temp = self:as_atom(cond)
            local cond_comp = self.B:ICmp(ll.IntEQ, cond_temp, ll.ConstInt(i32, 0), "if.cond.comp")
            print("emitted comparison")

            -- TODO: switch this to use "current function" instead of main
            -- condbr doesn't have a value!!! emit alloca for return value and `end` block with continuation
            -- after true_block/false_block br to `end`, return the value
            local main_block = self.block
            -- how do you read/write unions???
            local ret = self.B:Alloca(self.noun_ty:Pointer(0), "if.ret")
            local end_block = self:insert_block "end_block"
            local ret_val = self.B:Load(ret, "ret.value")

            local true_block = self:insert_block "true_block"
            local if_true = self:emit(ast.if_true)
            assert(if_true)
            self.B:Store(if_true, ret)
            self.B:Br(end_block)
            print("emitted if_true")

            local false_block = self:insert_block "false_block"
            local if_false = self:emit(ast.if_false)
            assert(if_false)
            self.B:Store(if_false, ret)
            self.B:Br(end_block)
            print("emitted if_false")

            self.block = main_block
            self.B:PositionAtEnd(main_block)
            local br = self.B:CondBr(cond_comp, true_block, false_block, "if.branch")
            print("emitted branch")

            self.block = end_block
            self.B:PositionAtEnd(end_block)
            return ret_val
        end,
        ["core"] = function()
            -- TODO: hashing cores for uniqueness
            local core_ty = self:llvm_core(ast)
            assert(core_ty)
            local core = self:make_core(core_ty)
            return core
        end
    }
    if tab[ast.tag] then
        return tab[ast.tag]()
    else
        error("missing emit for "..ast.tag)
    end
end

function jit:print(noun,noun_ty)
    tab = {
        ["atom"] = function()
            print("print atom")
            table.print(noun)
            local atom = self:as_atom(noun)
            print("print as_atom")
            table.print(atom)
            self.B:Call(self.printf, { self.M:AddAlias(i8p, self.atom_format, 'atom_format'), atom }, '_')
        end,
        ["cell"] = function()
            table.print(noun)
            --[[local c = self.B:Load(noun.v, "cell.temp")
            local left_ptr = self.B:ExtractValue(c, 1, "left_ptr")
            local left = self.B:Load(left_ptr,"left")
            local right_ptr = self.B:ExtractValue(c, 2, "right_ptr")
            local right = self.B:Load(right_ptr,"right")
            ]]
            local left, right = self:as_cell(noun)
            function emit_print(str)
                self.B:Call(self.printf, { str }, '_')
            end
            local s = self.cell_format
            emit_print(s[1])
            self:print(left, noun_ty.left)
            emit_print(s[2])
            self:print(right, noun_ty.right)
            emit_print(s[3])
            print("extracted left and right")
        end,
        ["face"] = function()
            print("print face")
            table.print(noun)
            local binding = self.B:GlobalStringPtr(noun.t.bind.."=", "binding."..noun.t.bind)
            self.B:Call(self.printf, { binding }, '_')
            self:print(noun, noun_ty.value)
        end,
        ["fork"] = function()
            -- fuq. need to emit runtime test for nest for this.
            table.print(noun)
            local ty = noun:TypeOf()
            print(ty, ty:GetStructName(), "a")
            --if ty:GetStructName() == "" then
                -- HORRIBLE HACK
                noun_ty = types.atom { value = 0, aura = "", example = 0 }
                return tab["atom"]()
            --end
            --error()
        end,
        ["core"] = function()
            table.print(noun)
            local core_str = "<"
            for i,v in next,noun.t.arms do
                core_str = core_str..i
            end
            core_str = core_str..">"
            local core_fmt = self.B:GlobalStringPtr("core."..core_str, "format."..core_str)
            self.B:Call(self.printf, { core_fmt }, '_')
        end
    }
    if not noun_ty or not noun_ty.tag then
        table.print(noun)
        error("attempted to print nil value")
    end
    if tab[noun_ty.tag] then
        return tab[noun_ty.tag]()
    else
        table.print(noun)
        error("can't print noun."..noun_ty.tag)
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

    self.context = types.vase(self:repr(context.v), context.t)
    table.print(self.context)
    ret = self:emit(ast)
    assert(ret)
    self:print(ret, types.type_ast(self.context, ast))
    self.B:Call(self.printf, { self.newline }, '_')
    self.B:Ret(ll.ConstInt(i32,0))

    self.M:PrintToFile("output.ll")


end

return jit
