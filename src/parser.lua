local lpeg = require "lpeg"

local locale = lpeg.locale()
local P, S, V = lpeg.P, lpeg.S, lpeg.V
local C, Cb, Cc, Cg, Cs, Cmt =
    lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cg, lpeg.Cs, lpeg.Cmt

local namechar = locale.alnum + P "_"
local nameinit = namechar - locale.digit
local w = local.space ^ 0  -- optional whitespace

local keywords = P(-1)
local function K(k)
  keyword = P(k) * -namechar
  keywords = keywords + keyword
  return keyword
}

local luc = P {
  (w * V "decl" * w * P ";")^0 * w * -1;

  decl =
      + V "name" * w * P "::" * w * V "type_expr"
      + V "name" * w * P "==" * w * V "val_expr"
      ;
  stmt =
      + K "do" * w * (P "{" * stmts * P "}" + V "func_call")
      + K "return" * (w * V "expr")^-1
      ;

  val_expr = V "simple_expr" * (w * V "where_block")
  simple_expr =
      + V "unop" * w * V "expr"
      + V ""
      ;

  where_block = K "where" * w * P "{" * wheres * P "}";
  wheres = (w * V "where" * w * P ";")

  -- Must be the last pattern defined to use complete keywords pattern
  name = nameinit * namechar ^ 0 - keywords
}
