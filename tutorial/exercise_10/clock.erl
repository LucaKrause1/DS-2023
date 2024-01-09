-module(clock). 
-export([start/1, get/1, getTS/1, startT/1, clock/3, clockTicker/3, ticker/2, startTicker/2, timer/3, startTimer/3, timerDone/0, getTimer/1, timeServer/1, startTS/1, startClient/2, client/4, network/0]).

% clockWrong(Speed, Pause, Time) -> 
%     receive
%         {set, Value} -> clock(Speed, Pause, Value);
%         {get, Pid} -> 
%             Pid!{clock, Time},
%             case Pause of
%                 true -> clock(Speed, Pause, Time);
%                 false -> clock(Speed, Pause, Time + 1)
%             end.
%         pause -> clock(Speed, true, Time);
%         resume -> clock(Speed, false, Time + 1);
%         stop -> ok
%     end.

clock(Speed, Pause, Time) -> 
    receive
        {set, Value} -> clock(Speed, Pause, Value);
        {get, Pid} -> Pid!{clock, Time}, clock(Speed, Pause, Time);
        pause -> clock(Speed, true, Time);
        resume -> clock(Speed, false, Time);
        stop -> ok
        %Nachteil receive after hier zu nutzen:
        %Beeinflussung des Increment-Verhaltens durch Erhalt anderer Nachrichten.
        %Außerdem Zeitverzögerung bei der Bearbeitung von Nachrichten durch den Prozess.
        after Speed ->
            case Pause of
                true -> clock(Speed, Pause, Time);
                false -> clock(Speed, Pause, Time + 1)
            end
    end.

clockTicker(TPid, Pause, Time) -> 
    %io:format("ClockTicker ~p", [self()]),
    receive
        {set, Value} -> clockTicker(TPid, Pause, Value);
        {get, Pid} -> Pid!{clock, Time}, clockTicker(TPid, Pause, Time);
        pause -> clockTicker(TPid, true, Time);
        resume -> clockTicker(TPid, false, Time);
        stop -> ok;
        {setTicker, Pid} ->
            case TPid of
                undefined -> clockTicker(Pid, Pause, Time);
                _ -> clockTicker(TPid, Pause, Time)
            end;
        %Durch TPid garantiert, dass nur der eigene Ticker-Subprozess beachtet wird.
        {tick, TPid} -> 
            case Pause of
                true -> clockTicker(TPid, Pause, Time);
                false -> clockTicker(TPid, Pause, Time + 1)
            end
    end.

ticker(Speed, Pid) ->
    receive
        stop -> ok
        after Speed ->
            Pid!{tick, self()},
            ticker(Speed, Pid)
    end.

startTicker(Speed, Pid) -> spawn(?MODULE, ticker, [Speed, Pid]).
start(Speed) -> spawn(?MODULE, clock, [Speed, false, 0]).
%startT(Speed) -> CT = spawn(?MODULE, clockTicker, [startTicker(Speed, CT), true, 0]), CT.
startT(Speed) -> io:format("Main ~p", [self()]), 
    CT = spawn(?MODULE, clockTicker, [undefined, false, 0]),
    timer:sleep(2000), 
    T = startTicker(Speed, CT), 
    io:format("Ticker ~p", [T]), 
    CT!{setTicker, T}, 
    CT. 

get(Pid) ->
    Pid!{get, self()},
    receive {clock, Value} -> Value end.


timer(TPid, Time, Func) ->
    receive
        {get, Pid} -> Pid!{timerI, Time}, timer(TPid, Time, Func);
        stop -> ok;
        {setTicker, Pid} ->
            case TPid of
                undefined -> timer(Pid, Time, Func);
                _ -> timer(TPid, Time, Func)
            end;
        {tick, TPid} -> 
            case Time - 1 of
                0 -> Func();
                _ -> timer(TPid, Time - 1, Func)
            end
    end.

startTimer(Speed, Time, Func) -> CT = spawn(?MODULE, timer, [undefined, Time, Func]), T = startTicker(Speed, CT), CT!{setTicker, T}, CT.
%startTimer(Speed, Time) -> CT = spawn(?MODULE, timer, [undefined, Time, timerDone]), T = startTicker(Speed, CT), CT!{setTicker, T}, CT.   %Geht so nicht!

