# Быстрая навигация

* [Ход](#ход)
* [Получение конфига комнаты](#получение-конфига-комнаты)
* [Подключение к view по sse](#подключение-к-view)
* [Ивенты SSE](#ивенты-передающиеся-по-sse)


### Подписка на ивенты в комнате

Ходить в обход gateway (на данном этапе gateway блокирует sse)
Адрес: ```/game/backgammon/view/{gameId}```\
gameId - id комнаты\

### Ход

Доступные типы игры: SHORT_BACKGAMMON \
Адрес ```/game/backgammon/move/{gameId}```

Ход с бара эквивалентен from == null
Выбивание на бар эквивалентно тому, что первое число == null в теле ответа

gameId - id комнаты\
Тело:

```
{
    "moves": 
    [ 
        {
            "from": int?,
            "to": int?
        },
        {
            "from" : int?,
            "to": int?
        }
    ]
}
```

Возвращает:

```
{
    "moves": {
        int?: int?,
        ...
        int?: int?
    },
    "user": int (userId)
}
```

### Получение конфига комнаты

Адрес: ```/game/backgammon/сonfig/{gameId}```\
gameId - id комнаты\
Пример тела:

```
{
    "color": "WHITE",
    "turn": "BLACK",
    "bar": {
        "BLACK": 0,
        "WHITE": 0
    },
    "deck": [
        {
            "color": "BLACK",
            "count": 2,
            "id": 0
        },
        {
            "color": "WHITE",
            "count": 5,
            "id": 5
        },
        {
            "color": "WHITE",
            "count": 3,
            "id": 7
        },
        {
            "color": "BLACK",
            "count": 5,
            "id": 11
        },
        {
            "color": "WHITE",
            "count": 5,
            "id": 12
        },
        {
            "color": "BLACK",
            "count": 3,
            "id": 16
        },
        {
            "color": "BLACK",
            "count": 5,
            "id": 18
        },
        {
            "color": "WHITE",
            "count": 2,
            "id": 23
        }
    ],
    "zar": [
        3,
        1
    ]
}
```

color - твой цвет\
turn - кто ходит\
bar - инфа по бару\
deck - инфа по деке (только не пустые позиции)\
zar - инфа по кубикам

### Подключение к view

Возвращает пустое тело\
Адрес: ```/game/backgammon/view/{gameId}```\
gameId - id комнаты\

### Ивенты передающиеся по sse

* GAME_STARTED_EVENT. игра началась

```
{
    "type": "PLAYER_CONNECTED_EVENT"
}
```

* PlayerConnectedEvent. Кто-то подключился к игре (этот ивент не отправляется тому, кто подключился)\
  Body выглядит следующим образом:

```
{
    "color": "WHITE"/"BLACK",
    "type": "PLAYER_CONNECTED_EVENT"
}
```

* TossZarEvent. Кто-то бросил кубики (на данном этапе ивент отправляется всем включая создателя ивента)

```
{
    "value": IntArray
    "tossedBy": Color,
    "type": "TOSS_ZAR_EVENT"
}
```

* MoveEvent. Ивент хода (отправляется всем кроме инициатора ивента)\
  Пример body, в котором белый игрок ходит фишкой с 8 на 4 и с 4 на 1, выбивая при этом черного с позиции 1 на бар

```
{
    "moves": [
        {
            "from": 8,
            "to": 4
        },
        {
            "from": 4,
            "to": 1
        },
        {
            "from": 1,
            "to": -1
        }
    ],
    "color": "WHITE",
    "type": "MOVE_EVENT"
}
```

* EndEvent. Конец матча (отправляется всем).

```
{
    "win": Color,
    "lose": Color,
    "type": "END_EVENT"
}
```