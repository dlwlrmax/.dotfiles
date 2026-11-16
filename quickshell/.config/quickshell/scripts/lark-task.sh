#!/usr/bin/env bash
# Lark Base client for the todo panel: list / create orders and create tasks in the
# "QUẢN LÝ CÔNG VIỆC" base. Credentials and ids come from ../todo/.env (gitignored).
#
# Always prints exactly one JSON object and exits 0:
#   {"ok":true,...}  or  {"ok":false,"error":"<short message>"}
#
# Usage:
#   lark-task.sh orders                      open orders, newest first
#   lark-task.sh options                     BU / Loại dự án choices of the Orders table
#   lark-task.sh assigned [id...]            tasks + orders assigned to LARK_ASSIGNEE_OPEN_ID;
#                                            of the given record ids, those deleted on Lark
#   lark-task.sh create-order '<fieldsJson>' new order   (Dev phụ trách added here)
#   lark-task.sh create-task  '<fieldsJson>' [--adopt]   new task (Người thực hiện added
#                                            here); --adopt: for an order created just now
#   lark-task.sh start <id>                  "Mark đang code" in the panel: -> Đang code
#   lark-task.sh deadline <id> <yyyymmdd>    deadline set in the panel -> Lark, if Lark has none
#   lark-task.sh finish <id>                 ticked in the panel: "Đang code" -> Chờ nghiệm thu, 100 %
#   lark-task.sh update <tasks|orders> <id> '<fieldsJson>'
#   lark-task.sh delete <tasks|orders> <id>  remove a record (smoke tests only)
#
# The field objects are built by todo/LarkLogic.js (taskFields / orderFields).

set -uo pipefail

here="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
env_file="$here/../todo/.env"
host="https://open.larksuite.com/open-apis"
token_cache="${XDG_RUNTIME_DIR:-/tmp}/quickshell-lark-token"

fail() { jq -nc --arg e "$1" '{ok:false,error:$e}'; exit 0; }

command -v jq >/dev/null || { printf '{"ok":false,"error":"jq not installed"}\n'; exit 0; }
command -v curl >/dev/null || fail "curl not installed"

# Read KEY=VALUE lines without executing the file.
declare -A cfg=()
if [ -r "$env_file" ]; then
  while IFS='=' read -r k v || [ -n "$k" ]; do
    [[ "$k" =~ ^[A-Z_][A-Z0-9_]*$ ]] || continue
    v="${v%$'\r'}"; v="${v%\"}"; v="${v#\"}"
    cfg[$k]="$v"
  done < "$env_file"
fi
for k in LARK_APP_ID LARK_APP_SECRET LARK_BASE_APP_TOKEN LARK_TASKS_TABLE LARK_ORDERS_TABLE LARK_ASSIGNEE_OPEN_ID; do
  [ -n "${cfg[$k]:-}" ] || fail "Lark not configured"
done
base="/bitable/v1/apps/${cfg[LARK_BASE_APP_TOKEN]}/tables"
tasks="${cfg[LARK_TASKS_TABLE]}"
orders="${cfg[LARK_ORDERS_TABLE]}"

TOKEN=""
RESP=""

# Tenant token, cached as "<expiryEpoch> <token>" until 5 minutes before it expires.
get_token() {
  local now exp tok resp ttl
  now=$(date +%s)
  if [ -r "$token_cache" ] && read -r exp tok < "$token_cache" \
      && [[ "$exp" =~ ^[0-9]+$ ]] && [ -n "${tok:-}" ] && (( now < exp - 300 )); then
    TOKEN="$tok"; return
  fi
  resp=$(jq -nc --arg a "${cfg[LARK_APP_ID]}" --arg s "${cfg[LARK_APP_SECRET]}" '{app_id:$a,app_secret:$s}' \
    | curl --silent --max-time 15 -X POST "$host/auth/v3/tenant_access_token/internal" \
        -H 'Content-Type: application/json; charset=utf-8' --data-binary @-) || fail "Lark unreachable"
  TOKEN=$(jq -r '.tenant_access_token // empty' <<< "$resp" 2>/dev/null) || fail "Lark unreachable"
  [ -n "$TOKEN" ] || fail "Lark auth failed"
  ttl=$(jq -r '.expire // 0' <<< "$resp")
  ( umask 077; printf '%s %s\n' "$(( now + ttl ))" "$TOKEN" > "$token_cache" )
}

