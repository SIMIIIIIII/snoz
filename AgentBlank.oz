functor

import
    OS
    Input
export
    'getPort': SpawnAgent
define

    % Mapping from random numbers (1-4) to cardinal directions
    Directions = directions(
        1: 'north'
        2: 'south'
        3: 'east'
        4: 'west'
    )

    fun {RandomDir}
        Directions.({OS.rand} mod 4 + 1)
    end

    fun {OppositeDir Dir}
        case Dir
        of 'north' then 'south'
        [] 'south' then 'north'
        [] 'east'  then 'west'
        [] 'west'  then 'east'
        [] 'stopped' then 'stopped'
        end
    end

    fun {NextDir S}
        OldDir = S.dir
    in
        if OldDir == 'stopped' then
            {RandomDir}
        else
            fun {Loop}
                D = {RandomDir}
            in
                if D == {OppositeDir OldDir} then {Loop} else D end
            end
        in
            {Loop}
        end
    end


    fun {Agent State}

        % Init position du snake
        fun {InitPos initPosition(Id _ X Y)}
            if Id == State.id andthen State.alive then
                Dir = {RandomDir}
                NewState = {Adjoin State state(x:X y:Y dir:Dir)}
            in
                {Send State.gcport moveTo(State.id Dir)}
                {Agent NewState}
            else
                {Agent State}
            end
        end

        % MovedTo: on vient de finir un mouvement, on choisit la prochaine direction
        fun {MovedTo movedTo(Id _ X Y)}
            if Id == State.id andthen State.alive then
                Tmp      = {Adjoin State state(x:X y:Y)}
                NewDir   = {NextDir Tmp}
                NewState = {Adjoin Tmp state(dir:NewDir)}
            in
                {Send State.gcport moveTo(State.id NewDir)}
                {Agent NewState}
            else
                {Agent State}
            end
        end

        % invalidAction() → le controller nous tue
        fun {HandleDeath invalidAction()}
            {Agent {Adjoin State state(alive:false)}}
        end

    in
        fun {$ Msg}
            Dispatch = {Label Msg}
            Interface = interface(
                'invalidAction': HandleDeath
                'movedTo':       MovedTo
                'initPosition':  InitPos
            )
        in
            if {HasFeature Interface Dispatch} then
                {Interface.Dispatch Msg}
            else
                {Agent State}
            end
        end
    end


    proc {Handler Msg | Upcoming Instance}
        if Msg \= shutdown() then
            {Handler Upcoming {Instance Msg}}
        end
    end

    fun {SpawnAgent init(Id GCPort Map)}
        Stream
        Port = {NewPort Stream}
        Instance = {Agent state(
            'id': Id
            'map': Map
            'gcport': GCPort
            'dir': 'stopped'
            'x': ~1
            'y': ~1
            'tracker': tracker()
            'port': Port
            'alive': true
        )}
    in
        thread {Handler Stream Instance} end
        Port
    end
end
