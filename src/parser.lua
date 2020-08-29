local lpeg = require "lpeg"

local locale = lpeg.locale()
local P, S, V = lpeg.P, lpeg.S, lpeg.V

local namechar = locale.alnum + P "_"
local nameinit = namechar - locale.digit
local w = locale.space ^ 0  -- optional whitespace

local C, Cb, Cc, Cg, Cs, Cmt =
    lpeg.C, lpeg.Cb, lpeg.Cc, lpeg.Cg, lpeg.Cs, lpeg.Cmt
local function un_cap(op, opee)
  return {op, opee}
end
local function bin_cap(lhs, op, rhs)
  return {op, lhs, rhs}
end
local function list_cap(...)
  return {...}
end
local function left_to_right(lhs, op, rhs, ...)
  if op == nil then return lhs end
  return left_to_right({op, lhs, rhs}, ...)
end
local function un_right_to_left(token, next_token, ...)
  if next_token == nil then return token end
  return {token, un_right_to_left(next_token, ...)}
end

local keywords = P(-1)
local function K(k)
  keyword = k * -namechar
  keywords = keywords + keyword
  return C(keyword)
end

local function comma_separated(node)
  -- Optional trailing comma
  return
      (w * node * (w * P "," * w * node) ^ 0 * (w * P ",") ^ -1) ^ -1 * w
      / list_cap
end
local function semicolon_separated(node)
  return (w * node * w * P ";") ^ 0 * w / list_cap
end

local function if_selected(node)
  -- TODO: support leading ? or !
  return
      K "if" * w * P "(" * w * V "expr" * w * P ")" * w * node
      * (w * K "else" * w * if_selected(node)) ^ -1
      / function (...) return {...} end
end
local function atomic(node)
  return P "(" * w * node * w * P ")"
end

local function chain_binary_op(op, node)
  return node * (w * op * w * node) ^ 0 / left_to_right
end
local function single_binary_op(op, node)
  return node * (w * op * w * node) ^ -1 / left_to_right
end

local function chain_prefix_op(op, node)
  return (op * w) ^ 0 * node / un_right_to_left
end

local function with_where(node)
  return node + node * w * K "where" * w * P "{" * semicolon_separated(V "decl_def") * P "}" / bin_cap
end

local un_op = C "?" + C "!" + C "+" + C "-" * C "*" * C "/" * C "~"

-- Binary operators from highest to lowest precedence

local mul_op = C "*" + C "/" + C "%"
local add_op = C "+" + C "-"

local bit_and_op = C "&"
local bit_xor_op = C "^"
local bit_or_op = C "|"

local lt_op = C "<" + C "<="  -- Same precedence as gt
local gt_op = C ">" + C ">="
local eq_op = C "?="  -- Same precedence as neq
local neq_op = C "!="

local and_op = K "and"
local xor_op = K "xor"
local or_op = K "or"

-- Type operators
local type_op = K "struct" + K "union"
local func_type_op = C "->" + C "=>"


local luc = P {
  semicolon_separated(V "decl_def") * -1;

  decl_def
      = V "name" * w * C "::" * w * with_where(V "type_expr") / bin_cap
      + V "name" * w * C "==" * w * with_where(V "val_expr") / bin_cap
      + V "name" * w * C ":" * w * with_where(V "val_init") / bin_cap
      ;

  val_init
      = V "type_expr" * (w * C "=" * w * V "where_val_expr") ^ -1
      + C "=" * w * V "where_val_expr"
      + V "func_def"
      ;

  type_expr
      = if_selected(V "type_expr")
      + V "func_call"
      ;
  type_atom
      = V "name"
      + atomic(V "type_expr")
      ;

  val_expr
      = if_selected(V "val_expr")
      + chain_binary_op(or_op, V "or_term")
      ;
  or_term = chain_binary_op(xor_op, V "xor_term");
  xor_term = chain_binary_op(and_op, V "and_term");
  and_term
      = chain_binary_op(eq_op, V "eq_term")
      + single_binary_op(neq_op, V "eq_term");
  eq_term
      = chain_binary_op(lt_op, V "comp_term")
      + chain_binary_op(gt_op, V "comp_term");
  comp_term = chain_binary_op(bit_or_op, V "bit_or_term");
  bit_or_term = chain_binary_op(bit_xor_op, V "bit_xor_term");
  bit_xor_term = chain_binary_op(bit_and_op, V "bit_and_term");
  bit_and_term = chain_binary_op(add_op, V "add_term");
  add_term = chain_binary_op(mul_op, V "mul_term");
  mul_term = chain_prefix_op(un_op, V "val_atom");

  val_atom
      = V "func_call"
      + V "lit_num"
      + V "func_def"
      + atomic(V "val_expr")
      ;
  func_call = V "callable" * (w * C "(" * comma_separated(V "expr") * P ")") ^ 0 / left_to_right;
  callable = V "name";

  func_def =
      P "(" * comma_separated(V "param") * P ")" * w * func_type_op * (w * V "type_expr") ^ -1
      * (w * V "where_block") ^ -1
      * w * V "stmt_block" / list_cap;  -- TODO: Not list
  param = V "name" * w * C ":" * w * V "type_expr" / bin_cap;
  stmt_block = P "{" * semicolon_separated(V "stmt") * P "}";
  stmt
      = V "decl_def"
      + K "do" * w * (V "stmt_block" + with_where(V "func_call")) / un_cap
      + K "return" * (w * with_where(V "val_expr")) ^ -1 / un_cap
      ;

  lit_num = locale.digit ^ 1 / tonumber;

  -- Must be the last pattern defined to use complete keywords pattern
  name = C(nameinit * namechar ^ 0 - keywords);
}

return luc
