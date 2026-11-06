# Fingertip Mr Snakes

A multilevel snake game where every level is half maze and half open snake field, with a hall of fame. You play it in the browser and the game logic runs in SWI-Prolog.

* Eat every 🍎 to unlock the gate, then slither through it to reach the next level.
* Each apple makes Mr Snake one segment longer. A long snake in a tight hedge maze is the challenge.
* There are 5 levels, and each one is faster than the last. You have 3 lives.
* The top 10 scores are saved to `data/hall_of_fame.pl`.

## Run

```sh
swipl fingertipmrsnakes.pl
```

Then open <http://localhost:8080>. To use another port, run `PORT=9000 swipl fingertipmrsnakes.pl`, or call `?- server(9000).`

## Controls

| | |
|---|---|
| Arrow keys / WASD | steer |
| Q / E (or Z / X) | turn left / right, relative to the way Mr Snake is facing |
| Space | pause |
| Touch screens | swipe anywhere, or use the on-screen buttons |

## How it fits together

| File | What it does |
|---|---|
| `snake_engine.pl` | Pure game rules: move, turn, collide, get longer, eat, gate, levels, win |
| `levels.pl` | The five maps (`#` hedge, `o` food, `S` start, `E` gate) |
| `hall_of_fame.pl` | Persistent top-10 table |
| `fingertipmrsnakes.pl` | HTTP server and JSON API (`/api/new`, `/api/step`, `/api/hall`) |
| `web/index.html` | The game page: canvas drawing, keyboard, swipe and buttons |
| `specs/fingertipmrsnakes_spec.pl` | The original spec-to-algorithm examples |

The server keeps each game's state, so the hall of fame only accepts scores from games that were actually played, and only once per game.

If the page is opened without the server, for example straight from disk, it uses a JavaScript copy of the engine and keeps scores in the browser. After editing `levels.pl`, run `python3 tools/make_web.py` to rebuild `web/index.html` from `web/index.template.html` with the new maps.

## Tests

```sh
swipl -g run_tests -t halt tests/test_snakes.pl
```

The `spec_move` tests use the grids from the spec file (digits = segments with `1` as the head, `'[]'` = wall, `X` = collision). Notes on the spec:

* In test 1, the "left" and "right" examples have their labels swapped: the "left" grid moves the head to the right. The single-segment "left get longer" example also moves right. The tests keep the grids and use the label that matches the move.
* The "delete screen" block in the fingertipmrsnakes spec appears to be copied from the retromr spec, so it is not used here.
* The spec file itself has unbalanced brackets around tests 2 and 3, so it is kept as a reference and not consulted.
