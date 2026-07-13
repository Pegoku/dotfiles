#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
default_config_file="$config_home/vikunja-calendar/vikunja.conf"
legacy_config_file="$config_home/vikunja-calendar/config"
state_file="${VIKUNJA_STATE:-$state_home/vikunja-calendar/state.json}"
state_dir="$(dirname "$state_file")"
lock_file="$state_dir/state.lock"

if [[ -n "${VIKUNJA_CONFIG:-}" ]]; then
    config_file="$VIKUNJA_CONFIG"
elif [[ ! -e "$default_config_file" && -r "$legacy_config_file" ]]; then
    config_file="$legacy_config_file"
else
    config_file="$default_config_file"
fi

if [[ ! -e "$config_file" ]]; then
    umask 077
    mkdir -p "$(dirname "$config_file")"
    printf '%s\n' \
        '# Vikunja calendar integration. Keep this file private (mode 600).' \
        'VIKUNJA_URL=""' \
        'VIKUNJA_TOKEN=""' \
        '' \
        '# Optional. New tasks use the first non-archived project when set to 0.' \
        'VIKUNJA_DEFAULT_PROJECT_ID=0' > "$config_file"
    chmod 600 "$config_file"
fi

if [[ -r "$config_file" ]]; then
    # The file deliberately lives outside the dotfiles repository so API
    # tokens are never committed.
    # shellcheck disable=SC1090
    source "$config_file"
fi

vikunja_url="${VIKUNJA_URL:-}"
vikunja_token="${VIKUNJA_TOKEN:-}"
default_project_id="${VIKUNJA_DEFAULT_PROJECT_ID:-0}"
configured=false
if [[ -n "$vikunja_url" && -n "$vikunja_token" ]]; then
    configured=true
fi

for dependency in jq flock; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        printf '{"ok":false,"error":"Missing dependency: %s"}\n' "$dependency"
        exit 0
    fi
done

umask 077
mkdir -p "$state_dir"
if [[ ! -e "$state_file" ]]; then
    printf '%s\n' '{"version":1,"projects":[],"tasks":[],"outbox":[],"last_sync":"","sync_error":""}' > "$state_file"
fi
chmod 600 "$state_file"

exec 9> "$lock_file"
flock 9

if ! jq -e 'type == "object" and (.projects | type == "array") and (.tasks | type == "array") and (.outbox | type == "array")' "$state_file" >/dev/null 2>&1; then
    backup_file="$state_file.broken.$(date +%s)"
    cp "$state_file" "$backup_file"
    chmod 600 "$backup_file"
    printf '%s\n' '{"version":1,"projects":[],"tasks":[],"outbox":[],"last_sync":"","sync_error":"Local cache was invalid and has been reset"}' > "$state_file"
fi

write_state() {
    local temporary
    temporary="$(mktemp "$state_dir/state.XXXXXX")"
    jq -c '.' > "$temporary"
    chmod 600 "$temporary"
    mv "$temporary" "$state_file"
}

