# Vietnamese Engine Review

Scope: `Caffee/Engine/*` (State, Parser, Transformer, Validator, Telex, VNI, Trie, EngineConfig) and `WordBuffer` in `Caffee/App/InputProcessor.swift`, which turns engine results into on-screen edits.

Method: I read every file, then compiled the engine and `WordBuffer` on their own with `swiftc`, together with a small driver. The driver types key sequences and applies every `Replacement` to a simulated screen the way the OS would (`<` = Backspace). Every result in this document comes from that driver running the code on `main` (`cb9f1e0`), not from reading the code. I also tried the fixes proposed below in the scratch copy. **They are not applied to the repository**, and the Xcode test suite has not been run against them.

---

## Status

Fixed on `main` in the commit after `cb9f1e0`: **#1–#10 and the #12 cleanup.** #11 is unchanged on purpose: it is UniKey-compatible free-style typing, not a bug. Every fix has a test in `RegressionTests` (`// MARK: - review-engine.md`), plus a corpus variant that types `ươ` as `uwow` / `u7o7`, and `text`/`next`/`texts`/`context` in the English recovery list.

| # | How it was fixed |
|---|------------------|
| 1, 9 | New `TiengVietState.mocCaHai` flag. A horn on `u` typed before `o`, or a second horn key on `uo`, horns both vowels; adjacent `ww`/`77` still cancels. The logic is shared as `TypingMethod.hornResult`. |
| 2, 5 | In raw mode, `WordBuffer.pop` removes exactly one character from the screen text. |
| 3, 6 | `.toggleToRaw` shows `wordState.transformed`, so the other marks stay. |
| 4 | The validator rejects huyền/hỏi/ngã with c/ch/p/t. |
| 7 | The Telex doubled-vowel check ignores case. |
| 8, 10 | The validator checks the marked nucleus exactly as the transformer places the mark (`ValidNguyenAmCoMu`), rejects `q` without `u` and `gh`/`ngh` before anything but e/ê/i, and lists every nucleus in `ValidVowelEndings`. `k` before a/o is still allowed (Bắc Kạn, Kon Tum). `more` → `mỏe` remains, because `oe` + hỏi is valid spelling. |
| 12 | Removed `noChange`, `notTiengViet`, `viTriDauThanh`, `ChuCai`, `nguyenAmChua`, `originalInput`, `ValidPhuAmCuoi` and the optional parse cache. `NguyenAmUO` is now a lowercase `Set`. Not done: storing the last applied mark key in place of the `keyStr` suffix rules. |

Behaviour change: after a word goes raw, Backspace no longer switches back to Vietnamese processing partway through the word. Only the one-step rollback (recovery caused by the last key) does.

## Summary

The structure is good. There is an immutable `TiengVietState` with a cached parse, and Parser, Validator and Transformer are pure functions. `EngineConfig` carries the options, so there is no global state. The corpus round-trip test covers about 9k syllables. Normal Vietnamese typed the way the corpus types it works.

The bugs are in paths the corpus does not reach:

