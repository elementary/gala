# Simple script to remove mutter version blocks from vala files up to the specified version.
#
# For example for a block
#
# #if HAS_MUTTER44
# ...
# #else
# ...
# #endif
#
# and a specified version of 44 or higher only the code between #if and #else will be kept.

import os
import re
import sys

class MutterBlock:
    def __init__(self):
        self.skip_block = False
        self.discard = False
        self.keep_endif = False


def remove_mutter_blocks(file_path, version):
    print ("Removing mutter blocks from file: " + file_path + " for version: " + str(version))

    with open(file_path, 'r') as file:
        lines = file.readlines()

    output_lines = []
    blocks = [MutterBlock()]
    version_pattern = re.compile(r'(#if|#elif) (!)?HAS_MUTTER(\d+)')

    for line in lines:
        if line.startswith("#if"):
            blocks.append(MutterBlock())

        if version_pattern.match(line):
            match = version_pattern.match(line)

            current_version = int(match.group(3))
            if current_version <= version:
                if not blocks[-1].skip_block and match.group(2) == "!":
                    blocks[-1].skip_block = True
                    blocks[-1].discard = True
                    continue
                elif not blocks[-1].skip_block and match.group(1) == "#elif":
                    output_lines.append("#else\n")
                    blocks[-1].keep_endif = True
                elif blocks[-1].skip_block: # we are already skipping so we probably are in an #elif block with an even lower version so we can discard right away
                    blocks[-1].discard = True

                blocks[-1].skip_block = True
                continue
        elif blocks[-1].skip_block and line.strip() == '#else':
            blocks[-1].discard = not blocks[-1].discard
            continue
        elif line.strip() == '#endif':
            block = blocks.pop()
            if block.skip_block and not block.keep_endif:
                continue

        discard = False
        for b in blocks:
            if b.discard:
                discard = True
                break

        if not discard:
            output_lines.append(line)

    with open(file_path, 'w') as file:
        file.writelines(output_lines)

def remove_recursive(file_path, version):
    for file in os.listdir(file_path):
        if os.path.isdir(file_path + "/" + file) and not file.startswith(".") and not "build" in file:
            remove_recursive(file_path + "/" + file, version)
        elif file.endswith(".vala") or file.endswith(".vapi"):
            remove_mutter_blocks(file_path + "/" + file, version)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python remove_mutter_versions.py <file_path> <version>")
        sys.exit(1)

    file_path = sys.argv[1]
    version = int(sys.argv[2])

    if os.path.isdir(file_path):
        print ("Removing mutter blocks from all vala files in dir and subdirs: " + sys.argv[1] + " for version: " + sys.argv[2])
        remove_recursive(file_path, version)
    else:
        remove_mutter_blocks(file_path, version)

    print ("Done! Also don't forget to update the meson.build files, README and remove outdated vapi.")
