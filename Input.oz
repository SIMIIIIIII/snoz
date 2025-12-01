%%% Input Configuration Module
%%% Defines the game configuration including grid dimensions, bot spawning locations, and map generation.

functor
export
    'genMap': MapGenerator
    'bots': Bots
    'dim': Dim
define
    % Grid dimension (Dim x Dim grid)
    Dim = 30

    % List of bots to spawn in the game.
    % Each bot is defined as: bot(Type TemplateAgent X Y)
    Bots = [
        bot('snake' 'AgentBlank' (Dim div 2) (Dim div 4))        % haut-centre
        bot('snake' 'AgentBlank' (Dim div 2) (3 * Dim div 4))    % bas-centre
        bot('snake' 'AgentBlank' (Dim div 4) (Dim div 2))        % centre-gauche
        bot('snake' 'AgentBlank' (3 * Dim div 4) (Dim div 2))    % centre-droit
        bot('snake' 'AgentBlank' (Dim div 2) (Dim div 2))        % centre exact
    ]

    % MapGenerator: Generates the game map as a list of integers.
    fun {MapGenerator}
        % GridStructure: Recursively builds the map grid.
        % Input: Acc - Current index in the grid (0 to Dim*Dim - 1)
        % Output: List of 0s and 1s representing the grid structure
        fun {GridStructure Acc}
            Next
        in
            if Acc < Dim*Dim then
                % Check if on border
                if Acc < Dim then  % First row
                    Next = 1
                elseif Acc >= (Dim-1)*Dim then  % Last row
                    Next = 1
                elseif Acc mod Dim == 0 then  % First column
                    Next = 1
                elseif Acc mod Dim == Dim-1 then  % Last column
                    Next = 1
                else
                    Next = 0
                end
                Next | {GridStructure Acc+1}
            else
                nil
            end
        end
    in
        {GridStructure 0}
    end
end
