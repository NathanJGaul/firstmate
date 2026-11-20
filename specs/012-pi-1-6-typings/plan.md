# Plan

Copy the base-class render result in `CalmOperationalUserMessageComponent.render` (`.pi/extensions/lib/fm-calm-operational-user-layout.ts`) so the returned array is a fresh mutable `string[]` on every Pi release.
No other `super.render` call exists under `.pi/extensions`.
No CI change: the existing portable lane that installs the latest Pi package is the regression for A1 and A2.
