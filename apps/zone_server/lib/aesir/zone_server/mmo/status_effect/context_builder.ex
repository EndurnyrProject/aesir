defmodule Aesir.ZoneServer.Mmo.StatusEffect.ContextBuilder do
  @moduledoc """
  Creates execution contexts for status effect formulas and actions.

  This module provides functions to build and enrich execution contexts with
  the data needed by status effect formulas, conditions, and actions.
  It abstracts away player stats retrieval and context construction logic.

  The context includes:
  - Target and caster stats (str, agi, vit, etc.)
  - State data from the status effect instance
  - Values from the status effect (val1-val4)
  - Additional context data for specific events (damage, healing, etc.)
  """
  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.Stats

  @doc """
  Builds a context map for status effect execution.

  The context includes target stats, caster stats (if available),
  and status effect state and values.

  ## Parameters
    - target_id: The ID of the target entity
    - caster_id: The ID of the caster entity (or nil)
    - instance: The StatusEntry struct representing the status effect instance
    
  ## Returns
    - A map containing all the context needed for formula evaluation
  """
  @spec build_context(integer(), integer() | nil, StatusEntry.t()) :: map()
  def build_context(target_id, caster_id, %StatusEntry{} = instance) do
    # Get the player stats for the target
    target_stats = get_player_stats(target_id)

    # Get the caster stats if available
    caster_stats =
      if caster_id && caster_id != target_id do
        get_player_stats(caster_id)
      else
        # If no caster_id or it's the same as target, use empty map
        %{}
      end

    %{
      # Include IDs for custom functions to access
      target_id: target_id,
      caster_id: caster_id,
      # Stats for formula calculations
      target: target_stats,
      caster: caster_stats,
      state: instance.state || %{},
      val1: instance.val1 || 0,
      val2: instance.val2 || 0,
      val3: instance.val3 || 0,
      val4: instance.val4 || 0
    }
  end

  @doc """
  Enhances an existing context with damage information.

  ## Parameters
    - context: The existing context map
    - damage_info: Map containing damage information (damage, element, type)
    
  ## Returns
    - The enhanced context with damage information
  """
  @spec add_damage_info(map(), map()) :: map()
  def add_damage_info(context, damage_info) do
    Map.put(context, :damage_info, damage_info)
  end

  @doc """
  Get player stats from player session.

  ## Parameters
    - player_id: The ID of the player
    
  ## Returns
    - Map of player stats
    
  ## Raises
    - RuntimeError if player not found or stats can't be retrieved
  """
  @spec get_player_stats(integer()) :: map()
  def get_player_stats(player_id) do
    case :ets.lookup(table_for(:zone_players), player_id) do
      [{^player_id, pid, _account_id}] ->
        # Get stats from player session
        case PlayerSession.get_current_stats(pid) do
          %Stats{} = stats ->
            # Extract relevant stats for status effect calculations
            %{
              max_hp: stats.derived_stats.max_hp,
              max_sp: stats.derived_stats.max_sp,
              hp: stats.current_state.hp,
              sp: stats.current_state.sp,
              level: stats.progression.base_level,
              str: stats.base_stats.str,
              agi: stats.base_stats.agi,
              vit: stats.base_stats.vit,
              int: stats.base_stats.int,
              dex: stats.base_stats.dex,
              luk: stats.base_stats.luk
            }

          _ ->
            # Stats can't be retrieved - critical error
            raise "Failed to retrieve stats for player #{player_id}"
        end

      _ ->
        # Player not found - critical error
        raise "Player #{player_id} not found in zone_players table"
    end
  end
end
