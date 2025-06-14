# Interpreter-zig

Continuation from the [interpreter-rust](https://github.com/tushyagupta81/interpreter-rust)\
The rust borrow checker made the way of making the interpreter feel like hell
> I will still be following [Crafting Interpreters](https://craftinginterpreters.com/) ~~hopeful~~ on my own this time

## Working model

Check out the working model at [https://tushyagupta81.github.io/interpreter-zig](https://tushyagupta81.github.io/interpreter-zig/)\
The backend might take 1-2 min to turn back on

## Current progress
- [x] How to read a file
- [x] Using the gpa allocator
- [x] REPL mode working
- [x] Tokens
- [x] Scanner
    - [x] Challenge
        - [x] Multiline comments
- [x] Parser
    - [x] Temp hack - Using arena allocator to help memory release
    - [ ] Challenge
        - [ ] Implement Comma operator from C and C++
        - [ ] Ternary operator
        - [x] Detect a Binary operation with a missing left hand operator
- [x] Interpreter
    - [ ] Challenge
        - [ ] compare numbers and string(Don't know what it should really do?)
        - [x] and numbers to string
        - [x] divide by 0 check
- [x] Statements
    - [x] Parts
        - [x] Exprs
        - [x] print
        - [x] variables(without scope)
        - [x] variables(with scope)
        - [x] conditionals
        - [x] and or operators
        - [x] loops
    - [ ] Challenge
        - [ ] REPL to auto detect a expr vs a statement and execute them accordingly
        - [ ] Give runtime error for variable that are declared but not initialized
        - [ ] branching statements?
        - [ ] break statement
- [x] Functions
    - [x] Return
    - [x] Local functions(~~can't really figure it out~~ moved all environments to the heap)
    - [ ] Challenge
        - [ ] Checking number of args at runtime hits preformance
        - [ ] Anonymous functions
- [x] Resolver
    - [x] Coping the env at the time of creation of the function
    - [x] For the one from the book to work need to make it so that I can HashMap Expr itself and not there pointers
        - Got the tedious HashMap defination from [tusharhero](https://github.com/tusharhero/zlox/tree/master)
        - [x] Also needed a globals list(pointed the init env 2 times)
    - [x] Resolve time errors
    - [ ] Challenge
        - [ ] Extend resolver to detect unused local variables
        - [ ] Look up variable using a index array instead of a hashmap
            - By sending the index and distance from the resolver
- [ ] ...

## Pitfalls to fix

1. interpreter.zig
    - evaluvate_binary -> string concat size limit of 4096
2. token.zig
    - LiteralValue
        - to_string methods size limit of 4096
3. enironment.zig
    - get -> string concat size limit of 4096
