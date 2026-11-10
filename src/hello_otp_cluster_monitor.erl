
-module(hello_otp_cluster_monitor).
-behaviour(gen_server).

-export([
    start_link/0,
    stop/0,
    get_status/0
]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

%% Public API

start_link() ->
    gen_server:start_link(
        {local, ?MODULE},
        ?MODULE,
        [],
        []
    ).

stop() ->
    gen_server:stop(?MODULE).

get_status() ->
    gen_server:call(?MODULE, get_status).

%% GenServer callbacks

init([]) ->
    ok = net_kernel:monitor_nodes(true),

    State = #{
        connected_nodes => nodes(),
        disconnection_count => 0,
        last_disconnected => undefined
    },

    io:format("Cluster monitor started.~n"),

    {ok, State}.

handle_call(get_status, _From, State) ->
    {reply, State, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Message, State) ->
    {noreply, State}.

%% A remote node connects.

handle_info({nodeup, Node}, State) ->
    io:format("NODE CONNECTED: ~p~n", [Node]),

    Connected = lists:usort(
        [Node | maps:get(connected_nodes, State)]
    ),

    NewState = State#{
        connected_nodes => Connected
    },

    {noreply, NewState};

%% A remote node disconnects.

handle_info({nodedown, Node}, State) ->
    io:format("NODE DISCONNECTED: ~p~n", [Node]),

    Connected = lists:delete(
        Node,
        maps:get(connected_nodes, State)
    ),

    Count = maps:get(disconnection_count, State) + 1,

    NewState = State#{
        connected_nodes => Connected,
        disconnection_count => Count,
        last_disconnected => Node
    },

    {noreply, NewState};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    net_kernel:monitor_nodes(false),
    io:format("Cluster monitor stopped.~n"),
    ok.

code_change(_OldVersion, State, _Extra) ->
    {ok, State}.