| # | Severity | Problem | Example (Telex / VNI) |
|---|----------|---------|-----------------------|
| 1 | **High** | Marking each horn separately (`uwow`, `u7o7`) cancels the horn | `dduwowcj` → **đuọc**, `nguwowif` → **nguòi**, `d9u7o7c5` → **đuọc** |
| 2 | **High** | Backspacing more than one character in a recovered word corrupts the text | `texting` + ⌫ → **tetin**, `based` + ⌫ → **bae** |
| 3 | Medium | Cancelling one mark (double key) also wipes every other mark | `tieenss` → **tiens** (should be tiêns), `dduowngff` → **duongf**, VNI `d9uo7ng22` → **duong2** |
| 4 | Medium | The validator allows huyền/hỏi/ngã on syllables ending in c/ch/p/t | `text` → **tẽt**, `next` → **nẽt** |
| 5 | Medium | After cancelling a mark, Backspace brings the mark back | `tieenss` + ⌫ → **tiên** (the screen showed `tiens`) |
| 6 | Low | With spelling check off, a digit drops the tone key | `as1` → **a1**, `tas1` → **ta1** |
| 7 | Low | `aA` (lowercase then uppercase) does not make â | `aA` → **aA** |
| 8 | Low | Circumflex goes on the first vowel that can take it, not on the doubled key | `hoaa` → hôa, `oee` → ôe, `chaoo` → châo |
| 9 | Low | Horn on `u` disappears until a final consonant or third vowel is typed | `tuwo` → **tuơ** (then `tươn` after `n`) |
| 10 | Low | The validator never checks open nuclei or onset+rhyme pairs | `more` → mỏe, `qa`, `ka`, `ưy` are accepted |
| 11 | Info | Telex `d` anywhere after a leading `d` gives đ | `dad` → đa, `did` → đi |
| 12 | Info | Dead code and duplicated tables | see §12 |

Issues 2, 3 and 5 share one cause: **in raw mode, `WordBuffer` rebuilds the screen from `chuKhongDau`, and `chuKhongDau` does not contain the keys that were used up as marks.**

---

## 1. [High] Horning each vowel separately cancels the horn

**Repro (Telex):** `dduwowcj` → `đuọc`, `nguwowif` → `nguòi`, `thuwowngr` → `thuỏng`, `chuwowng` → `chuong`, `tuwowi` → `tuoi`.
**Repro (VNI):** `u7o7ng` → `uong`, `d9u7o7c5` → `đuọc`.

Typing `ư` and then `ơ` (`uw…ow`, `u7…o7`) is a very common habit, and UniKey and EVKey both accept it.

**Cause.** There is only one `dauMu` for the whole syllable, and `withMu` toggles it (`TiengVietState.swift:158-167`). The first `w` sets `.muMoc`. The second `w` lands on the `uo` nucleus and calls `withMu(.muMoc)` again (`Telex.swift:91-101`, `VNI.swift:81-84`), which turns the mark off. The `ww` cancel rule does not fire because the two `w`s are not adjacent, so the result is `.applyMark` with no horn at all.

**Why the tests miss it.** `CorpusTests.telexKeys` and `vniKeys` (`CorpusTests.swift:177`, `:211`) always type `ươ` as `uo` + one `w`/`7`. `EngineConfigTests.testTonePlacementDoesNotAffectOtherSyllables` does include `dduwowcj`, but it only checks that both tone styles give the same output. Both give the wrong `đuọc`, so the test passes.

**Fix (prototyped).** If the nucleus is `uo`/`uoi`/`uou`, the horn is already set, and the key is not a direct `ww`/`77`, keep the mark instead of toggling it:

```swift
case "w", "W":
  if state.dauMu == .muMoc, thanhPhan.chuaNguyenAmUO, !keyStr.lowercased().hasSuffix("ww") {
    return .applyMark(state)
  }
```

Do the same in VNI for `7`. With this change: `dduwowcj` → được, `nguwowif` → người, `thuwowngr` → thưởng, `giuwowngf` → giường, `ruwowuj` → rượu, `d9u7o7c5` → được.

Also add `uwow` / `u7o7` encodings to the corpus, and give `dduwowcj` an expected value.

## 2. [High] Backspace in a recovered word rebuilds the wrong text

**Repro:** `texting` then ⌫ → `tetin` (should be `textin`). `based` then ⌫ → `bae` (should be `base`).

**Cause.** In recovery mode the screen shows `String(keys)`, which is every key typed (`InputProcessor.swift:145-149`). The single-step rollback (`:64`) only handles the case where recovery started on the last key. Every other Backspace goes through the normal path (`:87-96`), which does this:

```swift
wordState = engine.pop(state: wordState)
keys = Array(wordState.chuKhongDau)   // the x in "texting" was a ngã key, so it is not here
transformed = String(keys)
```

