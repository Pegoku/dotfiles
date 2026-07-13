#!/usr/bin/env bash

set -u

config_file="${VIKUNJA_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/vikunja-calendar/config}"

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
    local count

    paged_result='[]'
    while (( page <= 100 )); do
        if ! request GET "$route?per_page=100&page=$page"; then
            return 1
        fi

        if ! jq -e 'type == "array"' <<< "$response_body" >/dev/null 2>&1; then
            response_status="500"
            response_body='{"message":"Vikunja returned an unexpected response"}'
            return 1
        fi

        page_json="$(jq -c '.' <<< "$response_body")"
        count="$(jq 'length' <<< "$page_json")"
        if (( count == 0 )); then
            break
        fi

        paged_result="$(jq -cn --argjson accumulated "$paged_result" --argjson page "$page_json" '$accumulated + $page')"
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

        task_route="/tasks"
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

        jq -cn \
            --argjson projects "$projects" \
            --argjson tasks "$tasks" \
            --argjson default_project_id "${default_project_id:-0}" \
            '{ok: true, action: "fetch", projects: $projects, tasks: $tasks, default_project_id: $default_project_id}'
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
