## LLVM Mode
- LLVM mode is still under development. Though it works currently, some features are not yet implemented.
- our `llvm-mode` instrumentation needs llvm dependencies (>= LLVM 16.0) and is tested with LLVM 18, 19 and 20.
- `hopper-clang` invokes the clang of the LLVM the pass was built against (set `HOPPER_CC`/`HOPPER_CXX` to override), since the pass plugin only loads into that clang.

## Plan
- [x] API-sensitive branch counting
- [x] Cmp hooking
- [x] Resource related hooking

## How to use

- Compile your libraries with `hopper-clang`.
```
CC=hopper-clang
CXX=hopper-clang++
```

- Use hopper to compile the libraries. Hopper can identify the libraries are compiled by the `hopper-clang` and uses the `llvm-mode` automatically.
```
hopper compile --header ./cJSON.h --library ./libcjson.so --output output
```