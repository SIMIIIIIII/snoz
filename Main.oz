%%% Main Game Controller Module
%%% Coordinates the entire multi-agent snake game.
%%% Manages game state, bot tracking, fruit spawning, and message broadcasting.

functor

import
    Input
    Graphics
    AgentManager
    Application
    System
    OS

define

    StartGame
    Broadcast
    GameController
    Handler
    BotPort
    IsWall
    NewPosition
    SpawnRottenFruit

    % Mapping from bot IDs to color names for display
    ID_to_COLOR = converter(
        1: 'Purple'
        2: 'Marine'
        3: 'Green'
        4: 'Red'
        5: 'Cyan'
    )
in
   
    % Broadcast: Sends a message to all alive bots in the tracker.
    % Inputs:
    %   - Tracker: Record mapping bot IDs to bot information
    %   - Msg: Message to send to each bot's port
    proc {Broadcast Tracker Msg}
        {Record.forAll Tracker proc {$ Tracked}
            if Tracked.alive then {Send Tracked.port Msg} end
        end}
    end

    % GameController: Main game controller function managing game state and logic.
    % Input: State - Current game state
    % Output: Function that processes messages and returns updated controller instance
    % State attributes:
    %   - gui: Graphics object for rendering
    %   - map: Game map (list of 0s and 1s)
    %   - score: Global game score
    %   - gcPort: This controller's port
    %   - tracker: Record tracking all bots (id -> bot(id type port alive score x y))
    %   - active: Number of active bots
    %   - items: Record tracking fruits (index -> fruit(alive), nfruits count, nRfruits count for rotten fruits)
    %   - fruitsEaten: Counter for fruits eaten (used to spawn rotten fruits every 2 fruits)
    fun {GameController State}

        % CheckForWinner: retourne true s'il reste exactement un bot vivant.
        fun {CheckForWinner Tracker}
            AliveList
        in
            AliveList = {Record.filter Tracker fun {$ B} B.alive end}
            {Record.width AliveList} == 1
        end

        fun {OppositeDir Dir}
        case Dir
            of 'north' then 'south'
            [] 'south' then 'north'
            [] 'east'  then 'west'
            [] 'west'  then 'east'
            end
        end

        % MoveTo: Handles bot movement requests.
        % Input: moveTo(Id Dir) message
        %   - Id: Bot identifier requesting to move
        %   - Dir: Direction to move ('north', 'south', 'east', 'west')
        % Output: Updated game controller instance (toujours un contrôleur)
        fun {MoveTo moveTo(Id Dir)}
            Pos NewTracker NewBot NewPos
            AliveList WinnerBot WinnerId
            Last 
        in
            if State.tracker.Id.alive == true then
                
                Pos = pos('x':State.tracker.Id.x  'y':State.tracker.Id.y)

                if {IsWall Pos Dir State} == false then
                    {State.gui moveBot(Id Dir)}
                    NewPos = {NewPosition Pos Dir}
                    NewBot = {Adjoin State.tracker.Id bot(x:NewPos.x y:NewPos.y)}
                    NewTracker = {AdjoinAt State.tracker Id NewBot}
                    
                else
                    % Collision avec un mur → le bot meurt
                    {State.gui dispawnBot(Id)}
                    {State.gui updateMessageBox(ID_to_COLOR.Id # ' died')}

                    {Broadcast State.tracker movedTo(Id State.tracker.Id.type Pos.x Pos.y)}
                    {Send State.tracker.Id.port invalidAction()}

                    % IMPORTANT : mettre alive:false dans le tracker
                    NewBot     = {Adjoin State.tracker.Id bot(alive:false)}
                    NewTracker = {AdjoinAt State.tracker Id NewBot}
                end
            else 
                NewTracker = State.tracker
            end
            
            % Vérifier si un gagnant doit être déclaré
            if {CheckForWinner NewTracker} then
                AliveList = {Record.filter NewTracker fun {$ B} B.alive end}
                WinnerBot = {Record.toList AliveList}.1
                WinnerId  = WinnerBot.id
            in
                {State.gui updateMessageBox(ID_to_COLOR.WinnerId # ' wins the game')}
                {System.show 'Game Over! Winner: ' # ID_to_COLOR.WinnerId #
                             ', Final Score: ' # State.score}
                thread
                    {Delay 10000}     % attendre 10 secondes
                    {Application.exit 0}
                end

            end

            % On renvoie TOUJOURS un nouveau contrôleur (fonction)
            {GameController {AdjoinAt State 'tracker' NewTracker}}
        end

        % FruitSpawned: Handles fruit spawning events.
        % Input: fruitSpawned(X Y) message
        %   - X, Y: Grid coordinates of new fruit
        % Output: Updated game controller instance
        % Adds fruit to items tracker and broadcasts to all bots

        fun {FruitSpawned fruitSpawned(X Y)}
            Index NewItems
        in
            Index = Y * Input.dim + X
            if {HasFeature State 'items'} then
                NewItems = {Adjoin State.items
                        items(Index: fruit('alive': true)
                              'nfruits': State.items.nfruits + 1)}
            else
                NewItems = items(Index: fruit('alive':true)
                                'nRfruits':0
                                'nfruits':1)
            end
            {Broadcast State.tracker fruitSpawned(X Y)}
            {GameController {AdjoinAt State 'items' NewItems}}
        end

        % RottenFruitSpawned: Handles rotten fruit spawning events.
        % Input: rottenFruitSpawned(X Y) message
        %   - X, Y: Grid coordinates of new rotten fruit
        % Output: Updated game controller instance
        % Adds rotten fruit to items tracker and broadcasts to all bots
        fun {RottenFruitSpawned rottenFruitSpawned(X Y)}
            Index NewItems
        in
            Index = Y * Input.dim + X
            if {HasFeature State 'items'} then
                NewItems = {Adjoin State.items
                        items(Index: rottenfruit('alive': true)
                              'nRfruits': State.items.nRfruits + 1)}
            else
                NewItems = items(Index: rottenfruit('alive':true)
                                'nRfruits':1
                                'nfruits':0)
            end
            {Broadcast State.tracker rottenFruitSpawned(X Y)}
            {GameController {AdjoinAt State 'items' NewItems}}
        end

        % FruitDispawned: Handles fruit despawning events.
        % Input: fruitDispawned(X Y) message
        %   - X, Y: Grid coordinates of fruit being removed
        % Output: Updated game controller instance
        % Marks fruit as not alive and broadcasts to all bots
        fun {FruitDispawned fruitDispawned(X Y)}
            I NewItems
        in
            I = Y * Input.dim + X
            if State.items.I.alive == true then
                NewItems ={Adjoin State.items
                        items(I:fruit('alive':false)
                              'nfruits':State.items.nfruits - 1)}
                {Broadcast State.tracker fruitDispawned(X Y)}
                {GameController {AdjoinAt State 'items' NewItems}}
            else
                {GameController State}
            end
        end

        % RottenFruitDispawned: Handles rotten fruit despawning events.
        % Input: rottenFruitDispawned(X Y) message
        %   - X, Y: Grid coordinates of rotten fruit being removed
        % Output: Updated game controller instance
        fun {RottenFruitDispawned rottenFruitDispawned(X Y)}
            I NewItems
        in
            I = Y * Input.dim + X
            if {HasFeature State.items I} andthen State.items.I.alive == true then
                NewItems = {Adjoin State.items
                        items(I:rottenfruit('alive':false)
                              'nRfruits':State.items.nRfruits - 1)}
                {Broadcast State.tracker rottenFruitDispawned(X Y)}
                {GameController {AdjoinAt State 'items' NewItems}}
            else
                {GameController State}
            end
        end

        % MovedTo: Handles notifications that a bot has finished moving.
        % Input: movedTo(Id Type X Y) message
        %   - Id: Bot that moved
        %   - Type: Bot type ('snake')
        %   - X, Y: New grid coordinates
        % Output: Updated game controller instance
        fun {MovedTo movedTo(Id Type X Y)}
            I NewState
        in
            if State.tracker.Id.alive == true then
                I = Y * Input.dim + X
                {Wait State.tracker}

                if Type == 'snake' then
                    if {HasFeature State.items I} andthen
                       {And State.items.I.alive State.tracker.Id.alive} then
                        if {Label State.items.I} == 'fruit' then
                            local TempState1 TempState2 FruitsEaten in
                                % update score and message box
                                {State.gui updateScore(State.score + 1)}
                                {State.gui updateMessageBox(ID_to_COLOR.Id # ' ate a fruit')}

                                % remove the fruit (this will also spawn a new regular fruit)
                                {State.gui dispawnFruit(X Y)}

                                % update the state
                                TempState1 = {AdjoinAt State 'score' State.score+1}
                                TempState2 = {AdjoinAt TempState1 'active' State.active+1}

                                % Grow snake
                                {State.gui ateFruit(X Y Id)}

                                % Check if we should spawn a rotten fruit (every 2 fruits)
                                FruitsEaten = if {HasFeature State 'fruitsEaten'} then State.fruitsEaten + 1 else 1 end
                                if FruitsEaten mod 2 == 0 then
                                    {SpawnRottenFruit State.gui}
                                end
                                NewState = {AdjoinAt TempState2 'fruitsEaten' FruitsEaten}
                            end
                        elseif {Label State.items.I} == 'rottenfruit' then
                            % Snake ate a rotten fruit - just remove it for now
                            {State.gui updateMessageBox(ID_to_COLOR.Id # ' ate a rotten fruit')}
                            {State.gui dispawnRottenFruit(X Y)}
                            NewState = State
                        else
                            NewState = State
                        end
                    else
                        NewState = State
                    end
                else
                    NewState = State
                end
                {Broadcast State.tracker movedTo(Id Type X Y)}
            else
                NewState = State
            end

            {GameController NewState}
        end

        % TellTeam: Handles team communication between bots of the same type.
        % Input: tellTeam(Id Msg) message
        %   - Id: Bot sending the message
        %   - Msg: Message to send to teammates
        fun {TellTeam tellTeam(Id Msg)}
            TeamTracker
            % TeamFilter: Filters bots that are the same type but not the sender
            proc {TeamFilter X ?R}
                if X.type == State.tracker.Id.type andthen X.id \= Id then
                    R = true
                else
                    R = false
                end
            end
        in
            TeamTracker = {Record.filter State.tracker TeamFilter}
            {Broadcast TeamTracker tellTeam(Id Msg)}
            {GameController State}
        end
    in
        % Message dispatcher function
        fun {$ Msg}
            Dispatch = {Label Msg}
            Interface = interface(
                'moveTo': MoveTo
                'movedTo': MovedTo
                'fruitSpawned':FruitSpawned
                'fruitDispawned':FruitDispawned
                'rottenFruitSpawned':RottenFruitSpawned
                'rottenFruitDispawned':RottenFruitDispawned
                'tellTeam':TellTeam
            )
        in
            if {HasFeature Interface Dispatch} then
                {Interface.Dispatch Msg}
            else
                {GameController State}
            end
        end
    end

    % Handler: Processes messages from the stream and updates controller instance.
    % Instance doit TOUJOURS être une fonction contrôleur.
    proc {Handler Stream Instance}
        case Stream
        of Msg | Upcoming then
            local NewInstance in
                NewInstance = {Instance Msg}
                {Handler Upcoming NewInstance}
            end
        [] nil then
            skip
        end
    end

    % SpawnRottenFruit: Spawns a rotten fruit at a random empty location on the grid
    % Input: GUI - Graphics object to render the fruit
    proc {SpawnRottenFruit GUI}
        X Y
    in
        % Spawn inside playable area (avoid walls at borders)
        X = 1 + ({OS.rand} mod (Input.dim - 2))
        Y = 1 + ({OS.rand} mod (Input.dim - 2))
        {GUI spawnRottenFruit(X Y)}
    end

    % IsWall: Checks if moving in a direction would hit a wall.
    fun {IsWall Pos Dir State}
        NewPos = {NewPosition Pos Dir}
        NX = NewPos.x
        NY = NewPos.y
    in
        % Out of grid = wall
        if NX < 0 orelse NX >= Input.dim orelse NY < 0 orelse NY >= Input.dim then
            true
        else
            Index = NY * Input.dim + NX + 1
        in
            {List.nth State.map Index} == 1
        end
    end

    % NewPosition: Calculates the new position after moving in a direction.
    fun {NewPosition Pos Dir}
        X Y NewX NewY
    in
        X = Pos.x
        Y = Pos.y
        case Dir
        of 'north' then NewX=X NewY=Y-1
        [] 'south' then NewX=X NewY=Y+1
        [] 'east'  then NewX=X+1 NewY=Y
        else NewX=X-1 NewY=Y
        end
        pos('x':NewX 'y':NewY)
    end

    % BotPort: Creates and spawns all bots from the Input.bots configuration.
    fun {BotPort GCPort Map GUI Tracker}

        fun {BotPortInner Bots GCPort Map GUI Tracker}
            local Id BotPort in
                case Bots
                of bot(Type Template X Y)|T then
                    case Type
                    of snake then
                        Id = {GUI spawnBot('snake' X Y $)}
                        BotPort =
                            {AgentManager.spawnBot Template init(Id GCPort Map)}
                        {BotPortInner T GCPort Map GUI
                            {AdjoinAt Tracker Id
                                bot(id:Id type:Type port:BotPort
                                    alive:true score:0 x:X y:Y lastDir:none)}}
                    else
                        {BotPortInner T GCPort Map GUI Tracker}
                    end
                [] nil then Tracker
                end
            end
        end

    in
        {BotPortInner Input.bots GCPort Map GUI Tracker}
    end

    % StartGame: Initializes and starts the game.
    proc {StartGame}
        thread
            Stream BotTracker
            Port = {NewPort Stream}
            % 30 is the number of tick per s
            GUI = {Graphics.spawn Port 30}

            Map = {Input.genMap}
            {GUI buildMap(Map)}

            Instance = {GameController state(
                'gui': GUI
                'map': Map
                'score': 0
                'gcPort':Port
                'tracker':BotTracker
                'active':0
                'fruitsEaten':0
            )}
        in
            local Tracker in
                Tracker = tracker()
                BotTracker = {BotPort Port Map GUI Tracker}
            end
            {Handler Stream Instance}
        end

    end

    % Start the game on module load
    {StartGame}
end
