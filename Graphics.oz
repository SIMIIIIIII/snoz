%%% Graphics Module
%%% Manages all graphical rendering, game objects, and the GUI window.
%%% Handles drawing of snakes, fruits, the map, and game state display.

functor

import
    OS
    Application
    QTk at 'x-oz://system/wp/QTk.ozf'
    Input
export
    'spawn': SpawnGraphics
define
    % Constants for graphics
    CD = {OS.getCWD}
    FONT = {QTk.newFont font('size': 18)}
    WALL_TILE = {QTk.newImage photo(file: CD # '/assets/wall.png')}
    DEFAULT_GROUND_TILE = {QTk.newImage photo(file: CD # '/assets/ground/ground_1.png')}

    FRUIT_SPRITE = {QTk.newImage photo(file: CD # '/assets/fruit.png')}
    ROTTEN_FRUIT_SPRITE = {QTk.newImage photo(file: CD # '/assets/rotten_fruit.png')}
    
    % GameObject: Base class for all game entities.
    % Attributes:
    %   - id: Unique identifier for the object
    %   - type: Type of object ('snake', etc.)
    %   - sprite: QTk image to render
    %   - x, y: Pixel coordinates for rendering (not grid coordinates)
    % Methods:
    %   - init(Id Type Sprite X Y): Initializes the game object
    %   - getType($): Returns the type of this object
    %   - render(Buffer): Renders the sprite onto the given buffer
    %   - update(GCPort): Updates the object state (overridden in subclasses)
    class GameObject
        attr 'id' 'type' 'sprite' 'x' 'y'

        % init: Initializes a game object.
        % Inputs: Id (integer), Type (atom), Sprite (QTk image), X (pixels), Y (pixels)
        meth init(Id Type Sprite X Y)
            'id' := Id
            'type' := Type
            'sprite' := Sprite
            'x' := X
            'y' := Y
        end

        % getType: Returns the type of this game object.
        % Output: Type atom
        meth getType($) @type end

        % render: Draws this object on the given buffer.
        % Input: Buffer (QTk image buffer)
        meth render(Buffer)
            {Buffer copy(@sprite 'to': o(@x @y))}
        end



        % update: Updates object state each frame (default: no-op).
        % Input: GCPort (Game Controller port)
        meth update(GCPort) skip end 
    end

    % Snake: Represents a snake game object with animated movement.
    % Inherits from: GameObject
    % Attributes (in addition to GameObject):
    %   - isMoving: Boolean, true when snake is animating movement
    %   - moveDir: Current movement direction ('north', 'south', 'east', 'west')
    %   - targetX, targetY: Target pixel coordinates for current movement
    %   - tail: List of body parts (body_part(x y))                                 
    %   - length: Current length of the snake
    % Methods:
    %   - init(Id X Y): Initializes the snake at pixel coordinates (X, Y)
    %   - setTarget(Dir): Sets movement direction and target coordinates            
    %   - move(GCPort): Moves snake towards target by 4 pixels per frame
    %   - update(GCPort): Called each frame to update snake position                
    %   - grow(Size): Increases snake length (currently unimplemented)
    class Snake from GameObject
        attr 'isMoving' 'moveDir' 'targetX' 'targetY'
        'tail' 'length'

        % init: Initializes a snake.
        % Inputs: Id (unique identifier), X (pixel x-coord), Y (pixel y-coord)
        meth init(Id X Y)
            GameObject, init(Id 'snake' {QTk.newImage photo(file: CD # '/assets/SNAKE_' # Id # '/body.png')} X Y)  
            'isMoving' := false
            'targetX' := X
            'targetY' := Y
            'tail' := body_part(x:X y:Y)|nil
            'length' := 3   % 1 what pixel or what exactly
        end

        % setTarget: Sets the movement direction and calculates target coordinates.
        % Input: Dir (direction atom: 'north', 'south', 'east', 'west')
        % Sets target 32 pixels away in the specified direction
        meth setTarget(Dir) 
            'isMoving' := true
            'moveDir' := Dir
            if Dir == 'north' then
                'targetY' := @y - 32
            elseif Dir == 'south' then
                'targetY' := @y + 32
            elseif Dir == 'east' then
                'targetX' := @x + 32
            elseif Dir == 'west' then
                'targetX' := @x - 32
            end
        end

        % move: Animates movement by updating position 4 pixels per frame.
        % Input: GCPort (Game Controller port)
        % Sends movedTo message when target is reached
        meth move(GCPort)
            OldX = @x  % Correction : Sauvegarde l'ancienne position de la tête (avant mouvement)
            OldY = @y
            NewBodyPart
            TailNew
            TailLen
        in
            % Met à jour la position de la tête (comme avant)
            if @moveDir == 'north' then
                'y' := @y - 4
            elseif @moveDir == 'south' then
                'y' := @y + 4
            elseif @moveDir == 'east' then
                'x' := @x + 4
            elseif @moveDir == 'west' then
                'x' := @x - 4
            end

            % Correction : Ajoute l'ANCIENNE position de la tête à la queue (pas la nouvelle)
            NewBodyPart = body_part(x:OldX y:OldY)
            TailNew = NewBodyPart | @tail
            TailLen = {List.length TailNew}

            % Correction : Limite la queue à length - 1 (car length inclut la tête)
            if TailLen > @length - 1 then
                'tail' := {List.take TailNew @length - 1}
            else
                'tail' := TailNew
            end

            % Envoie movedTo quand arrivé (comme avant)
            if @x == @targetX andthen @y == @targetY then
                NewX = @x div 32
                NewY = @y div 32
            in
                'isMoving' := false
                {Send GCPort movedTo(@id @type NewX NewY)}
            end
        end


        % update: Called each frame to update snake state.
        % Input: GCPort (Game Controller port)
        meth update(GCPort)
            if @isMoving then
                {self move(GCPort)}
            end
        end

        % grow: Increases snake length
        % Input: Size (number of segments to add)
        meth grow(Size)                                         %it is not implemented and i have never used it
            % TODO
            % Increase the length of the snake
            % Modify the tail attribute
            % Render the tail (Not in this method)
            'length' := @length + Size
        end

        meth render(Buffer)
            % 1. Dessiner la tête
            {Buffer copy(@sprite 'to': o(@x @y))}

            % 2. Dessiner la queue
            for body_part(x:TX y:TY) in @tail do
                {Buffer copy(@sprite 'to': o(TX TY))}
            end
        end

    end

    % Graphics: Main graphics management class
    class Graphics
        attr
            'buffer' 'buffered' 'canvas' 'window'
            'score' 'scoreHandle'
            'ids' 'gameObjects'
            'background'
            'running'
            'gcPort'
            'lastMsg'
            'lastMsgHandle'
            'grid_dim'

        % init: Initializes the graphics system and creates the game window.
        % Input: GCPort (Port to the Game Controller)
        % Creates a window with canvas, buttons, score display, and message box
        meth init(GCPort)
            Height
            GridWidth
            PanelWidth = 400
            Width
        in
            'running' := true
            'gcPort' := GCPort
            'grid_dim' := Input.dim

            Height = @grid_dim*32
            GridWidth = @grid_dim*32
            Width = GridWidth + PanelWidth

            'buffer' := {QTk.newImage photo('width': GridWidth 'height': Height)}
            'buffered' := {QTk.newImage photo('width': GridWidth 'height': Height)}

            'window' := {QTk.build td(
                canvas(
                    'handle': @canvas
                    'width': Width
                    'height': Height
                    'background': 'black'
                )
                button(
                    'text': "close"
                    'action' : proc {$} {Application.exit 0} end
                )
            )}

            'score' := 0
            'lastMsg' := 'Message box is empty'
            {@canvas create('image' GridWidth div 2 Height div 2 'image': @buffer)}
            {@canvas create('text' GridWidth+(PanelWidth div 2) 50 'text': 'score: 0' 'fill': 'white' 'font': FONT 'handle': @scoreHandle)}
            {@canvas create('text' GridWidth+(PanelWidth div 2) 100 'text': 'Message box: empty' 'fill': 'white' 'font': FONT 'handle': @lastMsgHandle)}
            'background' := {QTk.newImage photo('width': GridWidth 'height': Height)}
            {@window 'show'}

            'gameObjects' := {Dictionary.new}
            'ids' := 0
        end

        % isRunning: Returns whether the graphics system is running.
        % Output: Boolean
        meth isRunning($) @running end

        % genId: Generates a unique identifier.
        % Output: Integer ID
        meth genId($)
            'ids' := @ids + 1
            @ids
        end

        % spawnFruit: Spawns a fruit at the given grid coordinates.                       
        % Inputs: X (grid x), Y (grid y)
        % Draws fruit on background and notifies Game Controller
        meth spawnFruit(X Y)
            {@background copy(FRUIT_SPRITE 'to': o(X * 32 Y * 32))}
            {Send @gcPort fruitSpawned(X Y)}
        end

        % dispawnFruit: Removes a fruit and schedules respawn after 500ms.                  
        % Inputs: X (grid x), Y (grid y)
        meth dispawnFruit(X Y)
            NewX NewY
        in
            % Spawn inside playable area (avoid walls at borders)
            NewX = 1 + ({OS.rand} mod (@grid_dim - 2))
            NewY = 1 + ({OS.rand} mod (@grid_dim - 2))
            thread
                {self spawnFruit(NewX NewY)}
            end
            {@background copy(DEFAULT_GROUND_TILE 'to': o(X * 32 Y * 32))}
            {Send @gcPort fruitDispawned(X Y)}
        end

        % spawnRottenFruit: Spawns a rotten fruit at the given grid coordinates.
        % Inputs: X (grid x), Y (grid y)
        % Draws rotten fruit on background and notifies Game Controller
        meth spawnRottenFruit(X Y)
            {@background copy(ROTTEN_FRUIT_SPRITE 'to': o(X * 32 Y * 32))}
            {Send @gcPort rottenFruitSpawned(X Y)}
        end

        % dispawnRottenFruit: Removes a rotten fruit from the grid.
        % Inputs: X (grid x), Y (grid y)
        meth dispawnRottenFruit(X Y)
            {@background copy(DEFAULT_GROUND_TILE 'to': o(X * 32 Y * 32))}
            {Send @gcPort rottenFruitDispawned(X Y)}
        end

        % ateFruit: Handles a snake eating a fruit.
        % Inputs: X (grid x), Y (grid y), Id (bot identifier)                             %should use this i think to increase its length
        % Makes the snake grow by 1 segment
        meth ateFruit(X Y Id)
            Bot = {Dictionary.condGet @gameObjects Id 'null'}
        in
            if Bot \= 'null' then
                {Bot grow(5)}                % augmente la longueur logique
                {self dispawnFruit(X Y)}      % enlève le fruit de la map
            end
        end


        % buildMap: Constructs the static background from the map.                          %buildmap
        % Input: Map (list of 0s and 1s, where 1=wall, 0=empty)
        % Draws walls and ground tiles, randomly spawns fruits
        % Random fruit generation
        meth buildMap(Map)
            Z = {NewCell 0}
        in
            for K in Map do
                X = @Z mod @grid_dim
                Y = @Z div @grid_dim
                Rand_n = {OS.rand}
                Tile_index = (Rand_n mod 3)+1
            in
                if K == 0 then
                    {@background copy({QTk.newImage photo(file: CD # '/assets/ground/ground_' # Tile_index # '.png')} 'to': o(X * 32 Y * 32))}
                    % Only spawn fruits inside playable area (avoid walls at borders)
                    if X > 0 andthen X < @grid_dim-1 andthen Y > 0 andthen Y < @grid_dim-1 andthen Rand_n mod (((Input.dim-1)*(Input.dim-1)) div 8) == 0 then {self spawnFruit(X Y)} end
                elseif K == 1 then
                    {@background copy(WALL_TILE 'to': o(X * 32 Y * 32))}
                end
                Z := @Z + 1
            end
        end

        % spawnBot: Creates and registers a new bot sprite.
        % Inputs: Type ('snake'), X (grid x), Y (grid y)                            %new bot id
        % Output: Unique bot ID
        % Notifies Game Controller that bot has spawned
        meth spawnBot(Type X Y $)
            Bot
            Id = {self genId($)}
        in
            if Type == 'snake' then
                Bot = {New Snake init(Id X * 32 Y * 32)}
            else
                skip
            end

            {Dictionary.put @gameObjects Id Bot}
            {Send @gcPort movedTo(Id Type X Y)}
            Id
        end

        % dispawnBot: Removes a bot from the game.                                  %removes a bot from the game
        % Input: Id (bot identifier)
        meth dispawnBot(Id)
            {Dictionary.remove @gameObjects Id}
        end

        % moveBot: Initiates movement for a bot in the specified direction.
        % Inputs: Id (bot identifier), Dir (direction atom)
        meth moveBot(Id Dir)
            Bot = {Dictionary.condGet @gameObjects Id 'null'}
        in
            if Bot \= 'null' then
                {Bot setTarget(Dir)}
            end
        end

        % updateScore: Updates the displayed score.
        % Input: NewScore (integer)
        meth updateScore(NewScore)
            'score' := NewScore
            {@scoreHandle set('text': "score: " # @score)}
        end

        % updateMessageBox: Updates the message box display.
        % Input: Msg (string or atom to display)
        meth updateMessageBox(Msg)
            'lastMsg' := Msg
            {@lastMsgHandle set('text': "Message box: " # @lastMsg)}
        end

        % update: Main rendering loop - updates and draws all game objects.
        % Called each frame by the ticker thread
        % Uses double buffering: draws to buffered, then copies to buffer
        meth update()
            GameObjects = {Dictionary.items @gameObjects}
        in
            {@buffered copy(@background 'to': o(0 0))}
            for Gobj in GameObjects do
                {Gobj update(@gcPort)}
                {Gobj render(@buffered)}
            end
            {@buffer copy(@buffered 'to': o(0 0))}
        end
    end

    % NewActiveObject: Creates an active object that processes messages in a separate thread.
    % Inputs:
    %   - Class: Class to instantiate
    %   - Init: Initialization method to call
    % Output: Procedure that sends messages to the object
    fun {NewActiveObject Class Init}
        Stream
        Port = {NewPort Stream}
        Instance = {New Class Init}
    in
        thread
            for Msg in Stream do {Instance Msg} end
        end

        proc {$ Msg} {Send Port Msg} end
    end

    % SpawnGraphics: Creates and starts the graphics system with a rendering loop.
    % Inputs:
    %   - Port: Game Controller port
    %   - FpsMax: Maximum frames per second (e.g., 30)
    % Output: Active Graphics object (procedure to send messages)
    % Starts a ticker thread that calls update() every FrameTime milliseconds
    fun {SpawnGraphics Port FpsMax}
        Active = {NewActiveObject Graphics init(Port)}
        FrameTime = 1000 div FpsMax

        % Ticker: Recursive procedure that runs the render loop.
        proc {Ticker}
            if {Active isRunning($)} then
                {Active update()}
                {Delay FrameTime}
                {Ticker}
            end
        end
    in
        thread {Ticker} end
        Active
    end
end