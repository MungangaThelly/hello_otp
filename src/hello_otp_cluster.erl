
-module(hello_otp_cluster).

-export([
    check_node/1,
    get_remote_count/1,
    increment_remote/1
]).

-define(RPC_TIMEOUT, 5000).

%% Check whether a remote node is reachable.
check_node(Node) when is_atom(Node) ->
    case net_adm:ping(Node) of
        pong ->
            {ok, Node};
        pang ->
            {error, {node_unreachable, Node}}
    end.

%% Retrieve the counter from a remote node.
get_remote_count(Node) when is_atom(Node) ->
    case check_node(Node) of
        {ok, _} ->
            rpc:call(
                Node,
                hello_otp_server,
                get_count,
                [],
                ?RPC_TIMEOUT
            );
        {error, Reason} ->
            {error, Reason}
    end.

%% Increment the counter on a remote node.
increment_remote(Node) when is_atom(Node) ->
    case check_node(Node) of
        {ok, _} ->
            rpc:call(
                Node,
                hello_otp_server,
                increment,
                [],
                ?RPC_TIMEOUT
            );
        {error, Reason} ->
            {error, Reason}
    end.
