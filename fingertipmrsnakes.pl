/*  fingertipmrsnakes.pl - web server for Fingertip Mr Snakes

    Start:   swipl fingertipmrsnakes.pl
    Play:    http://localhost:8080
    Port:    set the PORT environment variable, or call ?- server(Port).

    The game logic runs here, in Prolog; the browser only draws and
    sends key presses.  Game state is kept on the server so that the
    hall of fame only accepts scores that were really played.
*/

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_files)).

:- use_module(snake_engine).
:- use_module(levels).
:- use_module(hall_of_fame).

:- dynamic game_store/3.        % game_store(Id, Game, SavedToHallOfFame)
:- dynamic app_dir/1.

:- prolog_load_context(directory, Dir),
   retractall(app_dir(_)),
   asserta(app_dir(Dir)).

:- multifile user:file_search_path/2.
user:file_search_path(snakes_web, Dir) :-
    app_dir(App),
    directory_file_path(App, web, Dir).

:- http_handler(root(.),        http_reply_file(snakes_web('index.html'), []), []).
:- http_handler(root(static), serve_static, [prefix]).
:- http_handler(root(api/new),  api_new,  [method(post)]).
:- http_handler(root(api/step), api_step, [method(post)]).
:- http_handler(root(api/hall), api_hall, [methods([get, post])]).

%!  server is det.
%!  server(+Port) is det.
server :-
    (   getenv('PORT', P), atom_number(P, Port)
    ->  true
    ;   Port = 8080
    ),
    server(Port).

server(Port) :-
    hof_load,
    http_server(http_dispatch, [port(Port)]),
    format("~nFingertip Mr Snakes is running at http://localhost:~w~n~n", [Port]).

stop(Port) :-
    http_stop_server(Port, []).

%   ---- handlers ----------------------------------------------------------

api_new(_Request) :-
    new_game(G),
    new_id(Id),
    with_mutex(snake_games, assertz(game_store(Id, G, false))),
    prune_games,
    game_json(G, J),
    reply_json_dict(_{id:Id, state:J, events:[]}).

api_step(Request) :-
    http_read_json_dict(Request, In),
    (   get_dict(id, In, IdS) -> atom_string(Id, IdS) ; Id = '' ),
    (   get_dict(cmd, In, CmdS) -> atom_string(Cmd0, CmdS) ; Cmd0 = none ),
    (   memberchk(Cmd0, [up, down, left, right, turn_left, turn_right, none])
    ->  Cmd = Cmd0
    ;   Cmd = none
    ),
    with_mutex(snake_games,
               (   retract(game_store(Id, G0, Saved))
               ->  step(G0, Cmd, G, Events),
                   assertz(game_store(Id, G, Saved)),
                   Found = true
               ;   Found = false
               )),
    (   Found == true
    ->  game_json(G, J),
        reply_json_dict(_{state:J, events:Events})
    ;   reply_json_dict(_{error:"Unknown game - start a new one."}, [status(404)])
    ).

api_hall(Request) :-
    memberchk(method(get), Request), !,
    hof_top(10, Entries),
    reply_json_dict(_{entries:Entries}).
api_hall(Request) :-
    http_read_json_dict(Request, In),
    (   get_dict(id, In, IdS) -> atom_string(Id, IdS) ; Id = '' ),
    (   get_dict(name, In, Name) -> true ; Name = "Anonymous" ),
    with_mutex(snake_games,
               (   game_store(Id, G, false),
                   arg(8, G, Status),
                   memberchk(Status, [game_over, won])
               ->  retract(game_store(Id, G, false)),
                   assertz(game_store(Id, G, true)),
                   OK = true
               ;   OK = false
               )),
    (   OK == true
    ->  game_score(G, Score, Level),
        hof_add(Score, Name, Level, Rank, Entries),
        reply_json_dict(_{rank:Rank, entries:Entries})
    ;   hof_top(10, Entries),
        reply_json_dict(_{rank:0, entries:Entries,
                          error:"Only a finished game can be entered, once."})
    ).

%   ---- helpers -----------------------------------------------------------

new_id(Id) :-
    random_between(100000000, 999999999, A),
    random_between(100000000, 999999999, B),
    format(atom(Id), "g~w~w", [A, B]).

%   Keep at most 500 games in memory; drop the oldest.
prune_games :-
    with_mutex(snake_games,
               (   aggregate_all(count, game_store(_, _, _), N),
                   N > 500
               ->  Extra is N - 500,
                   forall(( limit(Extra, game_store(Id, G, S)) ),
                          retract(game_store(Id, G, S)))
               ;   true
               )).

serve_static(Request) :-
    (   memberchk(path_info(P0), Request) -> true ; P0 = '' ),
    (   atom_concat('/', P, P0) -> true ; P = P0 ),
    \+ sub_atom(P, _, _, _, '..'),
    app_dir(A),
    atomic_list_concat([A, '/web/', P], F),
    exists_file(F), !,
    http_reply_file(F, [unsafe(true)], Request).
serve_static(Request) :-
    http_404([], Request).

:- initialization(server).
