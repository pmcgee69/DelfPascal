"""2000 distinct real file names from this machine's disks, a seeded random
sample, one per line in UTF-8: input for the natural sort's comparison with
Explorer's StrCmpLogicalW (user, 31 Oct: "Get a list of 2000 real filenames
from hdd, and test them")."""
import os, random, sys

roots = sys.argv[2:]
out = sys.argv[1]
names = set()
for root in roots:
    for dirpath, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        names.update(f for f in files if '\n' not in f and '\r' not in f)
        if len(names) > 400000:
            break
names = sorted(names)
random.seed(int(os.environ.get('SEED', '1')))      # SEED=2 for another sample
pick = random.sample(names, 2000)
with open(out, 'w', encoding='utf-8', newline='\n') as f:
    f.write('\n'.join(pick) + '\n')
digits = sum(any(c.isdigit() for c in n) for n in pick)
non_ascii = sum(any(ord(c) > 127 for c in n) for n in pick)
print(f'{len(names)} distinct names found; 2000 picked: {digits} with digits, {non_ascii} not ASCII')
print('e.g.', pick[:8])
