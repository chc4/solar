# solar

>Over his palm hovered the shards that had once been his spectacles, 
>and though the enchantments on them were gone there was something a 
>great deal more dangerous to be glimpsed in them now. The last thing
>they’d witnessed was the Summer sun in the fullness of its glory,
>and that light was still alive in the glass. It might never leave.
>                                          - Practical Guide To Evil

gonna make a perfect programming language. gonna make it with imperfect code.

`design` has rambling about design and motivation, but tldr its immutable statically typed lua

# building

its lua you just run `lua src/main.lua`. that would be `lua5.1` but also lualvm uses 5.2 ABI so don't do that.

lualvm might give you trouble (because its bad). you gotta install [this dude's weird lua bindgen](https://github.com/gilzoide/inclua)
and also maybe remove LLVMCreateOprofileJITEventListener from /usr/include/llvm-c/ExecutionEngine.h. c'est la vie.

i wrote a parser in rust for this but its not hooked up. once that works you'll probably have to build that too.

# contributing

better if you didn't, really.
