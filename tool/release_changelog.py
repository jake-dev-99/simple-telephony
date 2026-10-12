"""Move authored Unreleased notes into a release, retaining git-log notes."""
import argparse
from pathlib import Path
import re


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('changelog', type=Path)
    parser.add_argument('version')
    parser.add_argument('commit_notes')
    parser.add_argument('--write', action='store_true')
    args = parser.parse_args()
    history = args.changelog.read_text() if args.changelog.exists() else ''
    pending = re.search(r'^## \[?Unreleased\]?[ \t]*$', history, re.MULTILINE)
    authored = ''
    if pending:
        following = re.search(r'^## ', history[pending.end():], re.MULTILINE)
        end = pending.end() + following.start() if following else len(history)
        authored = history[pending.end():end].strip()
        history = history[:pending.start()] + history[end:]
    notes = '\n\n'.join(part for part in (authored, args.commit_notes.strip())
                        if part)
    entry = f'## {args.version}\n\n{notes}\n\n'
    if args.write:
        args.changelog.write_text(entry + history)
    print(entry, end='')


if __name__ == '__main__':
    main()
