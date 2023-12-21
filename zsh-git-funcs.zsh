###
# Print the final gitstatus prompt to stdout
# Arguments:  $1 -i, if it's an inline prompt => add a whitespace at the end, if
#                not empty
###
function gitstatus()
{
    is_in_git_repository || return 1

    parse_git_status
    local modified="${STATUS[1]}"
    local staged="${STATUS[2]}"
    local deleted="${STATUS[3]}"
    local untracked="${STATUS[4]}"
    unset STATUS

    git_grab_current_branch
    local branch="$REPLY"

    git_grab_remote_branch
    local remote="$REPLY"

    [[ ! -z "$remote" ]] \
        && git_local_remote_diffs "$branch" "$remote" \
        && local commit_diffs="$REPLY"

    if [[ $(echo ${branch} | grep \/) ]]; then
        branch=$(echo ${branch} | sed 's/\// /' | awk '{print substr($1,1,2)"/"$2}')
    fi
    if (( ${#branch} > 30 )); then  
        branch="${branch:0:15}…${branch:${#myarray[@]}-10}"
    fi

    (( modified > 0 )) \
        && modified=" !$modified"
    (( staged > 0 )) \
        && staged=" +$staged"
    (( deleted > 0 )) \
        && deleted=" -$deleted"
    (( untracked > 0 )) \
        && untracked=" ?$untracked"

    local output=" %F{cyan} $branch"
            output+="%F{blue}$commit_diffs%f"
            output+="%F{yellow}$modified%f"
            output+="%F{green}$staged%f"
            output+="%F{red}$deleted%f"
            output+="%F{yellow}$untracked%f"

    local true_output="$(sed 's/[ \t]*$//' <<<"$output")" # remove trailing whitespace

    if [[ "$1" == "-i" ]]; then
        true_output+=" "
    fi

    true_output+=$'%F{default}'
    echo "${true_output}"

    unset REPLY
}

###
# Check if we're in a git repository
# Arguments:    none
# Returns:      0 if in a git repo, 1 otherwise
###
function is_in_git_repository()
{
    git rev-parse --git-dir &>/dev/null || return 1
}

###
# Return current branch we're on
# Arguments:    none
###
function git_grab_current_branch()
{
    local branch="$(git branch --show-current)"
    typeset -g REPLY="${branch}"
}

###
# Return remote branch that the local one is tracking
# Arguemnts: none
###
function git_grab_remote_branch()
{
    local symbolic_ref="$(git symbolic-ref -q HEAD)"
    typeset -g REPLY="$(git for-each-ref --format='%(upstream:short)' "$symbolic_ref")"
}

###
# Find how many things have changed since last git commit
# Arguments:    none
###
function parse_git_status()
{
    git status --porcelain=v1 | while IFS= read -r status_line; do
        case "$status_line" in
            ' M '*)
                ((modified++))
                ;;
            'A  '*|'M '*)
                ((staged++))
                ;;
            'D  '*|' D '*)
                ((deleted++))
                ;;
            '?? '*)
                ((untracked++))
                ;;
            'MM '*)
                ((staged++))
                ((modified++))
                ;;
        esac
    done

    typeset -g STATUS=("$modified" "$staged" "$deleted" "$untracked")
    return 0
}

###
# Look at how many commits a local branch is ahead/behind of remote branch
# Arguments:    $1 local branch
#               $2 remote branch
###
function git_local_remote_diffs()
{
    local local_branch="$1"
    local remote_branch="$2"

    local differences="$(git rev-list --left-right --count $local_branch...$remote_branch)"
    local commits_ahead=$(echo -n "$differences" | awk '{print $1}')
    local commits_behind=$(echo -n "$differences" | awk '{print $2}')
    local ahead="" behind=""

    local result=""

    (( $commits_ahead > 0 )) \
        && ahead="↑$commits_ahead"
    (( $commits_behind > 0 )) \
        && behind="↓$commits_behind"

    if [[ ! -z "${ahead}" ]]; then
        result=" ${ahead}"
    fi

    if [[ ! -z "${behind}" ]]; then
        result=" ${behind}"
    fi

    typeset -g REPLY="${result}"
}

function fzf-git-branch() {
    git rev-parse HEAD > /dev/null 2>&1 || return

    git branch --color=always --all --sort=-committerdate |
        grep -v HEAD |
        fzf --height 50% --ansi --no-multi --preview-window right:65% \
            --preview 'git log -n 50 --color=always --date=short --pretty="format:%C(auto)%cd %h%d %s" $(sed "s/.* //" <<< {})' |
        sed "s/.* //"
}

# open up an fzf window with available git branches allowing you to select one
function fzf-git-checkout() {
    git rev-parse HEAD > /dev/null 2>&1 || return

    local branch

    branch=$(fzf-git-branch)
    if [[ "$branch" = "" ]]; then
        echo "No branch selected."
        return
    fi

    # If branch name starts with 'remotes/' then it is a remote branch. By
    # using --track and a remote branch name, it is the same as:
    # git checkout -b branchName --track origin/branchName
    if [[ "$branch" = 'remotes/'* ]]; then
        git checkout --track $branch
    else
        git checkout $branch;
    fi
}

