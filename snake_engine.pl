/*  snake_engine.pl - pure game logic for Fingertip Mr Snakes

    Positions are X-Y pairs, 0-based, X = column, Y = row.
    A snake is a list of positions, head first.

    Game state:
      g(Level, Snake, Dir, Grow, Food, Score, Lives, Status, Crash, Ticks)

    Status is one of playing, crashed (a life was lost; the next step
    restarts the level), game_over or won.
*/

:- module(snake_engine,
          [ new_game/1,
            start_level/4,
            step/4,
            advance/6,
            choose_dir/4,
            heading/2,
            delta/3,
            opposite/2,
            turn_left/2,
            turn_right/2,
            game_json/2,
            game_score/3
          ]).

:- use_module(levels).

grow_per_food(1).
start_lives(3).
start_length(3).

delta(up,     0, -1).
delta(down,   0,  1).
delta(left,  -1,  0).
delta(right,  1,  0).

opposite(up, down).
opposite(down, up).
opposite(left, right).
opposite(right, left).

turn_left(up, left).
turn_left(left, down).
turn_left(down, right).
turn_left(right, up).

turn_right(D, R) :- turn_left(R, D).

%!  heading(+Snake, -Dir) is semidet.
%   The direction the head is travelling, worked out from head and neck.
heading([X-Y, NX-NY|_], Dir) :-
    DX is X - NX,
    DY is Y - NY,
    delta(Dir, DX, DY).

%!  choose_dir(+Current, +Command, +Length, -New) is det.
%   Command is up/down/left/right (absolute), turn_left/turn_right
%   (relative to the current heading) or none.  A snake longer than one
%   segment cannot reverse straight into its own neck.
choose_dir(Cur, turn_left, _, New) :- !, turn_left(Cur, New).
choose_dir(Cur, turn_right, _, New) :- !, turn_right(Cur, New).
choose_dir(Cur, Abs, Len, New) :-
    delta(Abs, _, _), !,
    (   Len > 1, opposite(Cur, Abs)
    ->  New = Cur
    ;   New = Abs
    ).
choose_dir(Cur, _, _, Cur).

%!  advance(+Snake, +Dir, +Blocked, +Size, +Grow, -Result) is det.
%   Move the snake one cell.  Result is ok(NewSnake) or crash(HeadPos)
%   when the move would leave the board, enter a blocked cell or bite
%   the snake's own body.  With Grow > 0 the tail stays put (get longer).
advance([X-Y|Body], Dir, Blocked, W-H, Grow, Result) :-
    delta(Dir, DX, DY),
    NX is X + DX,
    NY is Y + DY,
    Next = NX-NY,
    (   ( NX < 0 ; NY < 0 ; NX >= W ; NY >= H ; memberchk(Next, Blocked) )
    ->  Result = crash(X-Y)
    ;   (   Grow > 0
        ->  Kept = [X-Y|Body]
        ;   drop_last([X-Y|Body], Kept)
        ),
        (   memberchk(Next, Kept)
        ->  Result = crash(X-Y)
        ;   Result = ok([Next|Kept])
        )
    ).

drop_last([_], []) :- !.
drop_last([H|T], [H|T1]) :- drop_last(T, T1).

%!  new_game(-Game) is det.
new_game(G) :-
    start_lives(Lives),
    start_level(1, 0, Lives, G).

%!  start_level(+Level, +Score, +Lives, -Game) is det.
start_level(N, Score, Lives, g(N, Snake, Dir, 0, Food, Score, Lives, playing, none, 0)) :-
    level(N, _, Dir, _, _),
    start_cell(N, Head),
    food_cells(N, Food),
    start_length(Len),
    initial_snake(Head, Dir, Len, Snake).

initial_snake(X-Y, Dir, Len, Snake) :-
    delta(Dir, DX, DY),
    L1 is Len - 1,
    findall(SX-SY,
            ( between(0, L1, I),
              SX is X - DX*I,
              SY is Y - DY*I
            ),
            Snake).

