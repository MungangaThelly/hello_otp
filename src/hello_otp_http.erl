%%%-------------------------------------------------------------------
%% @doc Minimal HTTP server for the browser counter demo.
%%%-------------------------------------------------------------------

-module(hello_otp_http).

-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Port = application:get_env(hello_otp, http_port, 8080),
    case gen_tcp:listen(Port, [binary, {packet, raw}, {active, false},
                               {reuseaddr, true}, {ip, {127, 0, 0, 1}}]) of
        {ok, ListenSocket} ->
            Acceptor = spawn_link(fun() -> accept_loop(ListenSocket) end),
            {ok, #{listen_socket => ListenSocket, acceptor => Acceptor}};
        {error, Reason} ->
            {stop, {http_listen_failed, Port, Reason}}
    end.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Request, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #{listen_socket := ListenSocket}) ->
    gen_tcp:close(ListenSocket),
    ok.

code_change(_OldVersion, State, _Extra) ->
    {ok, State}.

accept_loop(ListenSocket) ->
    case gen_tcp:accept(ListenSocket) of
        {ok, Socket} ->
            handle_client(Socket),
            accept_loop(ListenSocket);
        {error, closed} ->
            ok;
        {error, Reason} ->
            exit({http_accept_failed, Reason})
    end.

handle_client(Socket) ->
    try
        case gen_tcp:recv(Socket, 0, 5000) of
            {ok, Request} ->
                respond(Socket, request_path(Request));
            {error, _Reason} ->
                ok
        end
    after
        gen_tcp:close(Socket)
    end.

request_path(Request) ->
    case binary:split(Request, <<"\r\n">>) of
        [RequestLine | _] ->
            case binary:split(RequestLine, <<" ">>, [global]) of
                [_Method, Path | _] -> hd(binary:split(Path, <<"?">>));
                _ -> <<>>
            end;
        _ -> <<>>
    end.

respond(Socket, <<"/increment">>) ->
    case hello_otp_server:increment() of
        Count when is_integer(Count) -> send_page(Socket, 200, page(Count));
        {error, _Reason} -> send_page(Socket, 500, error_page())
    end;
respond(Socket, <<"/">>) ->
    send_page(Socket, 200, page(hello_otp_server:get_count()));
respond(Socket, _Path) ->
    send_page(Socket, 404, <<"<h1>Not found</h1><p><a href=\"/\">Home</a></p>">>).

page(Count) ->
    iolist_to_binary(io_lib:format(
        "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
        "<title>Hello OTP</title><style>body{font:18px system-ui;max-width:42rem;"
        "margin:4rem auto;padding:0 1rem;color:#18302b}a,button{color:#075e54}"
        "button{font:inherit;padding:.6rem 1rem;cursor:pointer}</style></head>"
        "<body><h1>Hello from Erlang/OTP!</h1><p>The application is running.</p>"
        "<p>Persistent counter: <strong>~B</strong></p>"
        "<p><a href=\"/increment\"><button>Increment counter</button></a></p>"
        "</body></html>", [Count])).

error_page() ->
    <<"<!doctype html><html><body><h1>Counter storage error</h1>"
      "<p><a href=\"/\">Try again</a></p></body></html>">>.

send_page(Socket, Status, Body) ->
    Reason = case Status of
        200 -> "OK";
        404 -> "Not Found";
        500 -> "Internal Server Error"
    end,
    Header = io_lib:format(
        "HTTP/1.1 ~B ~s\r\nContent-Type: text/html; charset=utf-8\r\n"
        "Content-Length: ~B\r\nConnection: close\r\n\r\n",
        [Status, Reason, byte_size(Body)]),
    gen_tcp:send(Socket, [Header, Body]).