Any key that was used as a mark before recovery started (`s f r x j w`, doubled vowels, `d`) is lost. The diff then rewrites the whole word. This hits mixed English typing often: any English word where a tone letter comes before the point where the engine gives up.

**Fix (prototyped).** While `stopProcessing` is set, the screen is plain text, so Backspace should remove exactly one character:

```swift
if stopProcessing, !keys.isEmpty {
  keys.removeLast()
  transformed.removeLast()
  wordState = engine.pop(state: wordState)
  lastValidSnapshot = nil
  return Self.letSystemDeleteOneCharacter(.diff(from: lastTransformed, to: transformed))
}
```

With this change: `texting`⌫ → `textin`, `based`⌫ → `base`. The one-step rollback still runs first, so `base`⌫ → `bá` is unchanged. Open question: should the buffer leave raw mode again once enough characters are deleted? Today it never does, and the fix keeps it that way.

## 3. [Medium] Cancelling one mark also removes every other mark

**Repro:** `tieenss` → `tiens` (expected `tiêns`). `tieengss` → `tiengs`. `dduowngff` → `duongf`. `ddaayss` → `days`. VNI `d9uo7ng22` → `duong2`, `tie6ng11` → `tieng1`.

**Cause.** `.toggleToRaw` sets `transformed = wordState.originalInput`, which is just `chuKhongDau` (`InputProcessor.swift:139-143`). `markResult` has already removed the cancelled mark and appended the key, but the circumflex, horn and đ that are still in `newState` never reach the screen.

**Fix (prototyped).** Use `transformed = wordState.transformed`. The transformer already applies marks to the parsed syllable and appends `conLai` unchanged, so the result is `tiêns`, `đươngf`, `đâys`. `aaa` → `aa`, `ddd` → `dd` and `uww` → `uw` do not change. This also fixes #6.

## 4. [Medium] Tone not checked against a stop final

**Repro:** `text` → `tẽt`, `next` → `nẽt`, `texts` → `tét`.

In Vietnamese, a syllable that ends in **c, ch, p, t** only takes sắc or nặng. `TiengVietValidator.needsRecovery` (`:121-151`) and `TiengVietState.needsRecovery` (`:92-94`) never look at `dauThanh`. This rule is cheap and catches common English words. The corpus model already encodes it (`Tone.allowedAfterStop`), so the round-trip test will catch any false rejection.

**Fix (prototyped).** Pass `dauThanh` into `needsRecovery` and return `true` for `.huyen`/`.hoi`/`.nga` combined with a stop final. Do not reject `.bang`, because `tet` is a normal step on the way to `tết`. With this change `text`/`next` recover to the raw keys, and `học`, `tiếng` and `được` are unaffected.

## 5. [Medium] Backspace after a cancel brings the mark back

**Repro:** `tieenss` shows `tiens`. ⌫ → `tiên`.

The state after the toggle still has `dauMu = .muUp`. The normal pop path then sees a valid syllable, so it leaves raw mode and shows the circumflex again. The fix for #3 makes the screen `tiêns`, and the fix for #2 makes ⌫ give `tiên`, which then matches the screen. No separate change is needed.

## 6. [Low] Spelling check off: digit drops the tone

`as1` → `a1`. This only happens with spelling check off: `conLai` is not empty, `rawResult` hits the "digit suffix" rule, and `.toggleToRaw` then has the cause from #3. With #3 fixed the result is `á1`. Apart from this case, the Telex digit-suffix rule (`Telex.swift:131-133`) is never reached, because a digit always lands in `conLai` and triggers recovery first.

## 7. [Low] Mixed-case double vowel

`Telex.swift:84-85` checks `char` and `char.uppercased()`. If `char` is already uppercase, both checks look for `"A"`, so `aA` → `aA` (`Aa` → `Â` works). Compare lowercased instead, as `isOeo` on the line above already does.

