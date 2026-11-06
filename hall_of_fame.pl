/*  hall_of_fame.pl - persistent top-10 table, saved to data/hall_of_fame.pl
*/

:- module(hall_of_fame,
          [ hof_load/0,
            hof_add/5,
            hof_top/2,
            hof_set_file/1
          ]).

:- dynamic hof/4.               % hof(Score, Name, Level, Stamp)
:- dynamic hof_file_/1.

hof_size(10).

:- prolog_load_context(directory, Dir),
   directory_file_path(Dir, 'data/hall_of_fame.pl', F),
   retractall(hof_file_(_)),
   assertz(hof_file_(F)).

%!  hof_set_file(+File) is det.
%   Use another file (the tests use a temporary one).
hof_set_file(F) :-
    retractall(hof_file_(_)),
    assertz(hof_file_(F)).

hof_load :-
    hof_file_(F),
    retractall(hof(_, _, _, _)),
    (   exists_file(F)
    ->  setup_call_cleanup(open(F, read, S),
                           read_entries(S),
                           close(S))
    ;   true
    ).

read_entries(S) :-
    read_term(S, T, []),
    (   T == end_of_file
    ->  true
    ;   (   T = hof(Sc, N, L, St), integer(Sc)
        ->  assertz(hof(Sc, N, L, St))
        ;   true
        ),
        read_entries(S)
    ).

%!  hof_add(+Score, +Name, +Level, -Rank, -Entries) is det.
%   Add an entry, keep the best ten, save, and report the new rank
%   (0 if it did not make the table).
hof_add(Score, Name0, Level, Rank, Entries) :-
    clean_name(Name0, Name),
    get_time(Now),
    Stamp is integer(Now),
    with_mutex(hall_of_fame,
               ( assertz(hof(Score, Name, Level, Stamp)),
                 trim_table,
                 save_table,
                 (   sorted(Sorted),
                     nth1(Rank, Sorted, e(Score, Name, Level, Stamp))
                 ->  true
                 ;   Rank = 0
                 )
               )),
    hof_top(10, Entries).

%!  hof_top(+N, -Entries) is det.
%   Entries are dicts ready for JSON.
hof_top(N, Entries) :-
    sorted(Sorted),
    take(N, Sorted, Top),
    findall(_{rank:R, score:S, name:Nm, level:L, date:St},
            nth1(R, Top, e(S, Nm, L, St)),
            Entries).

sorted(Sorted) :-
    findall(S-e(S, N, L, St), hof(S, N, L, St), Pairs),
    sort(1, @>=, Pairs, SortedPairs),
    pairs_values(SortedPairs, Sorted).

trim_table :-
    hof_size(Max),
    sorted(Sorted),
    length(Sorted, Len),
    (   Len > Max
    ->  length(Keep, Max),
        append(Keep, Drop, Sorted),
        forall(member(e(S, N, L, St), Drop),
               retract(hof(S, N, L, St)))
    ;   true
    ).

save_table :-
    hof_file_(F),
    file_directory_name(F, Dir),
    make_directory_path(Dir),
    sorted(Sorted),
    setup_call_cleanup(
        open(F, write, Out),
        ( format(Out, "% Fingertip Mr Snakes hall of fame - hof(Score, Name, Level, UnixTime).~n", []),
          forall(member(e(S, N, L, St), Sorted),
                 portray_clause(Out, hof(S, N, L, St)))
        ),
        close(Out)).

take(N, List, Front) :-
    length(List, Len),
    (   Len =< N
    ->  Front = List
    ;   length(Front, N),
        append(Front, _, List)
    ).

%   Names are kept short and printable, stored as atoms.
clean_name(Name0, Name) :-
    (   string(Name0) -> S0 = Name0
    ;   atom(Name0) -> atom_string(Name0, S0)
    ;   S0 = "Anonymous"
    ),
    string_chars(S0, Cs0),
    include(printable, Cs0, Cs1),
    take(16, Cs1, Cs2),
    string_chars(S1, Cs2),
    normalize_space(string(S2), S1),
    (   S2 == "" -> Name = 'Anonymous' ; atom_string(Name, S2) ).

printable(C) :-
    char_code(C, Code),
    Code >= 32,
    Code =\= 127.
