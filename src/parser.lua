local lpeg = require "lpeg"

local locale = lpeg.locale()
local P, S, V = lpeg.P, lpeg.S, lpeg.V

local namechar = locale.alnum + P "_"
local nameinit = namechar - locale.digit
local w = locale.space ^ 0  -- optional whitespace

local C, Cc = lpeg.C, lpeg.Cc

local function un_cap(op, opee) return {op, opee} end
local function bin_cap(lhs, op, ...) return {op, lhs, ...} end
local function list_cap(...) return {...} end

local function left_to_right(lhs, op, rhs, ...)
  if op == nil then return lhs end
  return left_to_right({op, lhs, rhs}, ...)
end
local function un_right_to_left(token, next_token, ...)
  if next_token == nil then return token end
  return {token, un_right_to_left(next_token, ...)}
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

local function optional(node)
  return node + C ""
end
local function comma_separated(node)
  -- Optional trailing comma
  return (w * node * (w * P "," * w * node) ^ 0 * (w * P ",") ^ -1) ^ -1 * w / list_cap
end
local function semicolon_separated(node)
  return (w * node * w * P ";") ^ 0 * w / list_cap
end
local function atomic(node)
  return P "(" * w * node * w * P ")"
end

local keywords = P(-1)
local function K(k)
  keyword = k * -namechar
  keywords = keywords + keyword
  return C(keyword)
end

local if_kw, else_kw = K "if", K "else"
local function if_selected(node, if_selected_node)
  -- TODO: support leading ? or !
  return
      if_kw * w * P "(" * w * V "val_expr" * w * P ")" * w * node
       * optional(w * else_kw * w * if_selected_node / un_cap) / list_cap  -- TODO: not list_cap
      + node
end

local where_kw = K "where"
local function with_where(node)
  return node * w * where_kw * w * P "{" * semicolon_separated(V "decl_def") * P "}" / bin_cap + node
end

local un_op = C "?" + C "!" + C "+" + C "-" * C "*" * C "/" * C "~"

-- Binary operators from highest to lowest precedence

-- local exp_op = C "**"  -- Should we just use pow/exp?
local mul_op = C "*" + C "//" + C "/" + C "%"  -- C "/%"
local add_op = C "+" + C "-"

local bit_and_op = C "&"
local bit_xor_op = C "^"
local bit_or_op = C "|"

local lt_op = C "<" + C "<="  -- Same precedence as gt
local gt_op = C ">" + C ">="
local eq_op = C "?="
local neq_op = C "!="

local and_op = K "and"
local xor_op = K "xor"
local or_op = K "or"

local func_type_op = C "->" + C "=>"

local assg_op = C "=" + C "+=" + C "-=" + C "*=" + C "/=" + C "%="


local luc = {
  semicolon_separated(V "decl_def") * -1;

  decl_def
      = V "name" * w * C "::" * w * with_where(V "type_literal") / bin_cap
      + V "name" * w * C ":" * w * V "typed_literal" / bin_cap
      + V "name" * w * C "==" * w * with_where(V "val_expr") / bin_cap
      + V "name" * w * C ":" * w * with_where(optional(V "type_expr" * w) * C "=" * w * V "val_expr")
      + V "decl"
      ;
  decl = V "name" * w * C ":" * w * with_where(V "type_expr") / bin_cap;

  typed_literal  -- symbolic? `i: int { 2 * i } where { for_all (x: int) => {= i * x == x} }`
      = V "func_literal"
      -- + V "array_literal"
      -- + V "struct_literal"
      ;

  type_literal
      = V "type_func"
      + V "type_expr"
      ;
  type_func = V "type_param_list" * w * C ":>" * w * V "type_expr" / bin_cap;
  type_param_list = P "(" * comma_separated(V "name") * P ")" / list_cap;
  type_expr = if_selected(V "type_term", V "type_expr");
  type_term
      = V "type_ction"
      + V "func_call"  -- TODO: type_func_call
      + V "type_atom"
      ;
  type_ction
      = V "func_type"
      + K "enum" * w * P "{" * semicolon_separated(V "enum_assg") * P "}" / un_cap
      + K "union" * w * P "{" * semicolon_separated(V "decl") * P "}" / un_cap
      + K "struct" * w * P "{" * semicolon_separated(V "decl") * P "}" / un_cap
      ;
  type_atom = V "name" + atomic(V "type_expr");

  func_type = V "param_list" * w * func_type_op * optional(w * V "type_expr") / bin_cap;
  param_list = P "(" * comma_separated(V "param") * P ")";
  param = V "name" * w * C ":" * w * V "type_expr" / bin_cap;

  enum_assg = V "name" * w * C "==" * w * V "val_expr" / bin_cap;


  val_expr = if_selected(V "val_term", V "val_expr");
  -- TODO: Support prefixing and/xor/or
  val_term = chain_binary_op(or_op, V "or_term");
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
  mul_term = chain_prefix_op(un_op, V "un_term");
  un_term = V "func_call" + V "val_atom";
  func_call = V "callable_atom" * (w * V "args") ^ 1 / left_to_right;
  args = Cc "(" * V "val_atom" + P "(" * comma_separated(V "val_expr") * P ")" / un_cap;

  val_atom = V "callable_atom" + V "non_callable_atom";
  callable_atom
      = atomic(V "val_expr")
      + V "func_literal"
      + V "name"
      ;
  non_callable_atom
      = V "num_literal"
      ;

  func_literal = with_where(V "func_type") * w * (V "expr_block" + V "stmt_block") / un_cap;
  expr_block = P "{" * w * (P "=" / "return") * w * V "val_expr" * w * P "}" / un_cap / list_cap;
  stmt_block = P "{" * semicolon_separated(V "decl_def" + V "effect_stmt") * P "}";
  effect_stmt = if_selected(V "effect_stmt_term", V "effect_stmt");
  effect_stmt_term
      = V "return_stmt"
      + V  "name" * w * assg_op * w * with_where(V "val_expr") / bin_cap
      + K "do" * w * (V "stmt_block" + with_where(V "func_call")) / un_cap
      ;
  return_stmt = K "return" * optional(w * with_where(V "val_expr")) / un_cap;

  -- array_literal = ;

  num_literal = locale.digit ^ 1 / tonumber;

  -- Must be the last pattern defined to use complete keywords pattern
  keyword = keywords;
  name = C(nameinit * namechar ^ 0 - V "keyword");
}

return function () return P(luc), luc end
