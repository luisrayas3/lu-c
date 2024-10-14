local tprint = require "print_ast"

describe("The luC transpiler", function()


end)

prog = [[
add2 : (x : Int, y : Int) -> Int
{
  return x + y;
}
]]
out = [[
int add2(int x, int y)
{
  return x + y;
}
]]
