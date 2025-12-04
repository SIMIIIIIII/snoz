%%% Input Configuration Module
%%% Defines the game configuration including grid dimensions, bot spawning locations, and map generation.

functor
import
    OS
export
    'genMap': MapGenerator
    'bots': Bots
    'dim': Dim
define
    % Grid dimension (Dim x Dim grid)
    Dim = 24
    
    ObstacleDensity = 0.05
    
    Bots = [
        bot('snake' 'AgentBlank' (Dim div 2) (Dim div 4))        % haut-centre (Purple)
        bot('snake' 'AgentBlank' (Dim div 2) (3 * Dim div 4))    % bas-centre (Marine)
        bot('snake' 'AgentBlank' (Dim div 4) (Dim div 2))        % centre-gauche (Green)
        bot('snake' 'AgentHuman' (3 * Dim div 4) (Dim div 2))    % centre-droit (Red - HUMAN PLAYER)
        bot('snake' 'AgentBlank' (Dim div 2) (Dim div 2))        % centre exact (Cyan)
    ]

    % Random number generator state
    local
        RandGen = {New class $
            attr seed
            meth init
                seed := {OS.rand}
            end
            meth next(?R)
                % Linear congruential generator
                seed := (@seed * 1103515245 + 12345) mod 2147483648
                R = @seed
            end
        end init}
    in
        fun {Random}
            R
        in
            {RandGen next(R)}
            R
        end
    end

    % Check if a position is a bot spawn location
    fun {IsBotSpawn X Y}
        {Some Bots fun {$ Bot}
            case Bot of bot(_ _ BX BY) then
                BX == X andthen BY == Y
            else
                false
            end
        end}
    end

    % Helper function for Some
    fun {Some Xs P}
        case Xs of nil then false
        [] X|Xr then
            if {P X} then true
            else {Some Xr P}
            end
        end
    end

    % Convert list to array for efficient access
    fun {ListToArray Lst}
        fun {Helper L Index Arr}
            case L of nil then Arr
            [] H|T then
                {Helper T Index+1 {AdjoinAt Arr Index H}}
            end
        end
    in
        {Helper Lst 0 arr()}
    end

    % Get map value at position (X, Y) from array
    fun {GetMapValue MapArr X Y}
        Index = Y * Dim + X
    in
        if {HasFeature MapArr Index} then MapArr.Index
        else 1  % Out of bounds = wall
        end
    end

    % Flood fill to check connectivity from a starting point
    % Returns number of reachable cells
    fun {FloodFill MapArr StartX StartY}
        % Visited array to track explored cells
        fun {FloodFillHelper X Y Visited Count}
            Index = Y * Dim + X
        in
            % Check bounds
            if X < 0 orelse X >= Dim orelse Y < 0 orelse Y >= Dim then
                visited(v:Visited c:Count)
            % Check if already visited
            elseif {HasFeature Visited Index} then
                visited(v:Visited c:Count)
            % Check if it's a wall
            elseif {GetMapValue MapArr X Y} == 1 then
                visited(v:Visited c:Count)
            else
                % Mark as visited and explore neighbors
                NewVisited = {AdjoinAt Visited Index true}
                R1 = {FloodFillHelper X+1 Y NewVisited Count+1}
                R2 = {FloodFillHelper X-1 Y R1.v R1.c}
                R3 = {FloodFillHelper X Y+1 R2.v R2.c}
                R4 = {FloodFillHelper X Y-1 R3.v R3.c}
            in
                R4
            end
        end
        Result
    in
        Result = {FloodFillHelper StartX StartY visited() 0}
        Result.c
    end

    % Check if a map has no enclosed areas
    % All walkable cells should be reachable from any starting walkable cell
    fun {IsMapValid MapArr}
        % Find first walkable cell
        fun {FindFirstWalkable Index}
            if Index >= Dim*Dim then
                none
            elseif {List.nth MapArr Index+1} == 0 then
                pos(x:(Index mod Dim) y:(Index div Dim))
            else
                {FindFirstWalkable Index+1}
            end
        end
        
        % Count total walkable cells
        fun {CountWalkable Lst Acc}
            case Lst of nil then Acc
            [] 0|T then {CountWalkable T Acc+1}
            [] _|T then {CountWalkable T Acc}
            end
        end
        
        FirstPos TotalWalkable ReachableCount MapArray
    in
        MapArray = {ListToArray MapArr}
        FirstPos = {FindFirstWalkable 0}
        TotalWalkable = {CountWalkable MapArr 0}
        
        case FirstPos of none then
            true  % No walkable cells, technically valid
        [] pos(x:X y:Y) then
            ReachableCount = {FloodFill MapArray X Y}
            ReachableCount == TotalWalkable
        end
    end

    % MapGenerator: Generates a validated map with no enclosed areas
    fun {MapGenerator}
        % GridStructure: Recursively builds the map grid with connectivity validation
        fun {GridStructure Acc}
            Next
            X = Acc mod Dim
            Y = Acc div Dim
        in
            if Acc < Dim*Dim then
                % Check if on border
                if Acc < Dim then
                    Next = 1
                elseif Acc >= (Dim-1)*Dim then 
                    Next = 1
                elseif Acc mod Dim == 0 then
                    Next = 1
                elseif Acc mod Dim == Dim-1 then
                    Next = 1
                
                elseif {IsBotSpawn X Y} then
                    Next = 0  
                
                else
                    RandVal = {Random} mod 10000
                    Threshold = {FloatToInt ObstacleDensity * 10000.0}
                in
                    if RandVal < Threshold then
                        Next = 1  % Obstacle
                    else
                        Next = 0  % Empty space
                    end
                end
                Next | {GridStructure Acc+1}
            else
                nil
            end
        end
        
        % Generate and validate map
        fun {GenerateValidMap Attempts}
            if Attempts > 50 then
                % Fallback: return map with only borders
                fun {SafeMap Acc}
                    if Acc < Dim*Dim then
                        X = Acc mod Dim
                        Y = Acc div Dim
                    in
                        if Acc < Dim orelse Acc >= (Dim-1)*Dim orelse
                           Acc mod Dim == 0 orelse Acc mod Dim == Dim-1 then
                            1 | {SafeMap Acc+1}
                        else
                            0 | {SafeMap Acc+1}
                        end
                    else
                        nil
                    end
                end
            in
                {SafeMap 0}
            else
                Map = {GridStructure 0}
            in
                if {IsMapValid Map} then
                    Map
                else
                    {GenerateValidMap Attempts+1}
                end
            end
        end
    in
        {GenerateValidMap 0}
    end
end