## 8. [Low] Circumflex placed on the wrong vowel

`apDungDauMu` (`TiengVietTransformer.swift:105-114`) puts `.muUp` on the first vowel that can take it and ignores which key was doubled: `hoaa` → `hôa`, `oee` → `ôe`, `chaoo` → `châo`. None of these are Vietnamese, but with spelling check on they should recover, not produce nonsense. Either pass the target letter (`a`/`e`/`o`) into the state, or add the open-nucleus check from #10.

## 9. [Low] Horn on u flickers away

After `t u w o`, the screen shows `tuơ`. The transformer horns both vowels only when there are 3 vowels or a final (`TiengVietTransformer.swift:98-104`). This is so that `thuở`/`huơ` come out right. It means the user sees the horn they just typed disappear, and an extra replacement is sent. To fix it, record that the `u` was horned explicitly, for example with a `hornOnU` flag on the state or by storing `dauMu` per vowel. That flag would also make #1 cleaner.

## 10. [Low] Validator is lenient

- Open syllables are never checked. `ôa`, `ôe`, `âo`, `ưy` and `ơa` pass, and so does `mỏe` (English "more").
- Onset rules are not checked: `q` without `u`, `k`/`gh`/`ngh` before a/o/u, `c`/`g`/`ng` before e/ê/i.
- An unknown nucleus allows every final (`isValidVowelEnding` fallback, `:181-183`), so for example `oeng` is accepted.

Each of these could improve English recovery, but each also risks rejecting a loanword. The corpus and `EnglishRecovery` tests are the safety net. Add them one rule at a time.

## 11. [Info] Telex `d` anywhere

`Telex.swift:58-62` turns any `d` into a đ-marker when the word starts with `d`, so `dad` → đa and `did` → đi. This is UniKey-compatible free-style typing, but it makes English harder. Consider an option, or only accept it when the `d` comes right after the first `d` or after the nucleus.

## 12. Dead code and cleanup

- `TypingMethodResult.noChange` is never produced, but it is still handled (`TypingMethod.swift:74`, `InputProcessor.swift:156`).
- `ThanhPhanTieng.notTiengViet()` and `viTriDauThanh` (written but never read), and `TiengViet.ChuCai` / `ChuCaiThuong`, are unused.
- `TiengVietState._cachedThanhPhan` is always non-nil, so the optional and the `?? parse(...)` fallback are dead.
- `TiengVietValidator.ValidPhuAmCuoi` duplicates `TiengViet.PhuAmCuoi`.
- The toggle rules work backwards from raw `keyStr` suffixes (`dropLast(2).contains("a")`). That is an approximation of "the previous key applied this same mark". Storing the last applied mark key in the state would replace the guessing and make #1 and #3 easier to get right.
- Performance is not a concern: about 10 characters per word, one reparse per key. `NguyenAmUO.contains { $0.lowercased() == … }` allocates strings on every key and could be a `Set` lookup on the lowercased string, but this is cosmetic.

---

## Suggested tests

- Corpus: also encode `ươ` as `uwow` / `u7o7`, and as `uwo…w` with the mark after the final.
- Assert `dduwowcj` == `được` directly instead of comparing two configs.
- Backspace in recovery: `texting⌫`, `based⌫`, `based⌫⌫`, `tieenss⌫`. Use a screen simulator that applies `Replacement`s rather than reading `wordBuffer.transformed`, because the bug is in the diff the user actually sees.
- Cancel keeps other marks: `tieenss` → `tiêns`, `dduowngff` → `đươngf`, VNI `d9uo7ng22` → `đương2`.
- English recovery: add `text`, `next`, `texts`.

## Suggested order

1. #1 horn double-tap (high impact for Vietnamese users, small change, plus tests).
2. #2 and #3 together. Both are in `WordBuffer`, and #5 and #6 are fixed along the way.
3. #4 tone + stop-final rule.
4. The low items and cleanup as time allows.
