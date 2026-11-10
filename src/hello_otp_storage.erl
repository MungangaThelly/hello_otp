
%%%-------------------------------------------------------------------
%% @doc Persistent counter storage using DETS.
%%%-------------------------------------------------------------------

-module(hello_otp_storage).

-behaviour(gen_server).

-export([start_link/0, get_counter/0, save_counter/1]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2,
    code_change/3
]).

-define(SERVER, ?MODULE).
-define(TABLE, hello_otp_counter).
-define(DETS_FILE, "data/hello_otp_counter.dets").

%% Start storage service
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% Read persistent counter
get_counter() ->
    gen_server:call(?SERVER, get_counter).

%% Save persistent counter
save_counter(Value) when is_integer(Value), Value >= 0 ->
    gen_server:call(?SERVER, {save_counter, Value}).

%% Initialize DETS
init([]) ->
    case filelib:ensure_dir(?DETS_FILE) of
        ok ->
            case dets:open_file(?TABLE, [
                {file, ?DETS_FILE},
                {type, set}
            ]) of
                {ok, ?TABLE} ->
                    {ok, initialized};

                {error, Reason} ->
                    {stop, {dets_open_failed, Reason}}
            end;

        {error, Reason} ->
            {stop, {directory_creation_failed, Reason}}
    end.

%% Handle synchronous requests
handle_call(get_counter, _From, State) ->
    Reply =
        case dets:lookup(?TABLE, counter) of
            [{counter, Value}] ->
                Value;

            [] ->
                0
        end,
    {reply, Reply, State};

handle_call({save_counter, Value}, _From, State) ->
    case dets:insert(?TABLE, {counter, Value}) of
        ok ->
            case dets:sync(?TABLE) of
                ok ->
                    {reply, ok, State};

                {error, Reason} ->
                    {reply, {error, Reason}, State}
            end;

        {error, Reason} ->
            {reply, {error, Reason}, State}
    end;

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

%% Close DETS table
terminate(_Reason, _State) ->
    dets:close(?TABLE),
    ok.

code_change(_OldVersion, State, _Extra) ->
    {ok, State}.