# api METHOD PATH [BODY] -> response in $RESP. A rejected token is refreshed once.
api() {
  local method="$1" path="$2" body="${3:-}" attempt code
  for attempt in 1 2; do
    get_token
    if [ -n "$body" ]; then
      RESP=$(curl --silent --max-time 15 -X "$method" "$host$path" \
        -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json; charset=utf-8' \
        --data-binary @- <<< "$body") || fail "Lark unreachable"
    else
      RESP=$(curl --silent --max-time 15 -X "$method" "$host$path" \
        -H "Authorization: Bearer $TOKEN") || fail "Lark unreachable"
    fi
    code=$(jq -r '.code // empty' <<< "$RESP" 2>/dev/null) || fail "Lark unreachable"
    [ -n "$code" ] || fail "Lark unreachable"
    if [ "$attempt" = 1 ] && [[ "$code" == 99991663 || "$code" == 99991661 || "$code" == 99991668 ]]; then
      rm -f "$token_cache"
      continue
    fi
    if [ "$code" != 0 ]; then
      # SOFT=1: the caller wants to probe (e.g. "is this id in that table?").
      [ "${SOFT:-0}" = 1 ] && return 1
      fail "$(jq -r '"\(.msg // "Lark error") (\(.code))"' <<< "$RESP")"
    fi
    return 0
  done
}

# create TABLE USER_FIELD FIELDS_JSON -> record id in $RESP's data
create() {
  local table="$1" user_field="$2" fields body
  fields=$(jq -c --arg f "$user_field" --arg id "${cfg[LARK_ASSIGNEE_OPEN_ID]}" \
    'if type == "object" then {fields: (. + {($f): [{id: $id}]})} else error("not an object") end' \
    <<< "$3" 2>/dev/null) || fail "bad payload"
  body="$fields"
  api POST "$base/$table/records?user_id_type=open_id" "$body"
}

case "${1:-}" in
  orders)
    body=$(jq -nc '{
      field_names: ["Tiêu đề order", "BU order", "Loại dự án", "Trạng thái"],
      sort: [{field_name: "Ngày tạo", desc: true}],
      filter: {conjunction: "and", conditions: [
        {field_name: "Trạng thái", operator: "isNot", value: ["L8. Đã nghiệm thu"]},
        {field_name: "Trạng thái", operator: "isNot", value: ["Hủy"]}]}}')
    # Pages are collected in a file, not in argv: a long list would hit the argv limit.
    pages=$(mktemp) || fail "Lark error"
    trap 'rm -f "$pages"' EXIT
    page=""
    for _ in $(seq 1 20); do
      api POST "$base/$orders/records/search?page_size=500${page:+&page_token=$page}" "$body"
      jq -c '[.data.items[]? | {
          id: .record_id,
          title: ([.fields["Tiêu đề order"][]?.text] | join("")),
          bu: (.fields["BU order"] // ""),
          project: (.fields["Loại dự án"] // ""),
          status: (.fields["Trạng thái"] // "")}
        | select(.title | test("\\S"))]' <<< "$RESP" >> "$pages"
      [ "$(jq -r '.data.has_more // false' <<< "$RESP")" = true ] || break
      page=$(jq -r '.data.page_token // empty' <<< "$RESP")
      [ -n "$page" ] || break
    done
    jq -sc '{ok:true, orders: add}' "$pages"
    ;;
  options)
    api GET "$base/$orders/fields?page_size=100"
    jq -c 'def opts($n): [.data.items[]? | select(.field_name == $n) | .property.options[]?.name];
           {ok:true, bu: opts("BU order"), project: opts("Loại dự án")}' <<< "$RESP"
    ;;
  assigned)
    # Tasks / orders assigned to LARK_ASSIGNEE_OPEN_ID, most recently touched first
    # (one page of 200 each: enough to see new assignments and recent completions).
    me="${cfg[LARK_ASSIGNEE_OPEN_ID]}"
    body=$(jq -nc --arg me "$me" '{
      field_names: ["Công việc", "Link issue", "Ngày thực hiện", "Kết quả cuối ngày", "Ngày tạo", "Order"],
      sort: [{field_name: "Ngày cập nhật", desc: true}],
      filter: {conjunction: "and", conditions: [{field_name: "Người thực hiện", operator: "is", value: [$me]}]}}')
    api POST "$base/$tasks/records/search?page_size=200" "$body"
    def_text='def text($f): if ($f | type) == "array" then ([$f[]? | .text // ""] | join("")) else ($f // "" | tostring) end;'
    # Kept in a file: 200 tasks with long notes do not fit in one argv entry.
    t_file=$(mktemp) || fail "Lark error"
    trap 'rm -f "$t_file"' EXIT
    jq -c "$def_text"' [.data.items[]? | {
        id: .record_id, kind: "task",
        title: text(.fields["Công việc"]),
        content: text(.fields["Link issue"]),
        dateMs: (.fields["Ngày thực hiện"] // null),
        created: (.fields["Ngày tạo"] // 0),
        orderId: (.fields.Order.link_record_ids[0]? // ""),
        coding: ((.fields["Kết quả cuối ngày"] // "") == "Đang code"),
        done: ((.fields["Kết quả cuối ngày"] // "") | IN("Đã hoàn thành", "Hủy"))}]' <<< "$RESP" > "$t_file"
    body=$(jq -nc --arg me "$me" '{
      field_names: ["Tiêu đề order", "Chi tiết nội dung yêu cầu", "Trạng thái", "Ngày tạo"],
      sort: [{field_name: "Ngày tạo", desc: true}],
      filter: {conjunction: "and", conditions: [{field_name: "Dev phụ trách", operator: "is", value: [$me]}]}}')
    api POST "$base/$orders/records/search?page_size=200" "$body"
    jq -c --slurpfile tasks "$t_file" "$def_text"' {ok: true, items: ($tasks[0] + [.data.items[]? | {
        id: .record_id, kind: "order",
        title: text(.fields["Tiêu đề order"]),
        content: text(.fields["Chi tiết nội dung yêu cầu"]),
        dateMs: null,
        created: (.fields["Ngày tạo"] // 0),
        coding: ((.fields["Trạng thái"] // "") == "L4. Đang code"),
        done: ((.fields["Trạng thái"] // "") | IN("L8. Đã nghiệm thu", "Hủy"))}])}' <<< "$RESP" > "$t_file.out"
    # Extra arguments: record ids the caller still holds. Those that exist in neither
    # table any more (deleted on Lark) come back as "missing".
    shift
    missing="[]"
    ids=$(printf '%s\n' "$@" | grep -E '^rec[A-Za-z0-9]+$' | sort -u | jq -Rnc '[inputs]')
    for table in "$tasks" "$orders"; do
      [ "$ids" = "[]" ] && break
      absent="[]"
      for chunk in $(jq -c 'range(0; length; 100) as $i | .[$i:$i + 100]' <<< "$ids"); do
        api POST "$base/$table/records/batch_get" "$(jq -nc --argjson r "$chunk" '{record_ids: $r, automatic_fields: false}')"
        absent=$(jq -c --argjson a "$absent" '$a + (.data.absent_record_ids // [])' <<< "$RESP")
      done
      ids="$absent"
    done
    missing="$ids"
    jq -c --argjson m "$missing" '. + {missing: $m}' "$t_file.out"
    rm -f "$t_file.out"
    ;;
  create-order)
    create "$orders" "Dev phụ trách" "${2:-}"
    jq -c '{ok:true, id: .data.record.record_id}' <<< "$RESP"
    ;;
  create-task)
    # --adopt: the order was just created here. The Base's own automation ("Base
    # Assistant") reacts to a new order by adding a bare task for it and resetting the
    # order to L0. So: wait for that task and fill it in instead of adding a second
    # one, and only then put the order on L4 (earlier it would be overwritten).
    # No such task within ~10 s -> create one as usual.
    adopted=""
    if [ "${3:-}" = "--adopt" ]; then
      order_id=$(jq -r '.Order[0] // empty' <<< "${2:-}" 2>/dev/null) || fail "bad payload"
      [[ "$order_id" =~ ^rec[A-Za-z0-9]+$ ]] || fail "bad payload"
      find_body=$(jq -nc '{field_names: ["Order", "Người thực hiện"], sort: [{field_name: "Ngày tạo", desc: true}]}')
      for _ in 1 2 3 4 5 6 7; do
        api POST "$base/$tasks/records/search?page_size=20&user_id_type=open_id" "$find_body"
        # Unassigned = the automation's bare task. Assigned to us = an earlier attempt
        # already filled it in but its answer was lost: fill it again, never add a second.
        adopted=$(jq -r --arg o "$order_id" --arg me "${cfg[LARK_ASSIGNEE_OPEN_ID]}" 'first(.data.items[]?
            | select(((.fields.Order.link_record_ids // []) | index($o)) != null)
            | select((.fields["Người thực hiện"] // []) | (length == 0 or any(.[]; .id == $me)))
            | .record_id) // empty' <<< "$RESP")
        [ -n "$adopted" ] && break
        sleep 1.5
      done
      api PUT "$base/$orders/records/$order_id" '{"fields":{"Trạng thái":"L4. Đang code"}}'
    fi
    if [ -n "$adopted" ]; then
      body=$(jq -c --arg id "${cfg[LARK_ASSIGNEE_OPEN_ID]}" \
        'if type == "object" then {fields: (. + {"Người thực hiện": [{id: $id}]})} else error("not an object") end' \
        <<< "$2" 2>/dev/null) || fail "bad payload"
      api PUT "$base/$tasks/records/$adopted?user_id_type=open_id" "$body"
    else
      create "$tasks" "Người thực hiện" "${2:-}"
    fi
    jq -c --arg u "${cfg[LARK_BASE_URL]:-}" --arg app "${cfg[LARK_BASE_APP_TOKEN]}" --arg t "$tasks" \
      '.data.record.record_id as $id
       | {ok:true, id:$id} + (if $u != "" then {url: "\($u)/\($app)?table=\($t)&record=\($id)"} else {} end)' <<< "$RESP"
    ;;
  start)
    # "Mark đang code" in the panel: work on the record begins. Only records that have
    # not been started move; anything further along the workflow is never pulled back.
    #   task  "Chờ code" (or no status)            -> "Đang code"
    #   order L0 – L3 (or no status)               -> "L4. Đang code"
    #   and, for an order that is now L4, its "Chờ code" tasks assigned to
    #   LARK_ASSIGNEE_OPEN_ID                       -> "Đang code"
    # Prints {"ok":true,"kind":"task"|"order","changed":<records updated>,
    #         "coding":<the record itself is "Đang code" afterwards>}.
    id="${2:-}"
    [[ "$id" =~ ^rec[A-Za-z0-9]+$ ]] || fail "bad record id"
    task_coding='{"fields":{"Kết quả cuối ngày":"Đang code"}}'
    changed=0
    coding=false
    if SOFT=1 api GET "$base/$tasks/records/$id"; then
      case "$(jq -r '.data.record.fields["Kết quả cuối ngày"] // ""' <<< "$RESP")" in
        "Đang code") coding=true ;;
        "Chờ code"|"") api PUT "$base/$tasks/records/$id" "$task_coding"; changed=1; coding=true ;;
      esac
      jq -nc --argjson n "$changed" --argjson c "$coding" '{ok:true, kind:"task", changed:$n, coding:$c}'
    else
      [ "$(jq -r '.code // empty' <<< "$RESP")" = 1254043 ] \
        || fail "$(jq -r '"\(.msg // "Lark error") (\(.code))"' <<< "$RESP")"
      api GET "$base/$orders/records/$id"
      case "$(jq -r '.data.record.fields["Trạng thái"] // ""' <<< "$RESP")" in
        "L4. Đang code") coding=true ;;
        "L0. Chờ tiếp nhận"|"L1. Cần chốt mục tiêu"|"L2. Đang làm rõ yêu cầu"|"L3. Chờ lên kế hoạch code"|"")
          api PUT "$base/$orders/records/$id" '{"fields":{"Trạng thái":"L4. Đang code"}}'; changed=1; coding=true ;;
      esac
      # Its tasks only follow an order that is being coded.
      if [ "$coding" = true ]; then
        body=$(jq -nc --arg me "${cfg[LARK_ASSIGNEE_OPEN_ID]}" '{
          field_names: ["Order", "Kết quả cuối ngày"],
          sort: [{field_name: "Ngày cập nhật", desc: true}],
          filter: {conjunction: "and", conditions: [
            {field_name: "Người thực hiện", operator: "is", value: [$me]},
            {field_name: "Kết quả cuối ngày", operator: "is", value: ["Chờ code"]}]}}')
        api POST "$base/$tasks/records/search?page_size=200" "$body"
        for t in $(jq -r --arg o "$id" '.data.items[]?
            | select(((.fields.Order.link_record_ids // []) | index($o)) != null)
            | select((.fields["Kết quả cuối ngày"] // "") == "Chờ code")
            | .record_id' <<< "$RESP"); do
          api PUT "$base/$tasks/records/$t" "$task_coding"
          changed=$((changed + 1))
        done
      fi
      jq -nc --argjson n "$changed" --argjson c "$coding" '{ok:true, kind:"order", changed:$n, coding:$c}'
    fi
    ;;
  deadline)
    # A deadline was set on the todo in the panel: copy the date to Lark, but only
    # where Lark has none yet (an existing date is never overwritten).
    #   task  -> "Ngày hoàn thành task"      order -> "Ngày code xong"
    # Prints {"ok":true,"kind":"task"|"order","changed":0|1}.
    id="${2:-}"
    [[ "$id" =~ ^rec[A-Za-z0-9]+$ ]] || fail "bad record id"
    [[ "${3:-}" =~ ^[0-9]{8}$ ]] || fail "bad date"
    secs=$(date -d "$3" +%s 2>/dev/null) || fail "bad date"
    ms=$((secs * 1000))
    changed=0
    if SOFT=1 api GET "$base/$tasks/records/$id"; then
      table="$tasks"; field="Ngày hoàn thành task"; kind="task"
    else
      [ "$(jq -r '.code // empty' <<< "$RESP")" = 1254043 ] \
        || fail "$(jq -r '"\(.msg // "Lark error") (\(.code))"' <<< "$RESP")"
      api GET "$base/$orders/records/$id"
      table="$orders"; field="Ngày code xong"; kind="order"
    fi
    if [ "$(jq -r --arg f "$field" '.data.record.fields[$f] // empty' <<< "$RESP")" = "" ]; then
      api PUT "$base/$table/records/$id" "$(jq -nc --arg f "$field" --argjson d "$ms" '{fields: {($f): $d}}')"
      changed=1
    fi
    jq -nc --arg k "$kind" --argjson n "$changed" '{ok:true, kind:$k, changed:$n}'
    ;;
  finish)
    # A todo was ticked in the panel. Records that are being coded right now move to
    # "Chờ nghiệm thu" with progress 100 %; anything in another state is left alone.
    #   task  (Kết quả cuối ngày = "Đang code")  -> "Chờ nghiệm thu"
    #   order (Trạng thái = "L4. Đang code")     -> "L7. Chờ nghiệm thu", and the same
    #         for each of its "Đang code" tasks assigned to LARK_ASSIGNEE_OPEN_ID
    # Prints {"ok":true,"kind":"task"|"order","changed":<records updated>}.
    id="${2:-}"
    [[ "$id" =~ ^rec[A-Za-z0-9]+$ ]] || fail "bad record id"
    task_done='{"fields":{"Kết quả cuối ngày":"Chờ nghiệm thu","Tiến độ code":1}}'
    changed=0
    if SOFT=1 api GET "$base/$tasks/records/$id"; then
      if [ "$(jq -r '.data.record.fields["Kết quả cuối ngày"] // ""' <<< "$RESP")" = "Đang code" ]; then
        api PUT "$base/$tasks/records/$id" "$task_done"
        changed=1
      fi
      jq -nc --argjson n "$changed" '{ok:true, kind:"task", changed:$n}'
    else
      # Only "no such record" means it may be an order; any other failure is real.
      [ "$(jq -r '.code // empty' <<< "$RESP")" = 1254043 ] \
        || fail "$(jq -r '"\(.msg // "Lark error") (\(.code))"' <<< "$RESP")"
      api GET "$base/$orders/records/$id"
      if [ "$(jq -r '.data.record.fields["Trạng thái"] // ""' <<< "$RESP")" = "L4. Đang code" ]; then
        api PUT "$base/$orders/records/$id" '{"fields":{"Trạng thái":"L7. Chờ nghiệm thu","Tiến độ code":1}}'
        changed=1
      fi
      body=$(jq -nc --arg me "${cfg[LARK_ASSIGNEE_OPEN_ID]}" '{
        field_names: ["Order", "Kết quả cuối ngày"],
        sort: [{field_name: "Ngày cập nhật", desc: true}],
        filter: {conjunction: "and", conditions: [
          {field_name: "Người thực hiện", operator: "is", value: [$me]},
          {field_name: "Kết quả cuối ngày", operator: "is", value: ["Đang code"]}]}}')
      api POST "$base/$tasks/records/search?page_size=200" "$body"
      for t in $(jq -r --arg o "$id" '.data.items[]?
          | select(((.fields.Order.link_record_ids // []) | index($o)) != null)
          | select((.fields["Kết quả cuối ngày"] // "") == "Đang code")
          | .record_id' <<< "$RESP"); do
        api PUT "$base/$tasks/records/$t" "$task_done"
        changed=$((changed + 1))
      done
      jq -nc --argjson n "$changed" '{ok:true, kind:"order", changed:$n}'
    fi
    ;;
  update)
    case "${2:-}" in tasks) t="$tasks" ;; orders) t="$orders" ;; *) fail "usage: update <tasks|orders> <id> <fieldsJson>" ;; esac
    [[ "${3:-}" =~ ^rec[A-Za-z0-9]+$ ]] || fail "bad record id"
    body=$(jq -c 'if type == "object" then {fields: .} else error("not an object") end' <<< "${4:-}" 2>/dev/null) || fail "bad payload"
    api PUT "$base/$t/records/$3?user_id_type=open_id" "$body"
    jq -c '{ok:true, id: .data.record.record_id}' <<< "$RESP"
    ;;
  delete)
    case "${2:-}" in tasks) t="$tasks" ;; orders) t="$orders" ;; *) fail "usage: delete <tasks|orders> <id>" ;; esac
    [[ "${3:-}" =~ ^rec[A-Za-z0-9]+$ ]] || fail "bad record id"
    api DELETE "$base/$t/records/$3"
    printf '{"ok":true}\n'
    ;;
  *)
    fail "usage: lark-task.sh orders|options|assigned|create-order|create-task|start|deadline|finish|update|delete"
    ;;
esac
