import json

cur = gnubg.match(statistics = 0, verbose = 1)
cur["positionId"] = gnubg.positionid()
cur["cube"] = gnubg.cubeinfo()


print(json.dumps(cur))