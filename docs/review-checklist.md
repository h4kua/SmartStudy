# Pre-Commit Review Checklist — AI Academic Mentor

Run through this before every commit. Items marked **[BLOCKER]** must pass before pushing.

---

## Security — BLOCKERS

- [ ] **[BLOCKER]** `GROQ_API_KEY` in `.xcscheme` is empty: `value = ""`
- [ ] **[BLOCKER]** `crew_backend/.env` is NOT staged (`git diff --cached` should not show it)
- [ ] **[BLOCKER]** `GoogleService-Info.plist` is NOT staged
- [ ] No API keys, tokens, or passwords appear in any Swift or Python file as string literals

Quick check:
```bash
git diff --cached --name-only | grep -E "\.env|GoogleService"
grep -r "gsk_\|Bearer " --include="*.swift" FinalProject/
```

---

## iOS Build

- [ ] `xcodebuild -scheme FinalProject ... build` exits 0 with no new errors
- [ ] No new `warning:` lines for code you touched
- [ ] No raw colors/fonts — only `StudyTheme.*`, `StudyFont.*`, `StudySpacing.*`
- [ ] Every new `.swift` file is added to `project.pbxproj` (visible in Xcode navigator)

---

## Architecture

- [ ] ViewModels are `@MainActor final class` with no `DispatchQueue.main.async` workarounds
- [ ] Groq calls go through `GroqService.shared.*`, never directly to `api.groq.com`
- [ ] CrewAI calls go through `CrewAIService.shared.*`, never direct `URLSession` to backend
- [ ] `BackendConfig.baseURL` is the only place the backend IP/port is defined

---

## Backend (if `crew_backend/` changed)

- [ ] `./scripts/test.sh --backend-only` passes
- [ ] New endpoint has a Pydantic model for its request body
- [ ] JSON extracted from LLM output uses `json.JSONDecoder().raw_decode(raw, raw.find('{'))`, not a greedy regex
- [ ] OTEL env vars are set in `start.sh` before Python is invoked (not only inside Python)
- [ ] `requirements.txt` updated if a new dependency was added

---

## Feature Behavior

- [ ] Exam anti-cheat: `logAntiCheatWarning` fires on `.background` only, not `.inactive`
- [ ] `ExamSessionView` has `interactiveDismissDisabled(true)` — do not remove
- [ ] Focus camera in Quiz runs without a visible preview (no `AVCaptureVideoPreviewLayer` shown to user)
- [ ] Scan & Solve: Take Photo and Choose from Photos buttons both work; answer displays after solve

---

## UX / Theme

- [ ] New views use dark color scheme (`.preferredColorScheme(.dark)` or inherits from root)
- [ ] Loading states use `ProgressView` / shimmer — no frozen UI
- [ ] Error states show the `errorMessage` from the ViewModel, not raw Swift error descriptions

---

## Commit Message Format

```
<type>: <short description>

<optional body explaining WHY, not WHAT>
```

Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`

Example: `fix: fire exam anti-cheat only on .background to avoid double-counting`
