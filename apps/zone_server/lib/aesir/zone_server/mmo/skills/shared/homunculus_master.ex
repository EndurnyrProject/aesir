defmodule Aesir.ZoneServer.Mmo.Skills.Shared.HomunculusMaster do
  @moduledoc """
  The checks a homunculus skill aimed at its owner (Healing Touch, Urgent
  Escape, Defence, Castling) makes on the owner when its use starts, both modes: the owner must be
  registered, on the homunculus's map, not concealed from it (Hiding, Cloaking
  and Chase Walk hide the owner from a homunculus, which detects nothing), and
  within reach, with no wall between them beyond the adjacent cells. Every
  refusal is silent; the owner's death is the effect's concern.

  The four skills that retarget their master declare no range, and the
  reference hands a non-player caster whose skill declares none a reach of nine
  cells, checked over the straight line to the owner. Beyond the adjacent cells
  a wall between the two refuses the use.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Map.LineOfSight
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # The reference's reach for a non-player caster whose skill declares no range.
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
