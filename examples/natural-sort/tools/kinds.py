"""The pairs Explorer puts the other way round, by the first characters where
the two names part (case ignored), with examples."""
import collections, sys

rows = []
for line in open(sys.argv[1], encoding='utf-8-sig'):
    if ' before  ' in line:
        a, b = line.rstrip('\n').split(' before  ')
        rows.append((a.rstrip(), b))


def kind(ch):
    if ch == '':
        return 'end'
    if ch.isdigit():
        return 'digit'
    if ch.isalpha():
        return 'letter'
    return repr(ch)


kinds = collections.Counter()
examples = collections.defaultdict(list)
for a, b in rows:
    i = 0
    while i < min(len(a), len(b)) and a[i].lower() == b[i].lower():
        i += 1
    ka, kb = kind(a[i:i + 1]), kind(b[i:i + 1])
    k = f"{ka} before {kb}"
    kinds[k] += 1
    if len(examples[k]) < 3:
        examples[k].append(f"{a}  |  {b}")
for k, n in kinds.most_common():
    print(f"{n:4}  ours: {k}")
    for e in examples[k]:
        print(f"        {e}")
