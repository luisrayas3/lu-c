local lpeg = require "lpeg"
local tprint = require "print_ast"

-- Under test
local luc, luc_grammar, match_stats = require "parser" ()

local print_all = false

describe("the luc grammar", function()

  local function check_result(subject, match)
    -- TODO: How to get busted to print furthest_match if this fails?
    assert.message("failed to parse `" .. subject .. "`").is_not_nil(match)
    if match_stats.furthest_match_subject then
      assert.equal(subject, match_stats.furthest_match_subject)
    end

    if print_all then
      print("")
      print(subject)
      print("----")
      print("yielded:")
      tprint(match)
      print("")
      print("longest match: ")
      print(match_stats.furthest_match, match_stats.furthest_match_subject)
      print("")
    end
    match_stats:clear()
  end

  local function check(term, pattern)
    -- TODO: Use some busted feature to reload `luc`
    luc_grammar[1], prev_root = pattern * -1, luc_grammar[1]
    local match = lpeg.P(luc_grammar):match(term)
    luc_grammar[1] = prev_root
    check_result(term, match)
  end

  local function check_prog(program)
    check_result(program, luc:match(program))
  end

  it("parses integrals", function()
    check("0", luc_grammar.num_literal)
    check("01", luc_grammar.num_literal)
  end)

  it("parses other things too", function()
    check("enum { A == 0; B == 1; }", luc_grammar.type_ction)
    check("E :: enum { A == 0; B == 1; }", luc_grammar.decl_def)
    check("struct { x: int; y: int; }", luc_grammar.type_ction)
    check("P :: struct { x: int; y: int; }", luc_grammar.decl_def)

    check_prog [[ P :: struct { x: int; y: int; }; ]]
    check_prog [[ E :: enum { A == 0; B == 1; }; ]]

    check("f: (x: int) => int", luc_grammar.decl)
    check("(x: int) => int", luc_grammar.type_expr)
    check("f: (x: int) => int where {}", luc_grammar.decl)

    check_prog [[ f: (x: int, y: int) => int; ]]

    -- N.B. the former translates to a C-function, the latter to a pointer,
    -- also `f` can be used recursively in the former whereas it has not
    -- been declared for use in the definition in the second case.
    check_prog [[ f: (x: int, y: int) => int { return x * y; }; ]]
    check_prog [[ f == (x: int, y:int) => int { return x * y; }; ]]

    check("x == a + b where { a == f(z); b == g(y); }", luc_grammar.decl_def)

    check_prog [[ f: (x: int, y: int, opts: Options) => int where {}; ]]
    check_prog [[ f: (x: int, y: int, opts: Options) => int where { O :: struct { v: bool; }; }; ]]

    check("c / d", luc_grammar.add_term)
    check_prog [[ x == a + b * c // d; ]]
    check_prog [[ x == a or b and c | d & e // f; ]]
    check_prog [[ x == y + z where { y == z; }; ]]

    check_prog [[ F :: (T) :> F T; ]]
    check("(T) :> F T", luc_grammar.type_func)
    check("(T) :> F T", luc_grammar.type_literal)
    check_prog [[ F :: (T) :> F T where { T :: Class; }; ]]
    check("F T (U, V)", luc_grammar.type_expr)
    check_prog [[ F :: (T, Uv) :> F T (U, V) where { T :: Class; }; ]]
  end)
end)
