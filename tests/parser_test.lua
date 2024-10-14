local lpeg = require "lpeg"
local tprint = require "print_ast"

-- Under test
local luc, luc_grammar, match_stats = require "parser" ()

local print_em = false

describe("The luC grammar", function()

  local function check_result(subject, match)
    -- TODO: How to get busted to print furthest_match if this fails?
    assert.message("failed to parse `" .. subject .. "`").is_not_nil(match)
    if match_stats.furthest_match_subject then
      assert.equal(subject, match_stats.furthest_match_subject)
    end

    if print_em then
      print("")
      print("---")
      print(subject)
      print("")
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
    -- Or copy `luc_grammar`?
    luc_grammar[1], prev_root = pattern * -1, luc_grammar[1]
    local match = lpeg.P(luc_grammar):match(term)
    luc_grammar[1] = prev_root
    check_result(term, match)
  end

  local function check_prog(program)
    check_result(program, luc:match(program))
  end

  it("parses integrals", function()
    print_em = false
    check("0", luc_grammar.num_literal)
    check("01", luc_grammar.num_literal)
  end)

  it("parses strings", function()
    print_em = false
    check([["Hello world!"]], luc_grammar.str_literal)
    check([["\\"]], luc_grammar.str_literal)
    check([["abc\n"]], luc_grammar.str_literal)
    check([["\xDEAD"]], luc_grammar.str_literal)
    check([["\"Hello world\""]], luc_grammar.str_literal)
  end)

  it("parses arithmetic (val_term's)", function()
    print_em = false
    check("c / d", luc_grammar.val_term)
    check("a + b * c // d", luc_grammar.val_term)
  end)

  it("parses enum, struct, and union literals", function()
    print_em = false
    check("enum { A = 0; B = 1; }", luc_grammar.type_literal)
    check("struct { x : int; y : int; }", luc_grammar.type_literal)
    check("union { x : int; y : float; }", luc_grammar.type_literal)
  end)

  it("parses function type literals", function()
    print_em = false
    check("(x : int) => int", luc_grammar.type_literal)
    check("(x : int) -> int", luc_grammar.type_literal)
    check("(x : int) => (y : int) => int", luc_grammar.type_literal)
  end)

  it("parses advanced type expressions", function()
    print_em = false
    check("(T where { T :: float; })", luc_grammar.type_expr)
    check("((x : int, y : float) => T where { T :: float; })", luc_grammar.type_expr)
    -- TODO: check("((int, float) => T where { T :: float; })", luc_grammar.type_expr)
  end)

  it("parses type expressions", function()
    print_em = false
    check("F(U, V)", luc_grammar.type_expr)
    check("(T : Type) => Type == F(T)", luc_grammar.func_literal)
  end)

  it("parses kind expressions (as types)", function()
    print_em = false
    check("Type", luc_grammar.type_expr)
    check("(T : Type) => Type", luc_grammar.type_expr)
    check("(T : Type, V : Type) => Type", luc_grammar.type_expr)
  end)

  it("parses program type decls", function()
    print_em = false
    check_prog [[ P :: struct { x : int; y : int; }; ]]
    check_prog [[ E :: enum { A = 0; B = 1; }; ]]
  end)

  it("parses program func decls", function()
    print_em = false
    check_prog [[ f : (x : int) => int; ]]
    check_prog [[ f : (Int, Float) => Bool; ]]
    check_prog [[
      f : (x : int, y : int, opts : Options) => int
      where {
        Options :: struct { v: bool; };
      };
    ]]
  end)

  it("parses value function defs", function()
    print_em = false
    check_prog [[ F : (T : Type) => Type == T; ]]
    check_prog [[ A : (F : (Type, Type) => Type, T) => Type == F(T, T); ]]
    check_prog [[ F : (T : Type) => Type == F(U(T)) where { T :: Class; }; ]]
  end)

  it("parses program function def", function()
    print_em = false
    -- N.B. the former translates to a C-function, the latter to a pointer,
    -- also `f` can be used recursively in the former whereas it has not
    -- been declared for use in the definition in the second case.
    check_prog [[ f : (x : Int, y : Int) => Int { return x * y; }; ]]
    check_prog [[ f := (x : Int, y : Int) => Int { return x * y; }; ]]
    check_prog [[ f : (x : Int) => Int == (x + 1); ]]
    check_prog [[
      add2 : (x : Int, y : Int) => Int
      {
        return x + y;
      };
    ]]
  end)

  it("parses program value defs", function()
    print_em = false
    check_prog [[ x : Int = a + b; ]]
    check_prog [[ x := a + b where { a := f(z); b := g(y); }; ]]
    check_prog [[ x := a or b and c | d & e // f; ]]
  end)

end)
