/*  tests/test_snakes.pl

    Run from the repository folder:
        swipl -g run_tests -t halt tests/test_snakes.pl

    The "spec" tests use the grids from specs/fingertipmrsnakes_spec.pl:
    digits are snake segments (1 = head), '[]' is a wall, 'X' marks the
    head after a collision.
*/

:- use_module(library(plunit)).
:- use_module('../snake_engine').
:- use_module('../levels').
:- use_module('../hall_of_fame').

%   spec_move(+Command, +GridIn, -GridOut)
%   Command is the spec's text, e.g. "up", "right turn left get longer".
%   The first word is the snake's heading (or the move, for a plain move).
spec_move(Command, In, Out) :-
    split_string(Command, " ", "", Parts),
    maplist([S, A]>>atom_string(A, S), Parts, Words),
    Words = [D0|Rest],
    (   append(_, [turn, LR|_], Rest)
    ->  ( LR == left -> turn_left(D0, Dir) ; turn_right(D0, Dir) )
    ;   Dir = D0
    ),
    (   memberchk(longer, Rest) -> Grow = 1 ; Grow = 0 ),
    grid_parts(In, Snake, Walls, Size),
    advance(Snake, Dir, Walls, Size, Grow, Result),
    (   Result = ok(Snake1) -> Crash = none ; Result = crash(Crash), Snake1 = Snake ),
    parts_grid(Snake1, Walls, Size, Crash, Out).

grid_parts(Grid, Snake, Walls, W-H) :-
    length(Grid, H),
    Grid = [Row0|_],
    length(Row0, W),
    findall(N-(X-Y),
            ( nth0(Y, Grid, Row), nth0(X, Row, C), atom_number(C, N) ),
            Numbered),
    keysort(Numbered, Sorted),
    pairs_values(Sorted, Snake),
    findall(X-Y,
            ( nth0(Y, Grid, Row), nth0(X, Row, C), memberchk(C, ['[]', '#']) ),
            Walls).

parts_grid(Snake, Walls, W-H, Crash, Grid) :-
    W1 is W - 1, H1 is H - 1,
    findall(Row,
            ( between(0, H1, Y),
              findall(C, ( between(0, W1, X), cell_char(X-Y, Snake, Walls, Crash, C) ), Row)
            ),
            Grid).

cell_char(P, _, _, P, 'X') :- !.
cell_char(P, Snake, _, _, C) :- nth1(N, Snake, P), !, atom_number(C, N).
cell_char(P, _, Walls, _, '[]') :- memberchk(P, Walls), !.
cell_char(_, _, _, _, ' ').

:- begin_tests(spec_move).

test(up) :-
    spec_move("up", [[' ',' ',' '],[' ','1',' '],[' ','2',' ']], G),
    G == [[' ','1',' '],[' ','2',' '],[' ',' ',' ']].
test(down) :-
    spec_move("down", [[' ','2',' '],[' ','1',' '],[' ',' ',' ']], G),
    G == [[' ',' ',' '],[' ','2',' '],[' ','1',' ']].
%   The spec's own "left"/"right" examples in test 1 have their labels
%   swapped (the "left" example moves the head right); these use the
%   same grids with the labels the moves actually show.
test(left) :-
    spec_move("left", [[' ',' ',' '],[' ','1','2'],[' ',' ',' ']], G),
    G == [[' ',' ',' '],['1','2',' '],[' ',' ',' ']].
test(right) :-
    spec_move("right", [[' ',' ',' '],['2','1',' '],[' ',' ',' ']], G),
    G == [[' ',' ',' '],[' ','2','1'],[' ',' ',' ']].

test(up_turn_left) :-
    spec_move("up turn left", [[' ',' ',' '],[' ','1',' '],[' ','2',' ']], G),
    G == [[' ',' ',' '],['1','2',' '],[' ',' ',' ']].
test(right_turn_left) :-
    spec_move("right turn left", [[' ',' ',' '],['2','1',' '],[' ',' ',' ']], G),
    G == [[' ','1',' '],[' ','2',' '],[' ',' ',' ']].
test(right_turn_right) :-
    spec_move("right turn right", [[' ',' ',' '],['2','1',' '],[' ',' ',' ']], G),
    G == [[' ',' ',' '],[' ','2',' '],[' ','1',' ']].
test(left_turn_right) :-
    spec_move("left turn right", [[' ',' ',' '],[' ',' ',' '],[' ','1','2']], G),
    G == [[' ',' ',' '],[' ','1',' '],[' ','2',' ']].

test(left_collide_edge) :-
    spec_move("left collide", [[' ',' ',' '],['1','2',' '],[' ',' ',' ']], G),
    G == [[' ',' ',' '],['X','2',' '],[' ',' ',' ']].
