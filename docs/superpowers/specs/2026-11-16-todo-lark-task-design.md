# Todo panel: create a Lark task (with order picker)

Date: 2026-11-16

## Intent

From the quickshell todo panel, create a row in the team's Lark Base
"QUẢN LÝ CÔNG VIỆC" (`Tasks` table) without opening Lark. Every task belongs to
an order, so the flow lets the user pick an existing order or create a new one
(BU + Loại dự án required) on the spot.

## Goals

- A "Lark" button next to "Add todo" in `todo/TodoAddBar.qml`.
- Pressing it opens an order picker; confirming creates the Lark task and also
  adds the local todo (same title / note / due).
- Before creating, OpenCode reviews and rewrites the title and content from a
  prompt file the user can edit; the user sees the result in editable fields,
  can switch back to the original, and nothing is sent until they confirm by
  picking / creating an order.
- Order picker: search box, list of open orders, "+ New order" form.
- Task is assigned to Cao Trung Kiên.

## Non-goals

- Pushing an already existing local todo to Lark (no `lark_record_id` column).
- Syncing status back from Lark, editing or deleting Lark records.
- Choosing a different assignee in the UI.

## Anti-goals

- App secret must never appear in QML, logs, notifications or git.
- A failed Lark call must not lose what the user typed: the add bar keeps its
  text and the error is shown in the panel.

## Constraints / facts found

- Credentials: `todo/.env` has `LARK_APP_ID` / `LARK_APP_SECRET` (tenant token
  only, domain `https://open.larksuite.com`). "Người tạo" on Lark will be the
  bot `LangTech MCP`, not the user.
- Base app token `VSQEbM6kBaFCRbseuH6lHqFRg7f`; `Tasks` = `tblMADnsPIRSSjLw`,
  `Orders` = `tblrCCmpKOtoC9Vc`. Bot can read both. **Write access is not yet
  verified** — first implementation step creates and deletes one test record.
- Assignee open_id (taken from existing records):
  `ou_1b03372e8e9b90b13a230e94b22eed5d`.
- Date fields are millisecond timestamps at local midnight (UTC+7).
- Repo convention: shell work lives in `scripts/*.sh`, pure logic in `*Logic.js`
  covered by `tests/run.mjs`, state in `providers/*.qml`.

## Approaches

1. **Bash script + `Process` (chosen).** `scripts/lark-task.sh` (curl + jq)
   reads `.env`, QML only sees JSON. Matches the existing scripts, keeps the
   secret out of the shell process, testable from a terminal.
2. HTTP from QML (`XMLHttpRequest`). No extra process, but QML has to parse
   `.env` and hold the secret; harder to test.
3. Go through the OpenCode `lark` MCP server. Extra dependency, not running
   when the panel is used.

## Design

### Config (`todo/.env`, `.env.example`)

`LARK_BASE_APP_TOKEN`, `LARK_TASKS_TABLE`, `LARK_ORDERS_TABLE`,
`LARK_ASSIGNEE_OPEN_ID` added next to the existing two keys.

### `scripts/lark-task.sh`

Prints one JSON object on stdout: `{"ok":true,...}` or `{"ok":false,"error":"..."}`.
Tenant token cached in `$XDG_RUNTIME_DIR` (mode 600) until shortly before expiry.

- `orders` — open orders (status not `L8. Đã nghiệm thu`, not `Hủy`), newest
  first, paged until done: `[{id, title, bu, project, status}]`.
- `options` — BU and Loại dự án option names read from the `Orders` field
  definitions (`BU order`, `Loại dự án`), not hardcoded.
- `create-order <title> <bu> <project>` → `{id}`.
- `create-task <title> <note> <dateKey yyyymmdd> <orderId>` → `{id, url}`.

### Field mapping

Tasks:

| Field | Value |
|---|---|
| Công việc | todo title |
| Order | picked / newly created order (link) |
| Người thực hiện | `LARK_ASSIGNEE_OPEN_ID` |
| Ngày thực hiện | the add bar's due date; today when none is set |
| Ngày bắt đầu task | same value as Ngày thực hiện |
| Link issue | todo note (omitted when empty) |
| Kết quả cuối ngày | `Chờ code` (builder's call) |

The user only ever picks one date (the existing date picker / chips); the due
time of day is ignored for Lark.

Orders (new order form):

| Field | Value |
|---|---|
| Tiêu đề order | form field, prefilled with the todo title |
| BU order | required chip |
| Loại dự án | required chip |
| Dev phụ trách | `LARK_ASSIGNEE_OPEN_ID` |
| Ngày order | now |
| Trạng thái / Phân loại / Ưu tiên | `L4. Đang code` / `Order mới` / `Medium` (builder's call) |

### QML

- `todo/LarkLogic.js` — pure: filter orders by keyword (accent-insensitive),
  validate the new-order form, dateKey → argument. Tests in `tests/run.mjs`.
- `providers/LarkData.qml` — orders, options, `busy`, `error`; runs the script
  via `Process`; `refresh()`, `createOrder()`, `createTask()`. Registered in
  `DataProviders.qml`.
- `todo/LarkOrderPicker.qml` — search field, scrollable order list (title, BU,
  project), "+ New order" row that expands to title + BU chips + Loại dự án
  chips + "Create order". Registered in `todo/qmldir`.
- `todo/TodoAddBar.qml` — second button "Lark" beside "Add todo" (enabled when
  the title is non-empty), new signal `larkRequested(title, content, dueKey, dueMinutes)`.
- `todo/TodoPanel.qml` — third view state "lark picker" (like the detail view);
  Escape steps back to the list. On success: add the local todo, clear the add
  bar, `notify-send` with the task title. On failure: stay in the picker and
  show the error.

### New orders and the Base's own automation (found while testing)

Creating an order makes the Base's automation ("Base Assistant") add a bare task
for it (`Chờ code`, no assignee, no dates) within about a second and set the
order to `L0. Chờ tiếp nhận`. So for an order created from the panel,
`lark-task.sh create-task … --adopt`:

1. waits up to ~10 s for that task (linked to the order, no "Người thực hiện");
2. sets the order to `L4. Đang code` (user's decision: orders created from
   quickshell are L4) — after the automation ran, or it would be overwritten;
3. fills the adopted task with the title / dates / content / assignee instead
   of creating a second one; if none showed up, creates the task as usual.

Tasks under an existing order are created directly, as before.

### OpenCode review

- `scripts/lark-review.sh <title> <content>` runs `opencode run --archived`
  (no `--auto`, empty working directory, 60 s timeout) with the prompt in
  `todo/lark-review-prompt.md` plus the original text as JSON, and prints
  `{"ok":true,"title","content"}`.
- Starts automatically when the picker opens and runs while the user looks for
  an order. Advisory only: on failure or timeout the original text is used.
- The picker's title / content fields are the single source of what goes to
  Lark and into the local todo (builder's call: local todo gets the same text).
- A manual edit made before the review lands is never overwritten.
- Optional `LARK_REVIEW_MODEL` in `.env` selects the model.

## Left to the builder

- Exact layout / glyphs of the picker, following existing panel components
  (`Badge`, `IconButton`, `PanelHeader`).
- Cache lifetime of the order list (refresh on each picker open is fine).
