% https://github.com/gdamjan/ircbot-gleam/blob/main/src/uptime_ffi.erl
-module(uptime_ffi).
-author(gdamjan).
-export([uptime/0]).

uptime() ->
    {StartTime, _} = erlang:statistics(wall_clock),
    {D, {H, M, S}} = calendar:seconds_to_daystime(StartTime div 1000),
    {D, {H, M, S}}.
