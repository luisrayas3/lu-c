
local tprint = require "print_ast"
local luc2c = require "luc2c"
local luc = require "parser" ()

local FunctionDef = luc2c.FunctionDef
local ReturnStmt = luc2c.ReturnStmt
local BuiltinOp = luc2c.BuiltinOp
local FunctionCall = luc2c.FunctionCall
local VariableRef = luc2c.VariableRef


local function table_eq(t1, t2)
  if type(t1) ~= type(t2) then return false end
  if type(t1) ~= "table" then return t1 == t2 end
  for k, v in pairs(t1) do
    if not table_eq(v, t2[k]) then return false end
  end
  for k, v in pairs(t2) do
    if not table_eq(v, t1[k]) then return false end
  end
  return true
end


describe("The luC grammar", function()

  function check(prog, expected)
    local ast = luc:match(prog)
    assert.message("Program doesn't parse:\n" .. prog).is_not_nil(ast)
    local c_ast = luc2c.c_ast_from_luc_ast(ast)
    if not table_eq(c_ast, expected) then
      print("Expected:")
      tprint(expected)
      print("Got:")
      tprint(c_ast)
      assert.message("^^^").is_true(false)
    end
  end

  it("converts add function", function()
    local prog = [[
      add2 : (x : Int, y : Int) => Int
      {
        return x + y;
      };
    ]]
    check(prog, {
        FunctionDef {
          name = "add2";
          type = "int";
          params = {
            { name = "x"; type = "int"; },
            { name = "y"; type = "int"; },
          };
          body = {
            ReturnStmt {
              expr = FunctionCall {
                func = BuiltinOp { name = "+"; };
                args = {
                  VariableRef { name = "x"; },
                  VariableRef { name = "y"; },
                };
              };
            },
          };
        },
      }
    )
  end)

end)
