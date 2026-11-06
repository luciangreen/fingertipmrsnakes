/*  levels.pl - level maps for Fingertip Mr Snakes

    Every level is half maze, half open snake field.

    Map legend
      #  wall / hedge
      .  empty floor
      o  food (eat all of it to open the exit)
      S  snake head start (the body trails behind it, opposite StartDir)
      E  exit gate (locked until every piece of food has been eaten)

    level(Number, Name, StartDir, TickMs, Rows)
*/

:- module(levels,
          [ level/5,
            level_count/1,
            size/2,
            wall/2,
            exit_cell/2,
            start_cell/2,
            food_cells/2,
            index_levels/0
          ]).

:- dynamic size/2, wall/2, exit_cell/2, start_cell/2, food_cell/2.

%  Level 1: maze on the left, open garden on the right.
level(1, "Garden Gate", down, 230,
      [ "####################",
        "#...#.....#........#",
        "#.#.#.###.#...o....#",
        "#S#...#o..#........#",
        "#.#####.###....o...#",
        "#...o.#............#",
        "###.#.#.###........#",
        "#...#...#o.....o...#",
        "#.#####.#..........#",
        "#.#o....#.....o....#",
        "#.#.#####..........#",
        "#...#..o...........#",
        "#.###.###......o...#",
        "#.....#..........E.#",
        "####################"
      ]).

%  Level 2: open field on the left, hedge maze on the right.
level(2, "Hedge Hall", right, 210,
      [ "####################",
        "#.........#...#...o#",
        "#..S......#.#.#.##.#",
        "#.....o...#.#...#..#",
        "#.........#.#####.##",
        "#..o......#.....#..#",
        "#.........###.#.##.#",
        "#......o......#o...#",
        "#.........#####.####",
        "#..o......#...#....#",
        "#.........#.#.#.##.#",
        "#......o....#....o.#",
        "#.........###.###..#",
        "#..o......##E......#",
        "####################"
      ]).

%  Level 3: maze across the top half, open lake across the bottom.
level(3, "Split Spiral", right, 190,
      [ "####################",
        "#o.....#.....#....o#",
        "#.####.#.###.#.###.#",
        "#.#..#...#o....#...#",
        "#.#..###.#.#####.###",
        "#........#.....#...#",
        "#.######.#####.###.#",
        "#.........o........#",
        "#..S...............#",
        "#..........o.......#",
        "#....o.........o...#",
        "#..................#",
        "#.......o......o...#",
        "#E.................#",
        "####################"
      ]).

%  Level 4: open lake at the top, labyrinth at the bottom.
level(4, "Labyrinth Lake", right, 170,
      [ "####################",
        "#..................#",
        "#..S...o.....o.....#",
        "#..................#",
        "#.....o......o.....#",
        "#..................#",
        "#.######.####.####.#",
        "#.#o...#.#..#.....o#",
        "#.#.##.#.#..#.##.#.#",
        "#.#..#...#....#....#",
        "#.##.###.#.####.##.#",
        "#.....o..#.#..#....#",
        "####.#.....#....##.#",
        "#E.....#...#o......#",
        "####################"
      ]).

%  Level 5: Mr Snake's lair - tight maze on the left, fast arena on the right.
level(5, "Mr Snake's Lair", up, 150,
      [ "####################",
        "#o....#..o#........#",
        "#.#.#.#.#.#..o.....#",
        "#...#...#.#........#",
        "##.##.###.#....o...#",
        "#o..#...#.#........#",
        "#.#.###.#...o......#",
        "#.....#...#........#",
        "#..##.###.#....S...#",
        "#.........#........#",
        "###.#.###.#..o.....#",
        "#o......#.#........#",
        "#.#####.#.#.....o..#",
        "#.......#.......E..#",
        "####################"
      ]).

level_count(N) :-
    aggregate_all(max(L), level(L, _, _, _, _), N).

%!  food_cells(+Level, -Food) is det.
food_cells(N, Food) :-
    findall(P, food_cell(N, P), Food).

%!  index_levels is det.
%   Turn the text maps into wall/exit/start/food facts (X-Y, 0-based).
index_levels :-
    retractall(size(_, _)),
    retractall(wall(_, _)),
    retractall(exit_cell(_, _)),
    retractall(start_cell(_, _)),
    retractall(food_cell(_, _)),
    forall(level(N, _, _, _, Rows), index_level(N, Rows)).

index_level(N, Rows) :-
    length(Rows, H),
    Rows = [Row0|_],
    string_length(Row0, W),
    assertz(size(N, W-H)),
    forall(( nth0(Y, Rows, Row),
             string_chars(Row, Cs),
             nth0(X, Cs, C)
           ),
           index_cell(N, X-Y, C)).

index_cell(N, P, '#') :- !, assertz(wall(N, P)).
index_cell(N, P, 'E') :- !, assertz(exit_cell(N, P)).
index_cell(N, P, 'S') :- !, assertz(start_cell(N, P)).
index_cell(N, P, 'o') :- !, assertz(food_cell(N, P)).
index_cell(_, _, _).

:- initialization(index_levels).
