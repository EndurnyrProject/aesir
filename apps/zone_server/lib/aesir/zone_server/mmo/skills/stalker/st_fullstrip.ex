defmodule Aesir.ZoneServer.Mmo.Skills.Stalker.StFullstrip do
  @moduledoc """
  Divest All (ST_FULLSTRIP). In renewal and pre-renewal, one per-mille roll of
  `50 + 20 * level` plus twice the DEX difference, never below `50 + 20 *
  level`, strips the target's weapon (both hands' weapons), shield, armor and
  helm for the Divest duration (75 to 135 s by level plus the DEX bonus, 15 s
  longer on a monster or homunculus). Chemical Protection keeps its piece, and
  a player target only loses what it wears. The effect shows only when
  something was stripped, and a player caster is told when nothing was.

  A player caster whose target holds all four Chemical Protections is told
  the target is fully coated and nothing happens, the SP still spent; a
  monster caster tries the strip anyway. Melee range, no cast, 1 s delay.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 476,
    name: :st_fullstrip,
    requires: [],
    display_name: "Divest All",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :no_damage,
    range: 1,
    sp_cost: [22, 24, 26, 28, 30],
    after_cast_delay: List.duplicate(1_000, 5)

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skills.Rogue.StripCommon
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @slots [:right_hand, :left_hand, :armor, :head_top]

  @impl Active
  def cast(%PlayerState{} = caster, {:unit, target_ref} = target, level, definition) do
    if coated?(target_ref),
      do: {:failed, caster, :fullstrip_coated},
      else: StripCommon.cast(caster, target, level, definition, @slots, :full)
  end

  def cast(caster, target, level, definition),
    do: StripCommon.cast(caster, target, level, definition, @slots, :full)

  defp coated?(target_ref) do
    case TargetResolver.resolve(target_ref) do
      {:ok, _pid, target, type} when type in [:player, :mob, :homunculus] ->
        id = target.__struct__.get_unit_id(target)

        Enum.all?(StripCommon.pieces(), fn {_slot, _status, protection} ->
          StatusStorage.has_status?(type, id, protection)
        end)

      _other ->
        false
    end
  end
end