timerDone() -> io:format("Timer ist fertig!\n").
%func1 = fun io:format("Timer ist fertig!") end.

% Für den korrekten Aufruf in der Konsole: A = clock:startTimer(10, 1000, fun clock:timerDone/0).

getTimer(Pid) ->
    Pid!{get, self()},
    receive {timerI, Value} -> Value end.


startTS(Speed) -> %io:format("Main ~p", [self()]), 
    CT = spawn(?MODULE, clockTicker, [undefined, false, 0]),
    timer:sleep(2000), 
    T = startTicker(Speed, CT), 
    %io:format("Ticker ~p", [T]), 
    CT!{setTicker, T}, 
    TS = spawn(?MODULE, timeServer, [CT]),
    TS. 


startClient(Speed, TS) -> %io:format("Main ~p", [self()]), 
    CT = spawn(?MODULE, client, [undefined, false, 0, TS]),
    timer:sleep(2000), 
    T = startTicker(Speed, CT), 
    %io:format("Ticker ~p", [T]), 
    CT!{setTicker, T}, 
    CT. 


getTS(Pid) ->
    Pid!{get, self()},
    receive {Timestamp, T2, T3} -> io:format("Local Server Time Before ~p\n", [T2]), io:format("Global Server Time ~p\n", [Timestamp]), io:format("Local Server Time After ~p", [T3]) end.

timeServer(Local) ->
    receive
        {get, Pid} -> 
            Local!{get, self()},
            receive
                {clock, Time} -> T2 = Time
            end,
            Timestamp = erlang:timestamp(),
            Local!{get, self()},
            receive
                {clock, Time2} -> T3 = Time2
            end,
            Pid!{Timestamp, T2, T3},
            timeServer(Local);
        show ->
            Local!{get, self()},
            receive
                {clock, Time} -> io:format("Local Server Time ~p", [Time])
            end,
            timeServer(Local)
    end.

client(TPid, Pause, Time, TS) -> 
    %io:format("Client ~p", [self()]),
    receive
        {set, Value} -> client(TPid, Pause, Value, TS);
        {get, Pid} -> Pid!{clock, Time}, client(TPid, Pause, Time, TS);
        pause -> client(TPid, true, Time, TS);
        resume -> client(TPid, false, Time, TS);
        stop -> ok;
        {setTicker, Pid} ->
            case TPid of
                undefined -> client(Pid, Pause, Time, TS);
                _ -> client(TPid, Pause, Time, TS)
            end;
        %Durch TPid garantiert, dass nur der eigene Ticker-Subprozess beachtet wird.
        {tick, TPid} -> 
            case Pause of
                true -> client(TPid, Pause, Time, TS);
                false -> client(TPid, Pause, Time + 1, TS)
            end;
        adjust -> 
            T1 = Time, 
            TS!{get, self()},
            
            receive
                {{MegaSecs, Secs, MicroSecs}, T2, T3} ->
                    T4 = Time,
                    client(TPid, Pause, 1000000 * 1000 * MegaSecs + 1000 * Secs + MicroSecs + ((T2-T1)+(T4-T3))/2, TS)
            end;
        show ->
            io:format("Local Client Time ~p", [Time]),
            client(TPid, Pause, Time, TS)
        after 100 -> % Alternativ mit eigener Timer-Funktion umzusetzen. Dann unabhängig von den immer erhaltenden Tickernachrichten.
            T1 = Time, 
            TS!{get, self()},
            
            receive
                {{MegaSecs, Secs, MicroSecs}, T2, T3} ->
                    T4 = Time,
                    client(TPid, Pause, 1000000 * 1000 * MegaSecs + 1000 * Secs + MicroSecs + ((T2-T1)+(T4-T3))/2, TS)
            end
    end.

network() -> 
    TS = startTS(1),
    C1 = startClient(1, TS),
    C2 = startClient(100, TS),
    C3 = startClient(10000, TS),
    {C1, C2, C3}.