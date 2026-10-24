#!/data/data/com.termux/files/usr/bin/bash

# Obtain data only once to save resources
stats=$(termux-volume)

# Extract max volume
max=$(echo "$stats" | jq '.[] | select(.stream == "music") | .max_volume' 2>/dev/null)

if [[ -z "$max" ]] || [[ "$max" -eq 0 ]]; then
    # termux-volume / jq failed: don't print anything (a fake "0" would make
    # the volume popup fire)
    exit 1
fi

# ==========================================
# WRITE LOGIC (When the UI sends a value)
# ==========================================
if [[ -n "$1" ]]; then
    # decimals (e.g., 45.333) are removed so bash doesn't crash
    val="${1%.*}"

    # We convert the percentage to the cell phone range
    new_vol=$(( ( val * max + 50 ) / 100 ))

    # Safety limits
    if [[ "$new_vol" -gt "$max" ]]; then new_vol="$max"; fi
    if [[ "$new_vol" -lt 0 ]]; then new_vol=0; fi

    # We use the Termux API to change the volume
    termux-volume music "$new_vol" > /dev/null
    exit 0
fi

# ==========================================
# READ LOGIC (current volume in %)
# ==========================================
vol=$(echo "$stats" | jq '.[] | select(.stream == "music") | .volume' 2>/dev/null)

if [[ -z "$vol" ]]; then
    exit 1
fi

# calculate percentages
percent=$(( vol * 100 / max ))

echo "$percent"
