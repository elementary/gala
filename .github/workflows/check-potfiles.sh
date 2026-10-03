#!/usr/bin/env bash

missing=0
invalid=0

git ls-files | grep -E '\.(vala|desktop.in|metainfo.xml.in)$' | while read -r file; do
    if grep -q -E '\b((_|C_|N_)\(|ngettext \()' "$file"; then
        if ! grep -q "^$file$" po/POTFILES; then
            echo "Missing from POTFILES: $file"
            missing=1
        fi
    fi
done

while IFS= read -r file; do
    if [[ -z "$file" ]]; then
        continue
    fi

    if [[ ! -f "$file" ]]; then
        echo "Found in POTFILES but missing: $file"
        invalid=1
    fi
done < po/POTFILES

exit $((missing || invalid))
