# Tee Sheet Testing Checklist

Scope note: the real backend (`golfpro-backend-main 2`) and the existing reference
web client (`Golf-Management-Software-main 2`) implement a full desktop
course-management system (40+ tee-sheet REST endpoints, blocks, squeeze times,
standby, online booking, drag-and-drop, rain checks, recurring events, activity
logs, etc). The P18 Flutter app currently implements a focused subset of that.
This checklist tests what's actually built today, separates **known bugs**
(claimed to work but broken) from **known gaps** (not built, possibly not
in-scope for a tablet POS), so testers don't waste time filing things that are
already known.

## 0. Test Setup
- [ ] Device connected (`adb devices`), app launched, logged in
- [ ] Backend reachable (`api.dev.driverpos.io`)
- [ ] At least one tee sheet configured with bookable slots today
- [ ] A test customer exists with valid 9-hole/18-hole green+cart fee pricing
- [ ] DVPayLite terminal online if testing card payment (or use cash)

## 1. Tee Sheet Grid — Core
- [ ] Tee sheet chips load; first one auto-selects
- [ ] Switching chips reloads the grid for that sheet
- [ ] Date bar prev/next arrows move by 1 day and reload the grid
- [ ] Date bar tap opens calendar picker; picking a date reloads the grid
- [ ] Time slots render with correct AM/PM times
- [ ] Empty slot shows "Tap to book"
- [ ] Booked slot shows a pill-shaped capsule card (fixed ~34dp height, fully rounded ends) — matches web's `CustomerCapsuleBox` style (fixed 2026-06-29; was previously a small 6px-radius rectangle)
- [ ] Capsule has a left hole-count badge segment (9/18) on its own background color, separate from the card body
- [ ] Capsule body shows player count + customer name (ellipsis on overflow), and a row of status icons (cart+number, handicap, rental clubs, rain check, pre-auth, prevent-no-show, online-booking) when those flags are true on the booking — verify only against pre-set backend data, app has no in-app way to set most of these flags
- [ ] Capsule background and badge colors come directly from the backend's `bgColor`/`color` fields (server-computed per status — booked/checked-in/teed-off/turn/complete/rain-check/no-show/no-show-fee each have a distinct color per `data/teesheetColor.js`) rather than a locally-guessed color
- [ ] A 5-player slot shows as full
- [ ] Blocked slot (pre-seed via backend/Postman — app has no way to create one) shows "Blocked" + red styling
- [x] **Combined/grouped (non-split) bookings now render the backend's actual percentage-based multi-status gradient** (fixed 2026-06-29) — was previously a known simplification/gap; now parsed from the `linear-gradient(to right, ...)` string the backend sends and rendered as a real Flutter `LinearGradient`, matching the web pixel-for-pixel instead of falling back to a flat guessed color.
- [ ] **Pay an existing multi-person booking in cash/card, then look at the capsule without leaving the screen** (fixed 2026-06-29 — this was the actual bug behind "checked in = paid didn't turn blue"): backend sets `checkedIn: true` on payment (`helper/transactionHelper.js`) for combined bookings, returning a `linear-gradient` `bgColor` that includes the "Checked In" blue segment. Previously the Dart hex-only parser couldn't read gradient strings and silently fell back to a generic color, so it never turned blue. Confirm now: 100%-paid capsule should render solid blue (`#6BBBFF`); partially-paid should render visually split (matching web).
- [x] **New: Info icon now opens a real "Tee Sheet Icons & Colors" legend** (fixed 2026-06-29, was "coming soon") — verify it shows all 8 status colors + 7 icon meanings, matching the canonical values in `golfpro-backend-main/data/teesheetColor.js`
- [ ] **Status icons now use the real PNG assets copied from the web repo** (fixed 2026-06-29) — cart, handicap, rental clubs, rain check, pre-auth, prevent-no-show, online-booking icons should look identical to web, not generic Material icon substitutes. Verify in both the capsule itself and the legend modal.
- [ ] **Split-sibling connector**: book with Split Shot checked and 2+ named players — each gets their own capsule (same as before), but now a small green dot-line-dot connector should render between adjacent capsules that share the same `groupId`, matching the web's `TeeSheetConnections.jsx`. **Known simplification**: only connects siblings that land in the *same row* (same time slot) — the web also draws connectors across different time-slot rows for larger multi-slot group bookings; that cross-row case is not implemented (would need a full-grid overlay, not just per-row).
- [ ] Search bar filters visible rows by customer name or time (current date only)
- [ ] Toolbar Notes / Toggle Back / Side By Side buttons visually highlight on tap (no functional effect — see Known Gaps)
- [ ] Info / Print icons show a "coming soon" toast on tap (fixed 2026-06-29 — were previously silently dead)
- [ ] Back 9 column renders next to Front (fixed 2026-06-29); empty Back cells show "—" and are not tappable (derived from other bookings' turn time, not independently bookable); non-empty Back cells open the existing-booking view for that group

## 2. New Booking (Tee Times tab)
- [ ] **Multiple separate bookings in one slot** (fixed 2026-06-29): book 1 customer + 3 guests (persons=4) in a slot — the capsule should only occupy part of the row (proportional to player count: 1→25%, 2→50%, 3→75%, 4+→full, matching the web's column-span logic), leaving the rest tappable. Tap the remaining empty space — it must open a **new, empty** booking form (not the existing booking) for the leftover capacity. Book a 2nd separate customer there. Confirm both bookings now show as two distinct capsules in the same row, each independently editable by tapping only that capsule.
- [ ] Tapping directly on an existing capsule opens *only that booking's* detail (not merged with other bookings in the same row)
- [ ] If a row's total is already 5/5, there is no empty/tappable gap left (matches web — capsule widths sum to the full row)
- [ ] Tap empty slot opens modal with correct date/time in header
- [ ] Modal holds the slot over socket on open, releases on close/cancel
- [ ] Persons dropdown 1–5; Holes dropdown reflects the tee sheet's configured holes
- [ ] Cart One / Cart Two free-text fields accept input
- [ ] Per-split dropdown changes personPerSlot
- [ ] Customer search-by-name returns matches with phone number; selecting fills name/phone/membership
- [ ] "Add More" adds another independently-searchable player row
- [x] Cart icon toggle per player works and affects pricing (cartNeeded). **Fixed 2026-06-29**: the capsule's cart icon was gated on `assignedCart` (the optional cart-name text from Cart One/Cart Two fields) instead of the actual `carts` count the backend computes from `cartNeeded` — so toggling "cart needed" without also typing a cart name/number left the icon hidden even though the backend correctly recorded the cart. Now gated on `carts > 0`, matching web (`booking?.carts`), with `assignedCart` only used for the optional accompanying label text.
- [x] **New: Rental Clubs and Handicap toggles per player** (added 2026-06-29) — two new icon toggles next to the existing cart toggle in each player row, using the real PNG assets. Toggling either sends `handicap`/`rentalClubs` booleans in the booking payload (both create and Update), and the capsule's corresponding icon should appear on the tee sheet grid after saving.
- [ ] "Split Shot" checkbox toggles `split` in the booking payload — now actually sent to the backend (fixed 2026-06-29; was silently dropped before)
- [ ] Notes textarea accepts text and is now sent to the backend on Reserve (fixed 2026-06-29)
- [ ] Cart One / Cart Two text is now sent to the backend on Reserve (fixed 2026-06-29; was silently dropped before, same bug class as Notes)
- [ ] Reserve creates booking, shows confirmation snackbar, grid refreshes
- [ ] Reserve & Pay creates booking then opens Checkout with correct total/subtotal/tax
- [ ] Validation: Reserve with zero named customers shows "Add at least one customer"
- [ ] Validation: Persons < number of named customers shows an error
- [ ] Guest-fill: Persons > named customers bills the remainder as "Guest Customer" — verify checkout total math

## 3. Existing Booking
- [ ] **Opening an existing booking no longer emits a pending-reservation hold over the socket** (fixed 2026-06-29) — only opening a brand-new/empty booking does. Matches the web (`handleBookedCustomerHandler` passes a no-op `triggerTeesheetEvent` and never calls `emitPendingTeesheet`). Verify via debug logs: editing should show no `[Socket] Emitted /pendingReservation isPending=true` line; only genuinely-new bookings should.
- [ ] Tapping a booked slot loads persons/holes/cart/split/player rows correctly
- [ ] Notes pre-fill from the saved booking (fixed 2026-06-29)
- [ ] Existing booking now shows "Update" and "Pay" (Update replaces the old "Close" button — fixed 2026-06-29; header X icon still closes the modal)
- [ ] **Update**: change holes/cart one/cart two/notes/split, add a player via "Add More", or toggle cart-needed on an existing player, then tap Update — grid + reopened detail reflect the change
- [ ] **Update**: removing all named customers and tapping Update shows "Add at least one customer" (use per-player Delete instead to remove a single player from a live booking)
- [ ] **Update — known limitation**: if you change Holes during an update, already-booked players keep their previously-computed green/cart fee (only newly-added players get fresh fee computation for the new holes) — re-pricing existing players on a holes change is not implemented
- [ ] Per-player Delete removes that player only, grid refreshes
- [ ] Per-player No Show marks red/strikethrough, grid refreshes
- [ ] Pay (unpaid players only) opens Checkout with the correct combined total, excluding already-Paid players

## 4. Real-time / Socket Behavior
- [ ] Two sessions on the same tee sheet+date: a booking made on A appears on B without manual refresh
- [ ] Opening the same slot on two devices at once — B shows no "held by another user" indicator or countdown (known gap vs web, which shows a live MM:SS countdown)
- [ ] Toggling airplane mode and back: socket auto-reconnects (`[Socket] Reconnected` in logs)
- [ ] Login screen socket status badge reflects Connected/Disconnected/Error correctly

## 5. Payments (tee-sheet-triggered)
- [ ] Reserve & Pay / Pay with cash completes and returns to the tee sheet
- [ ] Reserve & Pay / Pay with card completes and returns to the tee sheet
- [ ] Reopening a paid slot shows the player(s) marked Paid

---

## Known Bugs Found This Session (2026-06-29, 2nd follow-up round) — Fixed
- [x] **The new-booking leftover-space tap target from the previous fix didn't actually register taps.** A `GestureDetector` wrapping a colorless/childless `SizedBox.expand()` never receives hits under Flutter's default `deferToChild` behavior (a classic Flutter gotcha — hit-testing checks whether the child painted/registered a hit, not just geometric bounds). In practice this meant tapping the "empty" half of a partially-filled slot did nothing, and an imprecise tap near the boundary would land back on the adjacent existing-booking capsule instead — which is what looked like "it still opens the existing 2 names." Fixed: added `behavior: HitTestBehavior.opaque` to that `GestureDetector` (and to the full-empty-slot "Tap to book" one, which had the same latent issue), and gave the leftover-space target a visible bordered "+" so it's unmistakable which area starts a new booking vs. which opens an existing one. Verified the underlying data was never the problem — direct DB check of the 2026-06-29 6:50AM slot confirmed exactly one booking (2 customer docs, same slotId/groupId, persons=2), with 3 seats of room for a second independent booking.

## Known Bugs Found This Session (2026-06-29 follow-up round) — Fixed
- [x] **Tapping a partially-filled slot always re-opened the existing booking, with no way to add a separate new booking to the same slot.** The web (`ShowFrontTeeSheetData.jsx`) gives each booking capsule its own click target sized proportionally to its player count (`customerCount`: 1→6/24 width, 2→12/24, 3→18/24, 4+→full), and the row's remaining empty space is a *separate* click target that always opens a brand-new booking. The Flutter app wrapped the whole front/back content area in one tap target that, once any booking existed, always resolved to "edit existing" — there was no way to start a second independent booking (e.g. a separate "Tuhin + guest" alongside an existing "Maulik + guest") in the same slot. Fixed: `_TeeTimeRow` now builds one tap target per existing capsule (proportional width, opens that one booking only) plus a leftover-space tap target (opens an empty new-booking form) when the slot isn't full. Also removed the row-level `InkWell` that wrapped the whole row (it has no web equivalent — Time column has no click behavior — and would have conflicted with the new per-segment tap targets).

## Known Bugs Found This Session — Fixed 2026-06-29
- [x] **Notes were silently discarded.** Fixed: `_saveBooking()`/`_updateBooking()` now send `notes`; `_loadDetail()` restores `detail.notes` into the field.
- [x] **Cart One/Cart Two/Split were also silently discarded on new bookings** (same root cause as Notes, found while fixing it). Fixed: now sent in `_saveBooking()`.
- [x] **Back 9 was fetched but never shown.** Fixed: grid now renders a Back column next to Front. Empty Back cells are display-only (not independently bookable — derived from other bookings' computed turn time), non-empty ones open that group's existing-booking view.
- [x] **No update path for existing bookings.** Fixed: added an "Update" button (replaces the old plain "Close" button) that calls `updateSlotCustomers()` with the current holes/cart/notes/split/players. Re-test per the limitation noted in section 3 (fee re-pricing on holes change for already-booked players is not implemented).
- [x] **Toolbar Info/Print icons had no tap handler.** Fixed: now show a "coming soon" toast so taps aren't silently swallowed.
- [ ] **Toolbar Notes/Toggle Back/Side By Side buttons are still inert** (intentionally left as-is — they already give visual highlight feedback on tap, and building real toggle-view/notes-modal behavior is a feature addition, not a bug fix; out of scope for this round).

## Legend Item Audit (Tee Sheet Icons & Colors modal) — 2026-06-29
Cross-checked every color/icon in the legend against whether the P18 app can actually trigger it, not just render it. 7 of 15 are fully wired (write + read); the rest render correctly if the data has the flag, but nothing in the app can ever set that flag.

| # | Item | Trigger scenario | Status |
|---|---|---|---|
| 1 | Booked/Reserved (default) | Create any new booking, don't pay | ✅ Wired |
| 2 | Checked In (blue) | Pay via Reserve & Pay or Pay | ✅ Wired |
| 3 | Tee'd Off (green) | Web: right-click → "Tee'd Off" (needs checked-in) | ❌ No UI in P18 |
| 4 | Turn (brown) | Web: right-click → "Mark the Turn" (18-hole) | ❌ No UI in P18 |
| 5 | Rain Check (purple, color) | Web: right-click → "Issue Rain Check" modal | ❌ No UI in P18 |
| 6 | Completed (light green) | Web: right-click → "Mark as Done" | ❌ No UI in P18 |
| 7 | No Showed (red) | Tap "No Show" per player | ✅ Wired |
| 8 | No Show Fee Taken (light blue) | No-show + customer has pre-auth card on file | ⚠️ Renders correctly, practically unreachable (see #14) |
| 9 | Online Reservation icon | Customer books via the separate self-service portal | ✅ Wired by design (not a staff action) |
| 10 | Golf Cart icon | Toggle cart per player | ✅ Wired |
| 11 | Rental Clubs icon | Toggle rental clubs per player | ✅ Wired (added 2026-06-29) |
| 12 | Handicap icon | Toggle handicap per player | ✅ Wired (added 2026-06-29) |
| 13 | Rain Check icon | Same trigger as #5 | ❌ No UI in P18 |
| 14 | Pre Authorized icon | Booking made with a saved/pre-auth card | ❌ No UI in P18 to capture a pre-auth card for tee times |
| 15 | Don't Charge No Show Fee icon | Web: toolbar "Don't Charge No Show" button | ❌ No such button in P18 |

User explicitly deferred building #3, #4, #5, #6, #13, #14, #15 for now (2026-06-29) — don't file these as bugs, they're a known, accepted gap pending a future decision.

## Out of Scope for This Build (confirm intent before filing as bugs)
- Block tab and Events tab ("coming soon" placeholders); Groups tab (multi-slot group editing)
- Drag-and-drop re-ordering of bookings between slots
- Right-click context-menu actions: Split, Teed Off, Mark the Turn, Mark as Done, Issue Rain Check, Activity Log, Delete-whole-booking — see Legend Item Audit above for the precise status-flag breakdown
- Squeeze times, Stand-by/waitlist, online customer self-booking, Online Reservation Groups/Settings
- Send Alert / Send Confirmation (SMS/email), "Don't Charge No Show" toggle, "mark all no-show", pre-auth card capture
- Recurring/repeat blocks, Print-to-PDF
- Side-by-side dual tee sheet view, true 3-step Front/Back/Both toggle
- Holiday banner