test(right_collide_wall) :-
    spec_move("right collide", [[' ',' ',' '],['1','[]',' '],[' ',' ',' ']], G),
    G == [[' ',' ',' '],['X','[]',' '],[' ',' ',' ']].
test(self_collide) :-
    spec_move("left", [['3','2',' '],['4','1',' '],['5',' ',' ']], G),
    G == [['3','2',' '],['4','X',' '],['5',' ',' ']].
test(chase_own_tail_is_fine) :-
    % the tail moves out of the way, so this is not a collision
    spec_move("left", [['3','2',' '],['4','1',' '],[' ',' ',' ']], G),
    G == [['4','3',' '],['1','2',' '],[' ',' ',' ']].

test(right_get_longer_single) :-     % spec labels this one "left"
    spec_move("right get longer", [[' ',' ',' '],['1',' ',' '],[' ',' ',' ']], G),
    G == [[' ',' ',' '],['2','1',' '],[' ',' ',' ']].
test(right_get_longer) :-
    spec_move("right get longer", [[' ',' ',' '],['2','1',' '],[' ',' ',' ']], G),
    G == [[' ',' ',' '],['3','2','1'],[' ',' ',' ']].
test(right_turn_left_get_longer) :-
    spec_move("right turn left get longer", [[' ',' ',' '],['2','1',' '],[' ',' ',' ']], G),
    G == [[' ','1',' '],['3','2',' '],[' ',' ',' ']].

:- end_tests(spec_move).

:- begin_tests(rules).

test(heading) :-
    heading([1-1, 1-2], D), D == up.
test(no_reverse) :-
    choose_dir(up, down, 3, D), D == up.
test(single_can_reverse) :-
    choose_dir(up, down, 1, D), D == down.
test(turns) :-
    choose_dir(right, turn_left, 3, L), L == up,
    choose_dir(right, turn_right, 3, R), R == down.
test(tail_moves_away) :-
    % a 4-long snake in a square can follow its own tail
    advance([1-1, 0-1, 0-0, 1-0], up, [], 3-3, 0, R),
    R = ok(_).

:- end_tests(rules).

:- begin_tests(levels).

test(level_count) :-
    level_count(N), N >= 5.
test(rows_rectangular, [forall(level(N, _, _, _, Rows))]) :-
    maplist(string_length, Rows, Ls),
    sort(Ls, [_]),
    assertion(start_cell(N, _)),
    assertion(exit_cell(N, _)).
test(new_game) :-
    new_game(G),
    G = g(1, Snake, _, 0, Food, 0, 3, playing, none, 0),
    length(Snake, 3),
    Food \== [].

:- end_tests(levels).

:- begin_tests(play).

%   Walk into a wall of level 1 until the lives run out.
test(game_over) :-
    new_game(G0),
    run_until(G0, left, G, 200),
    arg(8, G, Status),
    Status == game_over.

%   Eating food on a tiny hand-made state.
test(eat_grows) :-
    start_level(1, 0, 3, g(1, _, _, _, Food0, _, _, _, _, _)),
    Food0 = [F|_],
    F = FX-FY,
    HX is FX, HY is FY + 1,
    % place a 1-long snake just below the food, heading up
    (   \+ wall(1, HX-HY)
    ->  step(g(1, [HX-HY], up, 0, Food0, 0, 3, playing, none, 0), up, G, Ev),
        memberchk(eat, Ev),
        G = g(1, [F|_], _, Grow, Food1, Score, _, playing, _, _),
        Grow > 0, Score > 0,
        \+ memberchk(F, Food1)
    ;   true
    ).

:- end_tests(play).

run_until(G, _, G, 0) :- !.
run_until(G0, Cmd, G, N) :-
    step(G0, Cmd, G1, _),
    arg(8, G1, Status),
    (   Status == game_over
    ->  G = G1
    ;   N1 is N - 1,
        run_until(G1, Cmd, G, N1)
    ).

:- begin_tests(hall_of_fame).

test(add_and_rank, [setup(tmp_hof)]) :-
    hof_add(100, "Luc", 2, R1, _),
    hof_add(300, "Mr Snake", 5, R2, _),
    hof_add(200, "Fingertip", 3, R3, Entries),
    R1 == 1, R2 == 1, R3 == 2,
    Entries = [First|_],
    First.score == 300,
    hof_load,
    hof_top(10, Again),
    length(Again, 3).

:- end_tests(hall_of_fame).

tmp_hof :-
    tmp_file(hof, F),
    hof_set_file(F),
    hof_load.
