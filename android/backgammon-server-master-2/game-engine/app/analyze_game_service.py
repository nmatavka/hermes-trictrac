import glob
import os
import re
import shutil
import subprocess
from typing import Iterable


def analyze(request):
    path = str("/tmp/" + str(request["matchId"]) + ".sgf")
    analyze_path = path + ".txt"
    if os.path.exists(path):
        return read_analysis(get_paths(path), len(request["games"]))

    if os.path.exists(path):
        os.remove(path)

    with open(path, 'w', encoding="utf-8") as file:
        for i, game in enumerate(request["games"]):
            threshold = game["thresholdPoints"]
            if threshold == 1:
                allow_cube = False
            elif i == 0:
                allow_cube = True
            else:
                last_game = request["games"][i - 1]
                last_game_end_event = last_game["items"][-1]
                allow_cube = not (
                        (last_game_end_event["white"] == threshold - 1 and last_game_end_event["winner"] == "WHITE") or
                        (last_game_end_event["black"] == threshold - 1 and last_game_end_event["winner"] == "BLACK")
                )
            if i == 0:
                end_game_event = {"type": "GAME_END", "white": 0, "black": 0}
            else:
                end_game_event = game["items"][-1]
            convert_game_and_write(game, file, allow_cube, end_game_event)

    engine_analyze(path, analyze_path)
    return read_analysis(get_paths(path), len(request["games"]))


def get_paths(path):
    return sorted(i for i in glob.glob(f"{path}*") if i != path)


def convert_game_and_write(request, file, allow_cube, end_game_event):
    items = request["items"]
    turn = "B" if request["firstToMove"] == "BLACK" else "W"
    if end_game_event["type"] == "GAME_END":
        ws = end_game_event["white"]
        bs = end_game_event["black"]
        length = request["thresholdPoints"]
        items = items[:-1]
    else:
        ws = 0
        bs = 0
        length = 3
    game_id = request["gameId"]
    file.write(
        f"(;FF[4]GM[6]AP[GNU Backgammon]MI[length:{length}][game:{game_id}][ws:{ws}][bs:{bs}]PW[WHITE]PB[BLACK]DT[2025-04-30]CO[{'c' if allow_cube else 'n'}]\n")
    for item in items:
        file.write(";")
        item_type = item["type"]
        if item_type == "MOVE":
            dice = item["dice"]
            moves = item["moves"]
            file.write(f"{turn}[{dice[0]}{dice[1]}{convert_moves_to_sgf_notation(moves)}]\n")
            turn = "B" if turn == "W" else "W"
        elif item_type == "OFFER_DOUBLE":
            file.write(f"{turn}[double]\n")
            turn = "B" if turn == "W" else "W"
        elif item_type == "ACCEPT_DOUBLE":
            file.write(f"{turn}[take]\n")
            turn = "B" if turn == "W" else "W"
    file.write(")\n")


def engine_analyze(game_path, analyze_path):
    gnubg_commands = f"""
    load match {game_path}
    analyze match 
    export match text {analyze_path}
    quit
    """
    # Запускаем gnubg как подпроцесс с передачей команд через stdin
    gnubg_path = shutil.which("gnubg")
    process = subprocess.Popen(
        [gnubg_path],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        shell=True,
        text=True
    )

    # Посылаем команды и ждем завершения
    stdout, stderr = process.communicate(gnubg_commands)

    # Проверяем результат
    if process.returncode != 0:
        print(f"Ошибка при выполнении gnubg: {stderr}")
        return


def convert_moves_to_sgf_notation(moves):
    def convert(x):
        return chr(x + ord('a') - 1)

    chars = []
    for move in moves:
        move_from = move["from"]
        if move_from == 0 or move_from == 25:
            move_from = ord('y') + 1 - ord('a')
        move_to = move["to"]
        if move_to == -1 or move_to == 26:
            continue
        if move_to == 0 or move_to == 25:
            move_to = ord('z') + 1 - ord('a')
        chars.append(f"{convert(move_from)}{convert(move_to)}")
    return "".join(chars)


def split_without_empty(line):
    return [i for i in line.split("  ") if i]


