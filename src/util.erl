-module(util).

-export([mk_timestamp/0, mk_timestamp_us/0,
	 human_length/1, human_bandwidth/1, human_duration/1,
	 timestamp_to_iso8601/1,
	 timestamp_to_universal_time/1,
	 pmap/2, timeout/2,
	 split_string/3, list_index/2]).

mk_timestamp() ->
    {MS, S, _} = erlang:now(),
    MS * 1000000 + S.

mk_timestamp_us() ->
    {MS, S, SS} = erlang:now(),
    (MS * 1000000 + S) * 1000000 + SS.


-define(UPPER_READABLE_LIMIT, 1024).

divide_until_readable(I) ->
    divide_until_readable1(I, ["", "K", "M", "G", "T", "P", "E"]).

divide_until_readable1(I, [U]) ->
    {I, U};
divide_until_readable1(I, [_ | R]) when I > ?UPPER_READABLE_LIMIT ->
    divide_until_readable1(I / 1024, R);
divide_until_readable1(I, [U | _]) ->
    {I, U}.


human_length(L) ->
    {I, U} = divide_until_readable(L),
    S = io_lib:format("~.1f~sB", [I / 1.0, U]),
    list_to_binary(S).

human_bandwidth(B) ->
    {I, U} = divide_until_readable(B),
    S = io_lib:format("~.1f~sB/s", [I / 1.0, U]),
    list_to_binary(S).


human_duration(D) ->
    list_to_binary(human_duration1(D)).

human_duration1(D) when D >= 24 * 60 * 60->
    io_lib:format("~Bd ago", [D div (24 * 60 * 60)]);

human_duration1(D) when D >= 60 * 60->
    io_lib:format("~Bh", [D div (60 * 60)]);

human_duration1(D) when D >= 60 ->
    io_lib:format("~Bm", [D div 60]);

human_duration1(D) ->
    io_lib:format("~Bs", [D]).


timestamp_to_iso8601(TS) ->
    Now = {TS div 1000000, TS rem 1000000, 0},
    {{Y, M, D}, {Hour, Min, Sec}} = calendar:now_to_universal_time(Now),
    list_to_binary(
      io_lib:format("~4..0B-~2..0B-~2..0BT~2..0B:~2..0B:~2..0B+00:00",
		    [Y, M, D, Hour, Min, Sec])).

timestamp_to_universal_time(TS) ->
    Now = {TS div 1000000, TS rem 1000000, 0},
    calendar:now_to_universal_time(Now).

%% http://yarivsblog.com/articles/2008/02/08/the-erlang-challenge/
pmap(Fun, List) ->
    Parent = self(),
    Pids = [spawn_link(fun() ->
			       Parent ! {self(), Fun(Elem)}
		       end)
	    || Elem <- List],
    [receive
	 {'EXIT', _From, Reason} -> exit(Reason);
	 {Pid, Val} -> Val
     end
     || Pid <- Pids].


timeout(Fun, Timeout) ->
    I = self(),
    Ref = make_ref(),
    Pid = spawn_link(fun() ->
			     Result = Fun(),
			     I ! {Ref, Result}
		     end),
    receive
	{Ref, Result} ->
	    Result
    after Timeout ->
	    exit(Pid, timeout),
	    exit(timeout)
    end.


split_string(S, _Sep, 1) ->
    [S];
split_string(S, Sep, N) ->
    case lists:splitwith(fun(Ch) when Ch == Sep -> false;
			    (_) -> true
			 end, S) of
	{S1, [Sep | S2]} ->
	    [S1 | split_string(S2, Sep, N - 1)];
	{S, ""} ->
	    [S]
    end.

list_index(_, []) ->
    0;
list_index(E, [E | _]) ->
    1;
list_index(E, [_ | R]) ->
    list_index(E, R) + 1.
