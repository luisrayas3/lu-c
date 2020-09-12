local lpeg = require "lpeg"
local tprint = require "print_ast"
package.loaded["parser"] = nil  -- Force reload
local luc_program, luc = require "parser" ()

local function check(program, pattern)
  local match
  if pattern == nil then
    match = luc_program:match(program)
  else
    luc[1], prev_root = pattern * -1, luc[1]
    match = lpeg.P(luc):match(program)
    luc[1] = prev_root
  end
  if match == nil then
    print("Program did not compile")
    error(program)
  end
  print("")
  print(program)
  print("yielded")
  tprint(match)
end

print(luc.num_literal)
check("0", luc.num_literal)
check("01", luc.num_literal)

check("enum { A == 0; B == 1; }", luc.type_ction)
check("E :: enum { A == 0; B == 1; }", luc.decl_def)
check("struct { x: int; y: int; }", luc.type_ction)
check("P :: struct { x: int; y: int; }", luc.decl_def)

check [[ P :: struct { x: int; y: int; }; ]]
check [[ E :: enum { A == 0; B == 1; }; ]]

check("f: (x: int) => int", luc.decl)
check("(x: int) => int", luc.type_expr)
check("f: (x: int) => int where {}", luc.decl)

check [[ f: (x: int, y: int) => int; ]]

-- N.B. the former translates to a C-function, the latter to a pointer,
-- also `f` can be used recursively in the former whereas it has not
-- been declared for use in the definition in the second case.
check [[ f: (x: int, y: int) => int { return x * y; }; ]]
check [[ f == (x: int, y:int) => int { return x * y; }; ]]

check("x == a + b where { a == f(z); b == g(y); }", luc.decl_def)

check [[ f: (x: int, y: int, opts: Options) => int where {}; ]]
check [[ f: (x: int, y: int, opts: Options) => int where { O :: struct { v: bool; }; }; ]]

check("c / d", luc.add_term)
check [[ x == a + b * c // d; ]]
check [[ x == a or b and c | d & e // f; ]]
check [[ x == y + z where { y == z; }; ]]

check [[ F :: (T) :> F T; ]]
check("(T) :> F T", luc.type_func)
check("(T) :> F T", luc.type_literal)
check [[ F :: (T) :> F T where { T :: Class; }; ]]
check("F T (U, V)", luc.type_expr)
check [[ F :: (T, Uv) :> F T (U, V) where { T :: Class; }; ]]
