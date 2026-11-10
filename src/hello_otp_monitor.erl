
%%%-------------------------------------------------------------------
%% @doc Monitors the lifecycle of hello_otp_server.
%% @end
%%%-------------------------------------------------------------------

-module(hello_otp_monitor).

-behaviour(gen_server).

%% Public API
-export([start_link/0, get_status/0]).

%% GenServer callbacks
-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

%% Start monitoring service
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Get monitoring information
get_status() ->
    gen_server:call(?MODULE, get_status).

%% Initialize monitor
init([]) ->
    State = #{
        monitored_pid => undefined,
        monitor_ref => undefined,
        termination_count => 0,
        last_reason => undefined,
        status => waiting_for_server
    },

    self() ! check_server,

    {ok, State}.

%% Handle synchronous requests
handle_call(get_status, _From, State) ->
    Reply = maps:with(
        [monitored_pid, termination_count, last_reason, status],
        State
    ),
    {reply, Reply, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

%% Handle asynchronous messages
handle_cast(_Request, State) ->
    {noreply, State}.

%% Receive process termination notification
handle_info(
    {'DOWN', Ref, process, Pid, Reason},
    State = #{
        monitor_ref := Ref,
        monitored_pid := Pid
    }
) ->
    NewCount = maps:get(termination_count, State) + 1,

    NewState = State#{
        monitored_pid => undefined,
        monitor_ref => undefined,
        termination_count => NewCount,
        last_reason => Reason,
        status => waiting_for_server
    },

    %% Check for replacement worker
    erlang:send_after(100, self(), check_server),

    {noreply, NewState};

%% Look for the restarted GenServer
handle_info(check_server, State = #{monitored_pid := undefined}) ->
    case whereis(hello_otp_server) of
        undefined ->
            erlang:send_after(100, self(), check_server),
            {noreply, State};

        Pid ->
            Ref = monitor(process, Pid),

            NewState = State#{
                monitored_pid => Pid,
                monitor_ref => Ref,
                status => monitoring
            },

            {noreply, NewState}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

%% Cleanup
terminate(_Reason, _State) ->
    ok.

%% Code upgrade support
code_change(_OldVersion, State, _Extra) ->
    {ok, State}.
