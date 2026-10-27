# Accessibility in Compose — checklist and patterns

Accessibility is a Play quality signal, a legal requirement in many markets (EAA in the EU since
June 2025), and it makes UI tests possible (tests find nodes through semantics).

## The checklist

1. **Every interactive element has a name.** `IconButton { Icon(…, contentDescription = "Add to cart") }`.
   Text buttons are self-describing. Decorative images: `contentDescription = null`.
2. **Touch targets ≥ 48×48 dp.** Material components comply. For custom `Modifier.clickable` on
   small content, add `Modifier.minimumInteractiveComponentSize()` or `sizeIn(minWidth = 48.dp, minHeight = 48.dp)`.
3. **Contrast ≥ 4.5:1 for text, 3:1 for large text and icons.** Use Material `on*` roles.
4. **No information by color alone.** Add icons/text for status.
5. **Text scales.** Don't fix heights around text; test `fontScale = 1.3f` and `2f`
   (`@PreviewFontScale`, `adb shell settings put system font_scale 1.5`). Use `sp` for text, `dp` for
   layout; use `LocalDensity` to convert when necessary.
6. **Focus order is logical** for keyboard and switch access. `Modifier.focusProperties { next = … }`
   only when the default order is wrong.
7. **Announce dynamic changes.** `Modifier.semantics { liveRegion = LiveRegionMode.Polite }` on a
   status text; snackbars are announced automatically.
8. **Headings and structure.** `Modifier.semantics { heading() }` on section titles;
   `Modifier.semantics(mergeDescendants = true) { }` on list rows so TalkBack reads one item, not five.
   `clearAndSetSemantics { contentDescription = "…" }` to replace a noisy subtree with one label.
9. **Roles and state.** `Role.Button/Checkbox/Switch/Tab/RadioButton` via the `clickable(role=)` /
   `toggleable` / `selectable` modifiers; `stateDescription` ("Selected, 3 of 5"). Use
   `Modifier.toggleable(value, onValueChange)` instead of `clickable` for toggles.
10. **Custom actions.** `Modifier.semantics { customActions = listOf(CustomAccessibilityAction("Archive") { …; true }) }`
    for swipe actions, so they're reachable without gestures.
11. **Reduced motion / animations.** Respect `LocalAccessibilityManager`; keep animations
    interruptible; provide `animationSpec = snap()` alternatives if the OS reports reduced motion.
12. **Timeouts and autoplay.** Don't auto-dismiss critical content; let users pause carousels.
13. **Form fields.** `Modifier.semantics { contentType = ContentType.EmailAddress }` for autofill;
    error messages linked via `supportingText` and `isError`; `KeyboardType.Email` etc.
14. **RTL.** `Icons.AutoMirrored.*`, `Arrangement.Start/End` (not Left/Right), `padding(start=)`,
    test with `adb shell settings put global debug.force_rtl 1`.

## Snippets

```kotlin
// Row that reads as one item
Row(Modifier.semantics(mergeDescendants = true) { }.clickable(onClick = onOpen, role = Role.Button)) {
    Icon(Icons.Default.Star, contentDescription = null)
    Column { Text(title); Text(subtitle, style = MaterialTheme.typography.bodySmall) }
}

// Progress with meaningful description
LinearProgressIndicator(progress = { p }, modifier = Modifier.semantics { contentDescription = "Upload ${(p*100).toInt()} percent" })

// Toggle row
Row(Modifier.toggleable(value = enabled, onValueChange = onToggle, role = Role.Switch)) {
    Text("Wi-Fi"); Spacer(Modifier.weight(1f)); Switch(checked = enabled, onCheckedChange = null)
}
```

## Verify

- `android layout` (or `adb shell uiautomator dump`) shows names, roles, bounds — spot missing labels.
- Enable TalkBack on the emulator (`adb shell settings put secure enabled_accessibility_services com.google.android.marvin.talkback/com.google.android.marvin.talkback.TalkBackService` on images that ship it) and swipe through the screen.
- Compose test: `onNodeWithContentDescription("Add to cart").assertHasClickAction()`,
  `assertIsToggleable()`, and add `Modifier.testTag` only when no semantic handle exists.
- Android Studio → Accessibility Scanner / Lint "Accessibility" category; Play Console pre-launch report.

Android 17 note: apps targeting 37 that use standard `TextView`/Compose text fields get improved
CJKV IME accessibility text-change events automatically; custom `InputConnection`s should call
`AccessibilityEvent.setTextChangeTypes()`.
