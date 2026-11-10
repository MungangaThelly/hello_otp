
%%%-------------------------------------------------------------------
%% @doc hello_otp top level supervisor.
%%%-------------------------------------------------------------------

-module(hello_otp_sup).

-behaviour(supervisor).

-export([start_link/0, init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },

    ChildSpecs = [
        %% 1. Persistent storage
        #{
            id => hello_otp_storage,
            start => {hello_otp_storage, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [hello_otp_storage]
        },

        %% 2. Counter server
        #{
            id => hello_otp_server,
            start => {hello_otp_server, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [hello_otp_server]
        },

        %% 3. Monitoring service
        #{
            id => hello_otp_monitor,
            start => {hello_otp_monitor, start_link, []},
            restart => permanent,
            shutdown => 5000,
            type => worker,
            modules => [hello_otp_monitor]
        }
    ],

    {ok, {SupFlags, ChildSpecs}}.
