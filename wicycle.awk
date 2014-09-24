/^BSS / {
    w = w + 1
    printf "BSS_%i=%s\n",w,$2
}
/SSID:/ {
    printf "SSID_%i=%s\n",w,$2
}
/DS Parameter set: channel/ {
    printf "CHANNEL_%i=%s\n",w,$NF
}
/signal:/ {
    printf "SIGNAL_%i=%s\n",w,$2
}
/WPA:/ {
    printf "ENCRYPTION_%i=WPA\n",w
}
/WEP:/ {
    printf "ENCRYPTION_%i=WEP\n",w
}
END {
    printf "NETWORK_COUNT=%i\n",w
}