def read_analysis(paths: Iterable[str], games_count):
    current_game = 0
    data_by_game = [{"items": [], "overall": []} for _ in range(games_count)]
    overall_match = dict()
    for path in paths:
        move_data = None
        stage = None
        rolled_block = None
        with open(path, 'r', encoding='utf-8') as file:
            print(f"path:{path}, current_game:{current_game}")
            for line in file:
                line = line.strip()
                line = ";".join(i.strip() for i in line.split("  ") if i.strip() != "")
                if len(line) == 0:
                    continue
                if line.startswith("Pip counts:"):
                    line = line.replace("Pip counts:", "")
                    split = line.split(",")
                    white = split[0].strip()
                    black = split[1].strip()
                    move_data["pip_counts"]["white"] = int(white[1:])
                    move_data["pip_counts"]["black"] = int(black[1:])
                    continue

                if line.startswith("Move number"):
                    if move_data:
                        move_data["cube"] = move_data["cube"][2:]
                        data_by_game[current_game]["items"].append(move_data)
                    move_data = {
                        "rolled": None,
                        "best_moves": [],
                        "alerts": [],
                        "cube": [],
                        "pip_counts": dict()
                    }
                    stage = "READ_MOVE"
                    # if stage == "READ_MOVE" and line.startswith("*"):
                    #     move_data["move"] = line
                    continue
                if stage == "READ_MOVE" and line.startswith("Alert:"):
                    alert = parse_alert(line)
                    move_data["alerts"].append(alert)
                    continue
                if line.startswith("Cube analysis"):
                    stage = "CUBE_ANALYSIS"
                    continue
                if line.startswith("Rolled"):
                    match = find_in_parentheses(line)
                    if match:
                        move_data["rolled"] = match.group(0)[1:-1]
                    else:
                        print(f"cant find numbers:{line}")
                    stage = "ROLLED"
                    continue
                if stage == "CUBE_ANALYSIS":
                    if line.startswith("Alert:"):
                        alert = parse_alert(line)
                        move_data["alerts"].append(alert)
                        continue
                    if line.startswith("Proper cube action"):
                        continue
                    if line.startswith("Cubeful"):
                        continue
                    match = re.search('\d{1}-ply cubeless equity', line)
                    if match:
                        line = line.replace(match.group(0), "")
                        line = line.strip().split()[0]
                    if line[0].isdigit() and line[0] != '0':
                        line = line[2:]
                        match = find_in_parentheses(line)
                        if match:
                            line = line.replace(";" + match.group(0), "")
                    move_data["cube"].append(line.strip())
                    continue
                if stage == "ROLLED" and (line[0] == '*' or line[1] == '.'):
                    match = re.search("Cubeful \d{1}-ply", line)
                    if match:
                        rolled_block = line.replace(match.group(0), "").split(";")
                        asterisk = None
                        if rolled_block[0] == "*":
                            rolled_block = rolled_block[1:]
                            asterisk = "*"
                        rolled_block = rolled_block[1:]
                        rolled_block[1] = rolled_block[1].replace("Eq.:", "").strip().split()[0]
                        rolled_block = ";".join(rolled_block)
                        if asterisk:
                            rolled_block = asterisk + rolled_block
                    else:
                        if rolled_block:
                            move_data["best_moves"].append(rolled_block + ";" + line)
                        else:
                            print(f"rolled_block incomplete: {line}")
                        rolled_block = None
                    continue
                if line.startswith("Game statistics"):
                    if move_data:
                        move_data["cube"] = move_data["cube"][2:]
                        data_by_game[current_game]["items"].append(move_data)
                    move_data = None
                    stage = "GAME_STATISTICS"
                    rolled_block = None
                    continue
                if line.startswith("Match statistics"):
                    stage = "MATCH_STATISTICS"
                    continue
                if stage == "MATCH_STATISTICS":
                    if line.startswith("Moves marked") or line.startswith(
                            "Error total EMG") or line.startswith("Rolls marked") or line.startswith(
                        "Luck total EMG") or line.startswith("Missed doubles") or line.startswith(
                        "Wrong doubles") or line.startswith("Wrong takes") or line.startswith("Wrong passes"):
                        line = line.split(";")
                        first = delete_parentheses(line[1])
                        second = delete_parentheses(line[2])
                        overall_match[line[0]] = [float(first), float(second)]
                    continue
        current_game += 1
    print([len(i["items"]) for i in data_by_game])
    return {"games": data_by_game, "overall": overall_match}


def parse_alert(x):
    x = x.replace("Alert:", "").replace("!", "").replace(":", "")
    split = x.split("(")
    x = ";".join([split[0].strip(), split[1][:-1].strip()])
    return x


def find_in_parentheses(x):
    return re.search(r'\([-+.\d]+\)', x)


def delete_parentheses(x):
    match = re.search(r'\(.*\)', x)
    if match:
        x = x.replace(match.group(0), "")
    return x
