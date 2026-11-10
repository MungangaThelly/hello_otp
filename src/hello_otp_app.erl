%%%-------------------------------------------------------------------
%% @doc hello_otp public API
%% @end
%%%-------------------------------------------------------------------

-module(hello_otp_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    hello_otp_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
