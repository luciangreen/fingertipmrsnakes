% The predicates whose inputs and outputs are recorded in io/ios.txt (see io/ios_engine.pl).
:- ios_engine:load_repo(levels).
:- ios_engine:load_repo(snake_engine).

io_title('fingertipmrsnakes').

io_cases([advance, play, choose_dir, heading, turns, level]).

dirs([up, down, left, right]).
% a snake of 1 to 4 cells, head first, on a 6 x 6 board, going right then bending down
snake(K, Snake) :-
    num(K, 1, 1, 4, Len), num(K, 2, 1, 4, X0), num(K, 3, 1, 4, Y0),
    numlist(1, Len, Is),
    maplist([I, X-Y]>>( I =< 2 -> X is X0 - I + 1, Y = Y0 ; X is X0 - 1, Y is Y0 - I + 2 ), Is, Snake).

io_input(advance, K, [Snake, Dir, Walls, 6-6, Grow]) :-
    snake(K, Snake), dirs(Ds), pick(K, 4, Ds, Dir),
    pick(K, 5, [[], [3-3], [0-0, 5-5], [2-1, 2-2, 2-3]], Walls), num(K, 6, 0, 1, Grow).
io_input(play, K, [Cmds]) :- pick_n(K, 7, 12, [up, down, left, right, none, none], Cmds).
io_input(choose_dir, K, [Dir, Cmd, Len]) :- dirs(Ds), pick(K, 8, Ds, Dir), pick(K, 9, [none | Ds], Cmd), num(K, 10, 1, 3, Len).
io_input(heading, K, [Snake]) :- snake(K, Snake).
io_input(turns, K, [Dir]) :- dirs(Ds), pick(K, 11, Ds, Dir).
io_input(level, K, [N]) :- level_count(C), num(K, 12, 1, C, N).

io_run(advance, [Snake, Dir, Walls, Size, Grow], Result) :- advance(Snake, Dir, Walls, Size, Grow, Result).
% a new game played with these commands: the events of each tick, then score and level
io_run(play, [Cmds], [events(Es), score(S), level(L)]) :-
    new_game(G0),
    foldl([C, E, G, G1]>>step(G, C, G1, E), Cmds, Es, G0, G),
    game_score(G, S, L).
io_run(choose_dir, [Dir, Cmd, Len], D) :- choose_dir(Dir, Cmd, Len, D).
io_run(heading, [Snake], D) :- heading(Snake, D).
io_run(turns, [Dir], [left(L), right(R), opposite(O), delta(DX-DY)]) :- turn_left(Dir, L), turn_right(Dir, R), opposite(Dir, O), delta(Dir, DX, DY).
io_run(level, [N], [size(S), start(St), exit(E), food(F), walls(W)]) :-
    size(N, S), start_cell(N, St), exit_cell(N, E), food_cells(N, F0), length(F0, F), aggregate_all(count, wall(N, _), W).
