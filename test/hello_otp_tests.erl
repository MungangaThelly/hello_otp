
%%%-------------------------------------------------------------------
%% @doc EUnit tests for hello_otp.
%%%-------------------------------------------------------------------

-module(hello_otp_tests).

-include_lib("eunit/include/eunit.hrl").

%% Test fixture
hello_otp_test_() ->
    {
        setup,
        fun start_application/0,
        fun stop_application/1,
        fun(_State) ->
            [
                ?_test(test_initial_state()),
                ?_test(test_synchronous_increment()),
                ?_test(test_asynchronous_increment()),
                ?_test(test_storage_consistency()),
                ?_test(test_worker_restart())
            ]
        end
    }.

%% Start application before tests
start_application() ->
    case application:ensure_all_started(hello_otp) of
        {ok, _Started} ->
            ok;

        {error, Reason} ->
            erlang:error({application_start_failed, Reason})
    end.

%% Stop application after tests
stop_application(_State) ->
    application:stop(hello_otp).

%% Test 1: Initial state matches persistent storage
test_initial_state() ->
    StoredValue = hello_otp_storage:get_counter(),
    ServerValue = hello_otp_server:get_count(),

    ?assertEqual(StoredValue, ServerValue).

%% Test 2: Synchronous increment
test_synchronous_increment() ->
    Before = hello_otp_server:get_count(),

    Result = hello_otp_server:increment(),

    ?assertEqual(Before + 1, Result),
    ?assertEqual(Before + 1, hello_otp_server:get_count()).

%% Test 3: Asynchronous increment
test_asynchronous_increment() ->
    Before = hello_otp_server:get_count(),

    Result = hello_otp_server:increment_async(),

    ?assertEqual(ok, Result),

    %% The following call comes from the same process,
    %% so it follows the earlier cast in message order.
    ?assertEqual(
        Before + 1,
        hello_otp_server:get_count()
    ).

%% Test 4: Storage consistency
test_storage_consistency() ->
    ServerValue = hello_otp_server:get_count(),
    StoredValue = hello_otp_storage:get_counter(),

    ?assertEqual(ServerValue, StoredValue).

%% Test 5: Worker restart and persistent recovery
test_worker_restart() ->
    Before = hello_otp_server:get_count(),
    OldPid = whereis(hello_otp_server),

    ?assert(is_pid(OldPid)),

    exit(OldPid, kill),

    NewPid = wait_for_new_worker(OldPid, 50),

    ?assert(is_pid(NewPid)),
    ?assertNotEqual(OldPid, NewPid),

    ?assertEqual(
        Before,
        hello_otp_server:get_count()
    ),

    ?assertEqual(
        Before,
        hello_otp_storage:get_counter()
    ).

%% Wait for supervisor to restart worker
wait_for_new_worker(_OldPid, 0) ->
    erlang:error(worker_restart_timeout);

wait_for_new_worker(OldPid, Attempts) ->
    case whereis(hello_otp_server) of
        undefined ->
            timer:sleep(100),
            wait_for_new_worker(OldPid, Attempts - 1);

        OldPid ->
            timer:sleep(100),
            wait_for_new_worker(OldPid, Attempts - 1);

        NewPid ->
            NewPid
    end.
