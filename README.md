# lu-c

## Grammar

### Type declarations and definitions

```
Point :: struct  #(
  Points represent a 3D location in cartesian space.
) {
  x: int  #( x-axis location );
  y: int  #(...);
  z: int  #(...);
};
```

### Generic manipulation of statements, types, and values

```
if (this ?= that) do {
  goSomewhere();
} else do {
  print("uneq");
};

x = if (this ?= that) "eq" else "uneq";

Number (integral: bool = false) :: if (integral) int else double;
```
