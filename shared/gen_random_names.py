import random
import namegenerator
names = set()
while len(names) < 1000000:
    names.add(namegenerator.gen())
names = list(names)
random.shuffle(names)

for name in names:
    print(name)
