defmodule Aesir.ZoneServer.Mmo.Skills.Clown.CgLongingfreedom do
  @moduledoc """
  Longing for Freedom relaxes a pre-renewal ensemble lock for three minutes.

  It costs fifteen SP and permits walking, attacking and non-performance skills,
  with level-dependent movement/ASPD penalties and triple performing upkeep.
  The field stays put; leaving it ends the ensemble. Moonlit refuses this skill,
  and Moonlit/Hermode always-rooted fields stay rooted even under an older Longing.
  It is absent from the renewal skill tree, though the module exists in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 487,
    name: :cg_longingfreedom,
    display_name: "Longing for Freedom",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    sp_cost: List.duplicate(15, 5),
    duration: List.duplicate(180_000, 5),
    status: :sc_longing,
    damage_kind: :none

  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @doc """
  Frees the caster's ensemble lock. Outside a non-Moonlit ensemble, or with
  Longing already active, the paid use ends without effect and without a
  failure.
  """
  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:skipped, PlayerState.t(), atom()}
  def cast(%PlayerState{character_id: id} = caster, :self, level, _definition) do
    case longing_condition(id) do
      :ok ->
        StatusInterpreter.apply_status(:player, id, :sc_longing,
          caster_id: id,
          val1: level,
          duration: 180_000,
          owner_refresh: :defer
        )

        {:ok, caster}

      {:error, reason} ->
        {:skipped, caster, reason}
    end
  end

  defp longing_condition(id) do
    with %StatusEntry{val1: skill, val4: partner, state: state} when skill != 395 <-
           StatusStorage.get_status(:player, id, :sc_dancing),
         root =
           Map.get(state, :root) ||
             if(is_integer(partner) and partner > 0, do: :ensemble, else: :none),
         true <- root != :none do
      if StatusStorage.has_status?(:player, id, :sc_longing),
        do: {:error, :already_active},
        else: :ok
    else
      _ -> {:error, :not_in_ensemble}
    end
  end
end
