defmodule Aesir.ZoneServer.Unit.Player.DieCounter do
  @moduledoc """
  The player's death counter, kept as the permanent char variable
  `PC_DIE_COUNTER` (readable and settable by scripts like any char variable).

  Every death adds one. A Super Novice-classed player whose counter is still 0
  gets +10 to every base stat (from job level 70, or at any level in the
  expanded Super Novice line); the counter reaching 1 on such a player is a full
  stat recalculation that removes the bonus.
  """

  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Unit.Player.Handlers.StatusManager
  alias Aesir.ZoneServer.Unit.Player.StateCommit
  alias Aesir.ZoneServer.Unit.Player.Stats

  @var "PC_DIE_COUNTER"

  @doc "The char variable holding the counter."
  @spec var() :: String.t()
  def var, do: @var

  @doc "The player's death count; `0` when unknown."
  @spec count(map() | nil) :: non_neg_integer()
  def count(%{vars: %{@var => count}}) when is_integer(count), do: count
  def count(_player), do: 0

  @doc "Adds one death to the counter."
  @spec increment(map()) :: map()
  def increment(%{game_state: game_state} = state), do: put(state, count(game_state) + 1)

  @doc """
  Sets the counter to `value`, persisting it. A negative value or the current
  one changes nothing. Setting a Super Novice-classed player's counter to 1
  recalculates their stats in full.
  """
  @spec put(map(), integer()) :: map()
  def put(%{game_state: game_state} = state, value) do
    if value < 0 or value == count(game_state) do
      state
    else
      vars = Map.put(game_state.vars, @var, value)
      CharacterPersistence.update_character(game_state.character_id, %{vars: vars}, async: true)

      lost_bonus? =
        value == 1 and JobLineage.super_novice_classed?(game_state.stats.progression.job_id)

      game_state = %{game_state | vars: vars}

      if lost_bonus? do
        stats = Stats.force_full_recalculation(game_state.stats)

        state
        |> StateCommit.commit(%{game_state | stats: stats})
        |> StatusManager.recalculate_after_status_change()
      else
        StateCommit.commit(state, game_state)
      end
    end
  end
end
