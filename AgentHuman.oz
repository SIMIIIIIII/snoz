%%% Human Agent - Controlled by keyboard
%%% Allows a human player to control a snake using arrow keys

functor
export
    'getPort': SpawnAgent
define

    fun {Agent State}
        fun {ChangeDirection changeDirection(NewDir)}
            if State.alive then
                % Just update direction, MovedTo will send the next moveTo
                {Agent {Adjoin State state(dir:NewDir)}}
            else
                {Agent State}
            end
        end
        
        fun {InitPos initPosition(Id _ X Y)}
            if Id == State.id andthen State.alive then
                NewState = {Adjoin State state(x:X y:Y dir:'north')}
            in
                {Send State.gcport moveTo(State.id 'north')}
                {Agent NewState}
            else
                {Agent State}
            end
        end
        
        fun {MovedTo movedTo(Id _ X Y)}
            if Id == State.id andthen State.alive then
                NewState = {Adjoin State state(x:X y:Y)}
            in
                {Send State.gcport moveTo(State.id State.dir)}
                {Agent NewState}
            else
                {Agent State}
            end
        end
        
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
                'changeDirection': ChangeDirection
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
            'dir': 'north'
            'x': ~1
            'y': ~1
            'port': Port
            'alive': true
        )}
    in
        thread {Handler Stream Instance} end
        Port
    end
end
