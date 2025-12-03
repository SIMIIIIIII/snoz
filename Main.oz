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
    SpawnRegularFruit
    DeactivatePowerup

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

    % DeactivatePowerup: Deactivates power-up for a specific bot after timer expires
    % Inputs:
    %   - GCPort: Game Controller port
    %   - Id: Bot identifier
    %   - ActivationTime: Time when power-up was activated (to verify it's the same activation)
    proc {DeactivatePowerup GCPort Id ActivationTime}
        {Send GCPort deactivatePowerup(Id ActivationTime)}
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
            Last HasPowerup
        in
            if State.tracker.Id.alive == true then
                
                Pos = pos('x':State.tracker.Id.x  'y':State.tracker.Id.y)
                HasPowerup = State.tracker.Id.powerup == 'invincible'

                if {IsWall Pos Dir State} == false orelse HasPowerup then
                    {State.gui moveBot(Id Dir)}
                    NewPos = {NewPosition Pos Dir}
                    NewBot = {Adjoin State.tracker.Id bot(x:NewPos.x y:NewPos.y)}
                    NewTracker = {AdjoinAt State.tracker Id NewBot}
                    if HasPowerup andthen {IsWall Pos Dir State} then
                        {State.gui updateMessageBox(ID_to_COLOR.Id # ' passed through wall!')}
                    end
                    
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
                {Delay 1000}
                {Application.exit 0}

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

        % CheckSnakeCollision: Checks if a snake collided with another snake's body
        % Returns: bot ID if collision detected, none otherwise
        fun {CheckSnakeCollision X Y MovingSnakeId Tracker}
            fun {CheckAllBots BotIds}
                case BotIds
                of nil then none
                [] BotId|Rest then
                    local Bot in
                        Bot = Tracker.BotId
                        if Bot.alive andthen BotId \= MovingSnakeId then
                            % Check if position matches this snake's position
                            if Bot.x == X andthen Bot.y == Y then
                                BotId
                            else
                                {CheckAllBots Rest}
                            end
                        else
                            {CheckAllBots Rest}
                        end
                    end
                end
            end
        in
            {CheckAllBots {Record.arity Tracker}}
        end

        % CheckAllTailCollisions: Checks if position (X,Y) collides with any snake's tail
        % Returns: bot ID if collision detected, none otherwise
        % Uses a non-blocking approach by checking through GUI with minimal overhead
        fun {CheckAllTailCollisions X Y MovingSnakeId Tracker}
            PixelX = X * 32
            PixelY = Y * 32
            fun {CheckAllBots BotIds}
                case BotIds
                of nil then none
                [] BotId|Rest then
                    local Bot Result in
                        Bot = Tracker.BotId
                        if Bot.alive andthen Bot.type == 'snake' then
                            % Check collision with this snake's tail using GUI
                            try
                                Result = {State.gui checkTailCollision(BotId PixelX PixelY $)}
                                if Result then
                                    BotId
                                else
                                    {CheckAllBots Rest}
                                end
                            catch _ then
                                {CheckAllBots Rest}
                            end
                        else
                            {CheckAllBots Rest}
                        end
                    end
                end
            end
        in
            {CheckAllBots {Record.arity Tracker}}
        end

        % MovedTo: Handles notifications that a bot has finished moving.
        % Input: movedTo(Id Type X Y) message
        %   - Id: Bot that moved
        %   - Type: Bot type ('snake')
        %   - X, Y: New grid coordinates
        % Output: Updated game controller instance
        fun {MovedTo movedTo(Id Type X Y)}
            I NewState NewBot NewTracker
        in
            if State.tracker.Id.alive == true then
                I = Y * Input.dim + X
                {Wait State.tracker}

                % Check for snake-to-snake head collision
                local CollidedSnakeId HasPowerup VictimBot VictimTracker TempState in
                    HasPowerup = State.tracker.Id.powerup == 'invincible'
                    CollidedSnakeId = {CheckSnakeCollision X Y Id State.tracker}
                    
                    if CollidedSnakeId \= none andthen {Not HasPowerup} then
                        % Non-powered snake dies when hitting another snake's head
                        {State.gui dispawnBot(Id)}
                        {State.gui updateMessageBox(ID_to_COLOR.Id # ' hit ' # ID_to_COLOR.CollidedSnakeId # '!')}
                        {Broadcast State.tracker movedTo(Id State.tracker.Id.type X Y)}
                        {Send State.tracker.Id.port invalidAction()}
                        NewBot = {Adjoin State.tracker.Id bot(alive:false)}
                        NewTracker = {AdjoinAt State.tracker Id NewBot}
                        NewState = {AdjoinAt State 'tracker' NewTracker}
                    elseif HasPowerup andthen CollidedSnakeId \= none then
                        % Powered snake kills the other snake
                        {State.gui dispawnBot(CollidedSnakeId)}
                        {State.gui updateMessageBox(ID_to_COLOR.Id # ' destroyed ' # ID_to_COLOR.CollidedSnakeId # '!')}
                        {Broadcast State.tracker movedTo(CollidedSnakeId State.tracker.CollidedSnakeId.type State.tracker.CollidedSnakeId.x State.tracker.CollidedSnakeId.y)}
                        {Send State.tracker.CollidedSnakeId.port invalidAction()}
                        VictimBot = {Adjoin State.tracker.CollidedSnakeId bot(alive:false)}
                        VictimTracker = {AdjoinAt State.tracker CollidedSnakeId VictimBot}
                        TempState = {AdjoinAt State 'tracker' VictimTracker}
                        
                        % Continue with normal processing for the powered snake (can eat fruits, etc.)
                        if Type == 'snake' then
                            if {HasFeature TempState.items I} andthen
                               {And TempState.items.I.alive TempState.tracker.Id.alive} then
                                if {Label TempState.items.I} == 'fruit' then
                                    local TempState1 TempState2 FruitsEaten UpdatedBot UpdatedTracker NewBotScore in
                                        % update score and message box
                                        {State.gui updateScore(TempState.score + 1)}
                                        {State.gui updateMessageBox(ID_to_COLOR.Id # ' ate a fruit')}

                                        % remove the fruit (this will also spawn a new regular fruit)
                                        {State.gui dispawnFruit(X Y)}

                                        % update the state and bot score
                                        NewBotScore = TempState.tracker.Id.score + 1
                                        UpdatedBot = {Adjoin TempState.tracker.Id bot(score:NewBotScore)}
                                        UpdatedTracker = {AdjoinAt TempState.tracker Id UpdatedBot}
                                        TempState1 = {AdjoinAt TempState 'score' TempState.score+1}
                                        TempState2 = {AdjoinAt TempState1 'tracker' UpdatedTracker}
                                        
                                        % Update rankings display
                                        {State.gui updateRankings(UpdatedTracker)}

                                        % Grow snake
                                        {State.gui ateFruit(X Y Id)}

                                        % Check if we should spawn a rotten fruit (every 2 fruits)
                                        FruitsEaten = if {HasFeature TempState 'fruitsEaten'} then TempState.fruitsEaten + 1 else 1 end
                                        if FruitsEaten mod 2 == 0 then
                                            {SpawnRottenFruit State.gui}
                                        end
                                        NewState = {AdjoinAt TempState2 'fruitsEaten' FruitsEaten}
                                    end
                                elseif {Label TempState.items.I} == 'rottenfruit' then
                                    % Snake ate a rotten fruit - lose half of tail length and get power-up
                                    local UpdatedBot ActivationTime UpdatedTracker TempState2 GCPort in
                                        ActivationTime = {OS.rand}
                                        GCPort = State.gcPort
                                        UpdatedBot = {Adjoin TempState.tracker.Id bot(powerup:'invincible' powerupTime:ActivationTime)}
                                        UpdatedTracker = {AdjoinAt TempState.tracker Id UpdatedBot}
                                        TempState2 = {AdjoinAt TempState 'tracker' UpdatedTracker}
                                        
                                        {State.gui updateMessageBox(ID_to_COLOR.Id # ' got invincibility!')}
                                        {State.gui ateRottenFruit(X Y Id)}
                                        {State.gui activatePowerup(Id)}
                                        
                                        % Spawn 2 regular fruits as a reward
                                        {SpawnRegularFruit State.gui}
                                        
                                        % Schedule power-up deactivation after 5 seconds in a separate thread
                                        thread
                                            {Delay 5000}
                                            {Send GCPort deactivatePowerup(Id ActivationTime)}
                                        end
                                        
                                        NewState = TempState2
                                    end
                                else
                                    NewState = TempState
                                end
                            else
                                NewState = TempState
                            end
                        else
                            NewState = TempState
                        end
                        {Broadcast State.tracker movedTo(Id Type X Y)}
                    else
                        % No collision, normal processing
                        if Type == 'snake' then
                            if {HasFeature State.items I} andthen
                               {And State.items.I.alive State.tracker.Id.alive} then
                                if {Label State.items.I} == 'fruit' then
                                    local TempState1 TempState2 FruitsEaten UpdatedBot UpdatedTracker NewBotScore in
                                        % update score and message box
                                        {State.gui updateScore(State.score + 1)}
                                        {State.gui updateMessageBox(ID_to_COLOR.Id # ' ate a fruit')}

                                        % remove the fruit (this will also spawn a new regular fruit)
                                        {State.gui dispawnFruit(X Y)}

                                        % update the state and bot score
                                        NewBotScore = State.tracker.Id.score + 1
                                        UpdatedBot = {Adjoin State.tracker.Id bot(score:NewBotScore)}
                                        UpdatedTracker = {AdjoinAt State.tracker Id UpdatedBot}
                                        TempState1 = {AdjoinAt State 'score' State.score+1}
                                        TempState2 = {AdjoinAt TempState1 'tracker' UpdatedTracker}
                                        
                                        % Update rankings display
                                        {State.gui updateRankings(UpdatedTracker)}

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
                                    % Snake ate a rotten fruit - lose half of tail length and get power-up
                                    local UpdatedBot ActivationTime UpdatedTracker TempState GCPort in
                                        ActivationTime = {OS.rand}
                                        GCPort = State.gcPort
                                        UpdatedBot = {Adjoin State.tracker.Id bot(powerup:'invincible' powerupTime:ActivationTime)}
                                        UpdatedTracker = {AdjoinAt State.tracker Id UpdatedBot}
                                        TempState = {AdjoinAt State 'tracker' UpdatedTracker}
                                        
                                        {State.gui updateMessageBox(ID_to_COLOR.Id # ' got invincibility!')}
                                        {State.gui ateRottenFruit(X Y Id)}
                                        {State.gui activatePowerup(Id)}
                                        
                                        % Spawn 2 regular fruits as a reward
                                        {SpawnRegularFruit State.gui}
                                        
                                        % Schedule power-up deactivation after 5 seconds in a separate thread
                                        thread
                                            {Delay 5000}
                                            {Send GCPort deactivatePowerup(Id ActivationTime)}
                                        end
                                        
                                        NewState = TempState
                                    end
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
                    end
                end
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

        % DeactivatePowerupMsg: Handles power-up deactivation after timer expires
        % Input: deactivatePowerup(Id ActivationTime) message
        fun {DeactivatePowerupMsg deactivatePowerup(Id ActivationTime)}
            NewBot NewTracker
        in
            % Only deactivate if this is the same power-up activation (not a newer one)
            if {HasFeature State.tracker Id} andthen 
               State.tracker.Id.powerup == 'invincible' andthen
               State.tracker.Id.powerupTime == ActivationTime then
                NewBot = {Adjoin State.tracker.Id bot(powerup:none powerupTime:0)}
                NewTracker = {AdjoinAt State.tracker Id NewBot}
                {State.gui deactivatePowerup(Id)}
                {State.gui updateMessageBox(ID_to_COLOR.Id # ' lost invincibility')}
                {GameController {AdjoinAt State 'tracker' NewTracker}}
            else
                {GameController State}
            end
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
                'deactivatePowerup':DeactivatePowerupMsg
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

    % SpawnRegularFruit: Spawns 2 regular fruits at random empty locations
    % Input: GUI - Graphics object to render the fruits
    proc {SpawnRegularFruit GUI}
        proc {SpawnOne}
            X Y
        in
            % Spawn inside playable area (avoid walls at borders)
            X = 1 + ({OS.rand} mod (Input.dim - 2))
            Y = 1 + ({OS.rand} mod (Input.dim - 2))
            {GUI spawnFruit(X Y)}
        end
    in
        {SpawnOne}
        {SpawnOne}
        
    end

    % SpawnRottenFruit: Spawns a rotten fruit at a random empty location on the grid
    % Input: GUI - Graphics object to render the fruit
    % Spawns 3 rotten fruits
    proc {SpawnRottenFruit GUI}
        proc {SpawnOne}
            X Y
        in
            % Spawn inside playable area (avoid walls at borders)
            X = 1 + ({OS.rand} mod (Input.dim - 2))
            Y = 1 + ({OS.rand} mod (Input.dim - 2))
            {GUI spawnRottenFruit(X Y)}
        end
    in
        {SpawnOne}
        {SpawnOne}
        {SpawnOne}
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
                                    alive:true score:0 x:X y:Y lastDir:none
                                    powerup:none powerupTime:0)}}
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
