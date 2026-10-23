defmodule Aesir.ZoneServer.Mmo.Skills.Shared.HomunculusMaster do
  @moduledoc """
  The checks a homunculus skill aimed at its owner (Healing Touch, Castling)
  makes on the owner when its use starts, both modes: the owner must be
  registered, on the homunculus's map, not concealed from it (Hiding, Cloaking
  and Chase Walk hide the owner from a homunculus, which detects nothing), and
  within reach, with no wall between them beyond the adjacent cells. Every
  refusal is silent; the owner's death is the effect's concern.

  The reference declares no `Range` for the four skills that retarget their
  master, so its retargeted range check resolves to the skill's own zero; that
  would make these skills same-cell only, which the reference's own client and
  the Castling swap contradict. Aesir keeps the homunculus's sight reach until
  the reference behaviour is verified live; the reach is a known open question
  rather than a ported rule.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # The reference's own reach for these skills is unresolved (see the module
  # documentation); this is the homunculus's skill reach used until it is
  # verified against a live reference.
  @reach_cells 9

  @doc "Checks the owner `caster`'s skill is aimed at and returns the owner."
  @spec check(HomunculusState.t(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()}
          | {:error,
             :owner_not_found
             | :different_map
             | :target_concealed
             | :target_restricted
             | :caster_restricted
             | :out_of_range}
  def check(%HomunculusState{} = caster, _level, %Definition{} = definition) do
    with {:ok, owner} <- resolve_owner(caster),
         :ok <- check_map(caster, owner),
         :ok <- check_concealment(caster, owner, definition),
         :ok <- check_reach(caster, owner) do
      {:ok, owner}
    end
  end

  defp resolve_owner(%HomunculusState{owner_character_id: owner_id}) do
    case TargetResolver.resolve({:player, owner_id}) do
      {:ok, _pid, %PlayerState{} = owner, :player} -> {:ok, owner}
      _missing -> {:error, :owner_not_found}
    end
  end

  defp check_map(%HomunculusState{map_name: map_name}, %PlayerState{map_name: map_name}),
    do: :ok

  defp check_map(_caster, _owner), do: {:error, :different_map}

  defp check_concealment(caster, owner, definition) do
    Targeting.validate_skill_use(
      %{unit_type: :homunculus, unit_id: caster.world_gid},
      %{unit_type: :player, unit_id: owner.character_id},
      definition,
      :cast_begin
    )
  end

  defp check_reach(caster, owner) do
    distance = Geometry.chebyshev_distance(caster.x, caster.y, owner.x, owner.y)

    cond do
      distance > @reach_cells -> {:error, :out_of_range}
      distance < 2 -> :ok
      LineOfSight.clear?(caster.map_name, {caster.x, caster.y}, {owner.x, owner.y}) -> :ok
      true -> {:error, :out_of_range}
    end
  end
end
