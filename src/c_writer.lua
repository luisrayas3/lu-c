local table = require "table"

-- Things to be written (h):
-- - `extern` function & data decls
-- - Type definitions
-- - `inline` function definitions
-- Things to be written (c):
-- - `#include`s
-- - Static value definitions
-- - Function definitions
-- - Nested function definitions
local function write_c(chunk_ast, f)
  scopes = {{}}
  f:write("/* luC auto-generated */\n")
  f:write("\n")
  for i in 1, #chunk_ast do
    write()
  end
end

-- scopes: [1] is always TU scope
local function write_func(node, scopes)
  c_globals = {}
  c_locals = {}

  func_op, params, return_type = table.unpack(node[2])
  c_out = {
    write_type(return_type), "TEMPNAME", write_params(params),
    "{",
    write_func_body(node[3]),
    "}",
  }

  return c_globals, c_locals, c_out
end


return write_c

[[
// header
#define __luC_TYPE_var1 (int)
#define __luC_VALUE_var1 (123)
extern const __luC_TYPE_var1 var1;
// c
const __luC_TYPE_var1 var1 = __luC_VALUE_var1;
]]

[[
struct __luC_mpack_1 {
  int data1;
  int data2;
};
typedef struct __luC_mpack_1 LUC_NAMESPACED(mpack, MyClassDef);
]]

[[
E :: enum (Int) {
  ONE_OPTION = 0;
  TWO_OPTION = 1;
} where {
  is_even: (it) => bool { it == ONE_OPTION };
}
]] [[
enum mypack_enum_1 {
  mypack_enum_1_0_ONE_OPTION = 0;
  mypack_enum_1_0_TWO_OPTION = 1;
};
typedef int mypack_enum_1_type;
typedef enum mypack_enum_1 mypack_E;
#if defined(E)
#  error "E is already defined"
#endif  // defined(E)
#define E mypack_E
]]

[[
Invertible : (Type) => Class;
Invertible : (T : Type) => Type == class {
  invert: (@T) => void;
};
]] [[
# define mypack_class_1(MACRO_ARG_T) struct mypack_class_1_t_ ## MACRO_ARG_T {
  void (*invert)((MACRO_ARG_T)*);
};
]]