%!  step(+Game0, +Command, -Game, -Events) is det.
%   Advance the game by one tick.  Events is a list of atoms the client
%   can react to: eat, exit_open, crash, respawn, level_up, win, game_over.
step(G0, _Cmd, G0, []) :-
    arg(8, G0, Status),
    memberchk(Status, [game_over, won]), !.
step(g(N, _, _, _, _, Score, Lives, crashed, _, _), _Cmd, G, [respawn]) :- !,
    start_level(N, Score, Lives, G).
step(g(N, Snake, Dir0, Grow, Food, Score, Lives, playing, _, T0), Cmd, G, Events) :-
    length(Snake, Len),
    choose_dir(Dir0, Cmd, Len, Dir),
    size(N, Size),
    findall(P, wall(N, P), Walls),
    exit_cell(N, Exit),
    (   Food == []
    ->  Blocked = Walls
    ;   Blocked = [Exit|Walls]          % the gate is locked
    ),
    advance(Snake, Dir, Blocked, Size, Grow, Result),
    T is T0 + 1,
    after_move(Result, g(N, Snake, Dir, Grow, Food, Score, Lives, playing, none, T),
               Exit, G, Events).

after_move(crash(P), g(N, S, D, Gr, F, Sc, L, _, _, T), _Exit, G, Events) :- !,
    L1 is L - 1,
    (   L1 =< 0
    ->  G = g(N, S, D, Gr, F, Sc, 0, game_over, P, T),
        Events = [crash, game_over]
    ;   G = g(N, S, D, Gr, F, Sc, L1, crashed, P, T),
        Events = [crash]
    ).
after_move(ok([H|B]), g(N, _, D, Gr, F, Sc, L, _, _, T), Exit, G, Events) :-
    (   Gr > 0 -> Gr0 is Gr - 1 ; Gr0 = 0 ),
    (   H == Exit
    ->  length([H|B], Len),
        Sc1 is Sc + 100*N + 5*Len,
        level_count(Max),
        (   N >= Max
        ->  Sc2 is Sc1 + 500*L,
            G = g(N, [H|B], D, 0, [], Sc2, L, won, none, T),
            Events = [win]
        ;   N1 is N + 1,
            start_level(N1, Sc1, L, G),
            Events = [level_up]
        )
    ;   selectchk(H, F, F1)
    ->  grow_per_food(GPF),
        Gr1 is Gr0 + GPF,
        Sc1 is Sc + 10*N,
        G = g(N, [H|B], D, Gr1, F1, Sc1, L, playing, none, T),
        (   F1 == []
        ->  Events = [eat, exit_open]
        ;   Events = [eat]
        )
    ;   G = g(N, [H|B], D, Gr0, F, Sc, L, playing, none, T),
        Events = []
    ).

%!  game_score(+Game, -Score, -Level) is det.
game_score(G, Score, Level) :-
    arg(1, G, Level),
    arg(6, G, Score).

%!  game_json(+Game, -Dict) is det.
%   A JSON-ready view of the game for the web client.
game_json(g(N, Snake, Dir, _Grow, Food, Score, Lives, Status, Crash, Ticks), J) :-
    level(N, Name, _, Speed, Rows),
    level_count(Max),
    size(N, W-H),
    maplist(pair_list, Snake, SL),
    maplist(pair_list, Food, FL),
    (   Crash = CX-CY -> CJ = [CX, CY] ; CJ = null ),
    (   Food == [] -> Open = true ; Open = false ),
    J = _{ level:N, levels:Max, name:Name, speed:Speed,
           width:W, height:H, grid:Rows,
           snake:SL, food:FL, dir:Dir,
           score:Score, lives:Lives, status:Status,
           crash:CJ, exitOpen:Open, ticks:Ticks }.

pair_list(X-Y, [X, Y]).
