# Research

- Option cast `as string[]`: rejected, hides a real readonly contract.
- Option widen override return to `readonly string[]`: rejected, not assignable to the 1.5.2 base signature.
- Option copy with spread: chosen, type-checks on both and never mutates the base array.
- CI pin: rejected, see spec out of scope.
