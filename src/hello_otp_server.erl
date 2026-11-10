
%%%-------------------------------------------------------------------
%% @doc Counter GenServer with persistent storage.
%%%-------------------------------------------------------------------

-module(hello_otp_server).

-behaviour(gen_server).

-export([
    start_link/0,
    get_count/0,
    increment/0,
    increment_async/0
]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

%% Start counter server
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Public API
get_count() ->
    gen_server:call(?MODULE, get_count).

increment() ->
    gen_server:call(?MODULE, increment).

increment_async() ->
    gen_server:cast(?MODULE, increment_async).

%% Load persistent state
init([]) ->
    InitialState = hello_otp_storage:get_counter(),
    {ok, InitialState}.

%% Synchronous requests
handle_call(get_count, _From, State) ->
    {reply, State, State};

handle_call(increment, _From, State) ->
    NewState = State + 1,

    case hello_otp_storage:save_counter(NewState) of
        ok ->
            {reply, NewState, NewState};

        {error, Reason} ->
            {reply, {error, Reason}, State}
    end;

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

%% Asynchronous requests
handle_cast(increment_async, State) ->
    NewState = State + 1,

    case hello_otp_storage:save_counter(NewState) of
        ok ->
            {noreply, NewState};

        {error, Reason} ->
            {stop, {storage_error, Reason}, State}
    end;

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVersion, State, _Extra) ->
    {ok, State}.
