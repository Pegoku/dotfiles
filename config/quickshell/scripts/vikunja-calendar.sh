#!/usr/bin/env bash

set -u

config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
default_config_file="$config_home/vikunja-calendar/vikunja.conf"
legacy_config_file="$config_home/vikunja-calendar/config"

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
    # The file is user-owned and should be mode 600. It deliberately lives
    # outside the dotfiles repository so API tokens are never committed.
    # shellcheck disable=SC1090
    source "$config_file"
fi

vikunja_url="${VIKUNJA_URL:-}"
vikunja_token="${VIKUNJA_TOKEN:-}"
default_project_id="${VIKUNJA_DEFAULT_PROJECT_ID:-0}"

emit_error() {
    jq -cn --arg message "$1" --arg config "$config_file" \
        '{ok: false, error: $message, config_path: $config}'
}

if [[ -z "$vikunja_url" || -z "$vikunja_token" ]]; then
    emit_error "Vikunja is not configured"
    exit 0
fi

for dependency in curl jq; do
    if ! command -v "$dependency" >/dev/null 2>&1; then
        emit_error "Missing dependency: $dependency"
        exit 0
    fi
done

api_base="${vikunja_url%/}"
if [[ "$api_base" != */api/v1 ]]; then
    api_base="$api_base/api/v1"
fi

header_file="$(mktemp "${TMPDIR:-/tmp}/vikunja-calendar.XXXXXX")"
chmod 600 "$header_file"
printf 'Authorization: Bearer %s\nContent-Type: application/json\n' "$vikunja_token" > "$header_file"
trap 'rm -f "$header_file"' EXIT

response_body=""
response_status=""

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
        response_body="$response"
        response_status="000"
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

        if [[ "$route" == "/projects" ]]; then
            page_json="$(jq -c 'map({
                id,
                title,
                hex_color,
                is_archived,
                max_permission
            })' <<< "$response_body")"
        else
            page_json="$(jq -c 'map(
                select(.done != true)
                | select(.due_date != null and (.due_date | startswith("0001-") | not))
                | {
                    id,
                    title,
                    project_id,
                    due_date,
                    done,
                    priority,
                    hex_color
                }
            )' <<< "$response_body")"
        fi

        paged_result="$(printf '%s\n%s\n' "$paged_result" "$page_json" | jq -cs '.[0] + .[1]')"
        ((page++))
    done
}

action="${1:-fetch}"

case "$action" in
    fetch)
        if ! fetch_pages "/projects"; then
            emit_error "$(api_error_message "Could not load Vikunja projects")"
            exit 0
        fi
        projects="$paged_result"

        task_route='/tasks?filter=done%20%3D%20false%20%26%26%20due_date%20%3E%20%220001-01-02%22'
        if ! fetch_pages "$task_route"; then
            if [[ "$response_status" == "404" ]]; then
                task_route="/tasks/all"
                if ! fetch_pages "$task_route"; then
                    emit_error "$(api_error_message "Could not load Vikunja tasks")"
                    exit 0
                fi
            else
                emit_error "$(api_error_message "Could not load Vikunja tasks")"
                exit 0
            fi
        fi
        tasks="$paged_result"

        printf '%s\n%s\n' "$projects" "$tasks" \
            | jq -cs --argjson default_project_id "${default_project_id:-0}" \
                '{ok: true, action: "fetch", projects: .[0], tasks: .[1], default_project_id: $default_project_id}'
        ;;

    create)
        project_id="${2:-0}"
        due_date="${3:-}"
        title="${4:-}"

        if [[ ! "$project_id" =~ ^[0-9]+$ ]] || (( project_id <= 0 )); then
            emit_error "Choose a Vikunja project before creating a task"
            exit 0
        fi
        if [[ -z "$due_date" || -z "$title" ]]; then
            emit_error "Task title and due date are required"
            exit 0
        fi

        payload="$(jq -cn --arg title "$title" --arg due_date "$due_date" '{title: $title, due_date: $due_date}')"
        if ! request PUT "/projects/$project_id/tasks" "$payload"; then
            emit_error "$(api_error_message "Could not create Vikunja task")"
            exit 0
        fi

        jq -cn --argjson task "$response_body" '{ok: true, action: "create", task: $task}'
        ;;

    complete)
        task_id="${2:-0}"
        if [[ ! "$task_id" =~ ^[0-9]+$ ]] || (( task_id <= 0 )); then
            emit_error "Invalid Vikunja task"
            exit 0
        fi

        if ! request POST "/tasks/$task_id" '{"done":true}'; then
            emit_error "$(api_error_message "Could not complete Vikunja task")"
            exit 0
        fi

        jq -cn --argjson task "$response_body" '{ok: true, action: "complete", task: $task}'
        ;;

    *)
        emit_error "Unknown Vikunja calendar action: $action"
        ;;
esac
