# QA Testing Checklist - Code Refactoring Changes

## Critical Areas to Test

### 1. Settings Window
- [ ] Settings window opens correctly (Cmd+, or menu)
- [ ] General tab displays correctly
- [ ] Privacy tab displays correctly
- [ ] Tab switching works smoothly
- [ ] All settings persist after app restart

### 2. General Settings
- [ ] **Home Page Text Field:**
  - [ ] Text field is left-aligned (not right-aligned)
  - [ ] Can type and edit homepage URL
  - [ ] Saves on Enter key
  - [ ] Invalid URLs handled gracefully (should fallback to default)
- [ ] Search engine picker works
- [ ] New tab behavior (homepage vs blank page)
- [ ] Download folder selection works
- [ ] Network activity indicators toggle correctly
- [ ] **Sound Settings:**
  - [ ] Enable/disable toggle works
  - [ ] Volume slider works
  - [ ] Receive/Send toggles work
  - [ ] Sound scope (all tabs vs active tab) works

### 3. Privacy Settings
- [ ] All privacy toggles work correctly
- [ ] **Storage Whitelist:**
  - [ ] Can add domains
  - [ ] Can remove domains
  - [ ] Clear data buttons work
- [ ] **Custom Blocklist:**
  - [ ] Can add/remove domains
  - [ ] Enable/disable toggle works
- [ ] Privacy score badge updates correctly

### 4. Browser Functionality
- [ ] **New Tab Creation:**
  - [ ] Creates tab with homepage setting
  - [ ] Creates tab with blank page setting
  - [ ] Creates tab with explicit URL
- [ ] **Homepage Navigation:**
  - [ ] Valid URLs work correctly
  - [ ] Invalid URLs fallback gracefully
  - [ ] Default fallback (kagi.com) works
- [ ] **URL Bar Navigation:**
  - [ ] Direct URLs work
  - [ ] Domain-only (adds https://) works
  - [ ] Search queries work

### 5. WebView Features
- [ ] **Context Menu:**
  - [ ] "View Page Source" works
  - [ ] "Save Page As..." works
  - [ ] Save panel appears (no crashes)
  - [ ] All save formats work (Web Archive, HTML, PNG)

### 6. Network Sounds
- [ ] Sounds play when enabled
- [ ] Volume control works
- [ ] No crashes if audio initialization fails
- [ ] Scope settings respected (all tabs vs active tab)

## Edge Cases to Verify

1. **Invalid Homepage URL:**
   - [ ] Enter invalid URL in settings → should fallback to default
   - [ ] Test with malformed URLs (spaces, special chars, etc.)

2. **Empty Homepage:**
   - [ ] Clear homepage field → should use default
   - [ ] Test with empty string

3. **Network Sound Initialization:**
   - [ ] Test on systems with audio issues → should fail gracefully
   - [ ] Test with audio permissions denied

4. **Save Panel:**
   - [ ] Test when WebView has no window → should not crash
   - [ ] Test save functionality from different contexts

5. **Settings Persistence:**
   - [ ] Change settings → quit app → reopen → verify settings saved
   - [ ] Test with multiple setting changes in one session

## Regression Checks

- [ ] No crashes on app launch
- [ ] No crashes when opening settings
- [ ] No crashes when switching tabs
- [ ] No crashes when navigating
- [ ] All existing features still work as before

## Known Changes (Not Bugs)

### Phase 1 Changes
- Classes are now `final` (compile-time only, no runtime impact)
- Code split into separate files (organizational, no behavior change)
- Force unwraps replaced with safe unwrapping (more robust, may expose previously hidden issues)

### Phase 2 Changes
- Error handling improved: `try?` replaced with `do-catch` blocks (errors now logged instead of silently ignored)
- State management: Changed from `@ObservedObject` with singletons to `@EnvironmentObject` pattern
- Access control: All internal implementation details are now `private`
- Memory management: Verified no retain cycles (struct-based coordinators prevent cycles)

## Priority Levels

### High Priority
- Settings window functionality
- Homepage navigation
- Save page functionality

### Medium Priority
- Network sounds
- Privacy settings persistence

### Low Priority
- Edge cases with invalid URLs

## Phase 2: Error Handling & State Management Tests

### 7. Error Handling Improvements
- [ ] **Storage Whitelist JSON Operations:**
  - [ ] Add domain to whitelist → verify saves correctly
  - [ ] Remove domain from whitelist → verify updates correctly
  - [ ] Test with corrupted UserDefaults data → should handle gracefully (no crash)
  - [ ] Test with invalid JSON in storage → should fallback to empty array
- [ ] **Custom Blocklist JSON Operations:**
  - [ ] Add domain to blocklist → verify saves correctly
  - [ ] Remove domain from blocklist → verify updates correctly
  - [ ] Test with corrupted UserDefaults data → should handle gracefully
- [ ] **Download Directory Creation:**
  - [ ] Start download with valid download path → should create directory if missing
  - [ ] Start download with invalid path (no permissions) → should fail gracefully with error message
  - [ ] Start download with read-only directory → should show appropriate error
- [ ] **WebView Regex Patterns:**
  - [ ] View page source → should work correctly
  - [ ] Test with pages containing special characters → should handle properly
  - [ ] Verify no crashes if regex compilation fails

### 8. State Management (@EnvironmentObject)
- [ ] **Settings View:**
  - [ ] Open settings → verify PrivacySettings loads correctly via @EnvironmentObject
  - [ ] Change privacy settings → verify changes persist
  - [ ] Close and reopen settings → verify state maintained
- [ ] **General Settings View:**
  - [ ] Verify PrivacySettings accessible via @EnvironmentObject
  - [ ] Verify NetworkSoundManager and NetworkActivityMonitor still work (as @ObservedObject)
  - [ ] Change settings → verify updates reflect immediately
- [ ] **Environment Object Propagation:**
  - [ ] Verify settings are passed correctly from BarcApp → ContentView → SettingsView
  - [ ] Test with multiple settings windows (if possible) → verify they share state

### 9. Memory Management
- [ ] **No Retain Cycles:**
  - [ ] Open and close settings multiple times → verify no memory leaks
  - [ ] Add/remove domains from whitelist repeatedly → verify no memory buildup
  - [ ] Start/cancel downloads repeatedly → verify memory released properly
- [ ] **Delegate Patterns:**
  - [ ] Test WebView delegate callbacks → verify no retain cycles
  - [ ] Test text field delegate callbacks → verify no retain cycles
- [ ] **Closure Captures:**
  - [ ] Test async operations (downloads, network requests) → verify closures don't leak
  - [ ] Monitor memory usage during extended use → should remain stable

### 10. Error Recovery & Logging
- [ ] **Check Console Logs:**
  - [ ] Verify error messages appear in console for failed operations
  - [ ] Verify no silent failures (all errors should be logged)
  - [ ] Test with invalid data → check console for appropriate error messages
- [ ] **User-Facing Error Handling:**
  - [ ] Download failures show error message to user
  - [ ] Settings save failures handled gracefully
  - [ ] No crashes from error conditions

## Notes

Most changes are internal improvements. Focus testing on settings functionality and browser navigation, especially edge cases around URL handling and homepage settings.

**Phase 2 Focus:** Pay special attention to error handling paths and state management. Verify that all error conditions are handled gracefully and that the @EnvironmentObject pattern works correctly throughout the app.

