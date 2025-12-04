%%% Agent Manager Module
%%% Manages the creation and spawning of different agent types.
%%% Acts as a factory for creating agent instances based on their template name.

functor

import
    System
    SnakeBotExample
    AgentBlank
    AgentHuman
export
    'spawnBot': SpawnBot
    'getHumanPort': GetHumanPort
define

    HumanAgentPort = {NewCell unit}

    % SpawnBot: Creates and returns a port for the specified agent type.
    % Inputs:
    %   - BotName: Atom representing the agent template ('SnakeBotRandom', 'AgentBlank', 'AgentHuman')
    %   - Init: Initialization record containing init(Id GCPort Map)
    %     * Id: Unique identifier for the agent
    %     * GCPort: Port to the Game Controller for sending messages
    %     * Map: The game map as a list
    % Output: Port to communicate with the spawned agent, or false if BotName is unknown
    fun {SpawnBot BotName Init}
        case BotName of
            'SnakeBotExample' then {SnakeBotExample.getPort Init}
            []'AgentBlank' then {AgentBlank.getPort Init}
            []'AgentHuman' then
                Port = {AgentHuman.getPort Init}
            in
                HumanAgentPort := Port  % Store the port for keyboard control
                Port
        else
            {System.show 'Unknown BotName'}
            false
        end
    end

    % GetHumanPort: Returns the port of the human-controlled agent
    fun {GetHumanPort}
        @HumanAgentPort
    end
end