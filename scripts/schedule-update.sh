#!/usr/bin/env bash
# Schedules update.sh as a cron job.
#
# Usage:
#   ./schedule-update.sh <number><h|d>
#
# Examples:
#   ./schedule-update.sh 6h    # every 6 hours
#   ./schedule-update.sh 1d    # every day (at midnight)
#   ./schedule-update.sh 2d    # every 2 days (at midnight)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_SCRIPT="$SCRIPT_DIR/update.sh"

usage() {
    echo "Usage: $0 <interval>"
    echo "  interval: a number followed by 'h' (hours) or 'd' (days)"
    echo "  Examples: 6h, 12h, 1d, 7d"
    exit 1
}

[[ $# -ne 1 ]] && usage

INPUT="$1"
VALUE="${INPUT%[hHdD]}"
UNIT="${INPUT: -1}"

if ! [[ "$VALUE" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: interval value must be a positive integer (got: '$VALUE')"
    usage
fi

case "$UNIT" in
    h|H)
        if (( VALUE > 23 )); then
            echo "Error: hour interval must be 1–23 (got: $VALUE). Use days for longer intervals."
            exit 1
        fi
        CRON_EXPR="0 */$VALUE * * *"
        HUMAN="every ${VALUE} hour(s)"
        ;;
    d|D)
        if (( VALUE > 365 )); then
            echo "Error: day interval must be 1–365 (got: $VALUE)."
            exit 1
        fi
        if (( VALUE == 1 )); then
            CRON_EXPR="0 0 * * *"
        else
            CRON_EXPR="0 0 */$VALUE * *"
        fi
        HUMAN="every ${VALUE} day(s) at midnight"
        ;;
    *)
        echo "Error: unit must be 'h' (hours) or 'd' (days) (got: '$UNIT')"
        usage
        ;;
esac

CRON_JOB="$CRON_EXPR $UPDATE_SCRIPT >> /var/log/hf-gateway-update.log 2>&1"
MARKER="# hf-gateway auto-update"

# Remove any existing hf-gateway auto-update entry, then add the new one.
( crontab -l 2>/dev/null | grep -v "$MARKER" ; echo "$CRON_JOB $MARKER" ) | crontab -

echo "Scheduled: $HUMAN"
echo "Cron entry: $CRON_JOB $MARKER"
echo ""
echo "To remove: crontab -e  (delete the line containing '$MARKER')"
echo "To view:   crontab -l"
