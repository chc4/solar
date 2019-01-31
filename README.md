# solar

>Over his palm hovered the shards that had once been his spectacles, and though the enchantments on them were gone there was something a great deal more dangerous to be glimpsed in them now. The last thing they’d witnessed was the Summer sun in the fullness of its glory, and that light was still alive in the glass. It might never leave.

>                                          - A Practical Guide To Evil

gonna make a perfect programming language. gonna make it with imperfect code.

`design` has rambling about design and motivation, but tldr its immutable statically typed lua

# progress

i started emitting llvm ir. it can print values and that's about it, unless this readme gets out of date in which case it can do more. run it like `lua src/main.lua && lli output.ll`.

todo is basically "add flow control back in, figure out how the hell cores will work via llvm, add mutations".

# building

this uses lualvm and is probably the only program in the history of the world to do so. you gotta install [inclua](https://github.com/gilzoide/inclua) which is some random dude's lua bindgen and then go to `lib/lualvm` and run `export CXX=clang++ && export CC=clang && mkdir build && cd build && cmake .. && make && make install`. and also maybe remove LLVMCreateOprofileJITEventListener from /usr/include/llvm-c/ExecutionEngine.h. c'est la vie.

i wrote a parser in rust for this but its not hooked up. once that works you'll probably have to build that too.

# contributing

better if you didn't, really.
