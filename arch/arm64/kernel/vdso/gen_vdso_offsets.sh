#!/bin/sh
LC_ALL=C
export LC_ALL

awk '
$NF ~ /^VDSO_/ {
    symbol = $NF
    sub(/^VDSO_/, "", symbol)

    address = $1
    sub(/^0+/, "", address)
    if (address == "")
        address = "0"

    print "#define vdso_offset_" symbol " 0x" address
}'