emit_snapshot() {
    local action="$1"
    jq -c \
        --arg action "$action" \
        --argjson configured "$configured" \
        --argjson default_project_id "${default_project_id:-0}" \
        --arg config_path "$config_file" \
        '{
            ok: true,
            action: $action,
            configured: $configured,
            projects: (.projects // []),
            tasks: (.tasks // []),
            outbox_count: ((.outbox // []) | length),
            last_sync: (.last_sync // ""),
            sync_error: (.sync_error // ""),
            default_project_id: $default_project_id,
            config_path: $config_path
        }' "$state_file"
}

set_sync_error() {
    local message="$1"
    jq -c --arg message "$message" '.sync_error = $message' "$state_file" | write_state
}

response_body=""
response_status=""
header_file=""
api_base=""

initialize_remote() {
    if [[ "$configured" != true ]]; then
        set_sync_error "Vikunja is not configured"
        return 1
    fi
    if ! command -v curl >/dev/null 2>&1; then
        set_sync_error "Missing dependency: curl"
        return 1
    fi

    api_base="${vikunja_url%/}"
    if [[ "$api_base" != */api/v1 ]]; then
        api_base="$api_base/api/v1"
    fi

    header_file="$(mktemp "${TMPDIR:-/tmp}/vikunja-calendar.XXXXXX")"
    chmod 600 "$header_file"
    printf 'Authorization: Bearer %s\nContent-Type: application/json\n' "$vikunja_token" > "$header_file"
    return 0
}

cleanup_remote() {
    if [[ -n "$header_file" ]]; then
        rm -f "$header_file"
        header_file=""
    fi
}
trap cleanup_remote EXIT

request() {
    local method="$1"
    local path="$2"
    local payload="${3:-}"
    local response
    local curl_args=(
        --silent
        --show-error
        --connect-timeout 5
        --max-time 25
        --request "$method"
        --header "@$header_file"
        --write-out $'\n%{http_code}'
    )

    if [[ -n "$payload" ]]; then
        curl_args+=(--data "$payload")
    fi

    if ! response="$(curl "${curl_args[@]}" "$api_base$path" 2>&1)"; then
        response_status="${response##*$'\n'}"
        response_body="${response%$'\n'*}"
        if [[ ! "$response_status" =~ ^[0-9][0-9][0-9]$ ]]; then
            response_body="$response"
            response_status="000"
        fi
        return 1
    fi

    response_status="${response##*$'\n'}"
    response_body="${response%$'\n'*}"
    [[ "$response_status" =~ ^2[0-9][0-9]$ ]]
}

api_error_message() {
    local fallback="$1"
    local detail
    detail="$(jq -r '.message // .error // empty' <<< "$response_body" 2>/dev/null)"
    if [[ -n "$detail" ]]; then
        printf '%s (HTTP %s): %s' "$fallback" "$response_status" "$detail"
    elif [[ "$response_status" == "000" ]]; then
        printf '%s: %s' "$fallback" "$response_body"
    else
        printf '%s (HTTP %s)' "$fallback" "$response_status"
    fi
}

paged_result='[]'

fetch_pages() {
    local route="$1"
    local kind="$2"
    local page=1
    local page_json
    local response_count
    local query_separator="?"

    if [[ "$route" == *\?* ]]; then
        query_separator="&"
    fi

    paged_result='[]'
    while (( page <= 100 )); do
        if ! request GET "$route${query_separator}per_page=100&page=$page"; then
            return 1
        fi
        if ! jq -e 'type == "array"' <<< "$response_body" >/dev/null 2>&1; then
            response_status="500"
            response_body='{"message":"Vikunja returned an unexpected response"}'
            return 1
        fi

        response_count="$(jq 'length' <<< "$response_body")"
        if (( response_count == 0 )); then
            break
        fi

        if [[ "$kind" == "projects" ]]; then
            page_json="$(jq -c 'map({id, title, hex_color, is_archived, max_permission})' <<< "$response_body")"
        else
            page_json="$(jq -c 'map(
                select(.done != true)
                | select(.due_date != null and (.due_date | startswith("0001-") | not))
                | {id, title, project_id, due_date, done, priority, hex_color}
            )' <<< "$response_body")"
        fi

        paged_result="$(printf '%s\n%s\n' "$paged_result" "$page_json" | jq -cs '.[0] + .[1]')"
        ((page++))
    done
}

sync_outbox() {
    local entry
    local operation
    local payload
    local local_id
    local task_id
    local remote_task

    while (( $(jq '.outbox | length' "$state_file") > 0 )); do
        entry="$(jq -c '.outbox[0]' "$state_file")"
        operation="$(jq -r '.op' <<< "$entry")"

        if [[ "$operation" == "create" ]]; then
            local_id="$(jq -r '.local_id' <<< "$entry")"
            payload="$(jq -c '{title, due_date}' <<< "$entry")"
            task_id="$(jq -r '.project_id' <<< "$entry")"

            if ! request PUT "/projects/$task_id/tasks" "$payload"; then
                set_sync_error "$(api_error_message "Could not create queued Vikunja task")"
                return 1
            fi

            remote_task="$(jq -c '{id, title, project_id, due_date, done, priority, hex_color}' <<< "$response_body")"
            jq -c \
                --arg local_id "$local_id" \
                --argjson remote "$remote_task" \
                '.outbox = .outbox[1:] | .tasks = [.tasks[] | if (.id | tostring) == $local_id then $remote else . end]' \
                "$state_file" | write_state
        elif [[ "$operation" == "complete" ]]; then
            task_id="$(jq -r '.task_id' <<< "$entry")"
            if ! request POST "/tasks/$task_id" '{"done":true}'; then
                set_sync_error "$(api_error_message "Could not complete queued Vikunja task")"
                return 1
            fi

            jq -c '.outbox = .outbox[1:]' "$state_file" | write_state
        else
            set_sync_error "Unknown local outbox operation"
            return 1
        fi
    done
}

sync_remote_snapshot() {
    local projects
    local tasks
    local task_route
    local now

    if ! fetch_pages "/projects" projects; then
        set_sync_error "$(api_error_message "Could not load Vikunja projects")"
        return 1
    fi
    projects="$paged_result"

    task_route='/tasks?filter=done%20%3D%20false%20%26%26%20due_date%20%3E%20%220001-01-02%22'
    if ! fetch_pages "$task_route" tasks; then
        if [[ "$response_status" == "404" ]]; then
            if ! fetch_pages "/tasks/all" tasks; then
                set_sync_error "$(api_error_message "Could not load Vikunja tasks")"
                return 1
            fi
        else
            set_sync_error "$(api_error_message "Could not load Vikunja tasks")"
            return 1
        fi
    fi
    tasks="$paged_result"
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

    printf '%s\n%s\n%s\n' "$(jq -c '.' "$state_file")" "$projects" "$tasks" \
        | jq -cs --arg now "$now" '
            .[0] as $state
            | .[1] as $projects
            | .[2] as $remoteTasks
            | ($state.tasks | map(select(._sync_state == "pending"))) as $pendingCreates
            | ($state.outbox | map(select(.op == "complete") | (.task_id | tostring))) as $pendingCompletions
            | $state
            | .projects = $projects
            | .tasks = (($remoteTasks | map(select((.id | tostring) as $id | ($pendingCompletions | index($id) | not)))) + $pendingCreates)
            | .last_sync = $now
            | .sync_error = ""
        ' | write_state
}

action="${1:-sync}"

case "$action" in
    cache)
        emit_snapshot cache
        ;;

    enqueue-create)
        local_id="${2:-}"
        project_id="${3:-0}"
        due_date="${4:-}"
        title="${5:-}"

        if [[ -z "$local_id" || ! "$project_id" =~ ^[0-9]+$ ]] || (( project_id <= 0 )) || [[ -z "$due_date" || -z "$title" ]]; then
            jq -cn --arg error "Task title, project, local ID, and due date are required" '{ok:false,error:$error}'
            exit 0
        fi

        jq -c \
            --arg local_id "$local_id" \
            --argjson project_id "$project_id" \
            --arg due_date "$due_date" \
            --arg title "$title" \
            --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
                if any(.tasks[]; (.id | tostring) == $local_id) then . else
                    .tasks += [{
                        id: $local_id,
                        title: $title,
                        project_id: $project_id,
                        due_date: $due_date,
                        done: false,
                        priority: 0,
                        hex_color: "",
                        _sync_state: "pending"
                    }]
                    | .outbox += [{
                        op: "create",
                        local_id: $local_id,
                        title: $title,
                        project_id: $project_id,
                        due_date: $due_date,
                        created_at: $created_at
                    }]
                end
            ' "$state_file" | write_state
        emit_snapshot enqueue-create
        ;;

    enqueue-complete)
        task_id="${2:-}"
        if [[ -z "$task_id" ]]; then
            jq -cn --arg error "Task ID is required" '{ok:false,error:$error}'
            exit 0
        fi

        if [[ "$task_id" == local-* ]]; then
            jq -c --arg task_id "$task_id" '
                .tasks = [.tasks[] | select((.id | tostring) != $task_id)]
                | .outbox = [.outbox[] | select(.op != "create" or .local_id != $task_id)]
            ' "$state_file" | write_state
        else
            jq -c --arg task_id "$task_id" --arg created_at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
                .tasks = [.tasks[] | select((.id | tostring) != $task_id)]
                | if any(.outbox[]; .op == "complete" and (.task_id | tostring) == $task_id) then . else
                    .outbox += [{op:"complete", task_id:($task_id | tonumber), created_at:$created_at}]
                  end
            ' "$state_file" | write_state
        fi
        emit_snapshot enqueue-complete
        ;;

    fetch|sync)
        if ! initialize_remote; then
            emit_snapshot sync
            exit 0
        fi
        if ! sync_outbox; then
            emit_snapshot sync
            exit 0
        fi
        sync_remote_snapshot || true
        emit_snapshot sync
        ;;

    *)
        jq -cn --arg error "Unknown Vikunja calendar action: $action" '{ok:false,error:$error}'
        ;;
esac
