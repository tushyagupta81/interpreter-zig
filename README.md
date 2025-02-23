# Interpreter-zig

Continuation from the [interpreter-rust](https://github.com/tushyagupta81/interpreter-rust)\
The rust borrow checker made the way of making the interpreter feel like hell
> I will still be following [Crafting Interpreters](https://craftinginterpreters.com/) hopeful on my own this time

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
- [ ] Statements
    - [ ] Parts
        - [x] Exprs
        - [x] print
        - [x] variables(without scope)
        - [x] variables(with scope)
        - [x] conditionals
        - [x] and or operators
        - [x] loops
        - [ ] ...
    - [ ] Challenge
        - [ ] REPL to auto detect a expr vs a statement and execute them accordingly
        - [ ] Give runtime error for variable that are declared but not initialized
        - [ ] branching statements?
        - [ ] break statement
- [ ] Resolver
- [ ] ...

## Pitfalls to fix

1. interpreter.zig
    - [ ] evaluvate_binary -> string concat size limit of 4096

2. token.zig
    - LiteralValue
        - [ ] to_string methods size limit of 4096

3. enironment.zig
    - [ ] get -> string concat size limit of 4096

## Shifted to zig

Before doing the interpreter in rust I was hesitant to chose which one and in the end choose rust\
I enjoy rust but i after doing some complex things in it I felt like I was being held back\
Most probabaly this is a skill issue and my way of thinking in OOP's mentality\

###### P.S. I am really enjoying it rn :)
