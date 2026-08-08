defmodule Aesir.ZoneServer.Unit.Player.Handlers.SitHandler do
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @skill_id 223
  @status_id :sc_gangsterparadise
  @range 1

  def handle_sit(%{game_state: game_state} = state) do
    transition(state, game_state, :sitting)
  end

  def handle_stand(%{game_state: game_state} = state) do
    transition(state, game_state, :idle)
  end

  defp transition(state, game_state, action_state) do
    case PlayerState.transition_to(game_state, action_state) do
      {:ok, updated_game_state} ->
        state = StateCommit.commit(state, updated_game_state)
        synchronize_gangster_paradise(updated_game_state)
        {:noreply, state}

      {:error, :invalid_transition} ->
        {:noreply, state}
    end
  end

  defp synchronize_gangster_paradise(%{map_name: map_name, x: x, y: y}) do
    player_ids = SpatialIndex.get_players_in_range(map_name, x, y, @range)

    participants =
      player_ids
      |> Enum.flat_map(&player/1)
      |> Enum.filter(&gangster_sitting?/1)

    Enum.each(
      player_ids,
      &Interpreter.remove_status(:player, &1, @status_id, owner_refresh: :defer)
    )

    if length(participants) > 1 do
      Enum.each(participants, fn %{character_id: character_id} ->
        :ok = Interpreter.apply_status(:player, character_id, @status_id)
      end)
    end
  end

  defp player(character_id) do
    case UnitRegistry.get_unit(:player, character_id) do
      {:ok, {_module, player, _pid}} -> [player]
      {:error, :not_found} -> []
    end
  end

  defp gangster_sitting?(%{
         action_state: :sitting,
         stats: %{progression: %{learned_skills: learned_skills}}
       }) do
    Learned.learned_level(learned_skills, @skill_id) > 0
  end

  defp gangster_sitting?(_player), do: false
end
