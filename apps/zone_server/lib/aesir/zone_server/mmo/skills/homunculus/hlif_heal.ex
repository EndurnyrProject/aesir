defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HlifHeal do
  @moduledoc """
  Healing Touch (HLIF_HEAL). Consumes one Red Slim Potion and restores the
  owning player's HP by `Combat.SkillHeal`'s recipe from Lif's level, INT and
  Brain Surgery rank (and its MATK in renewal) and the owner's received-heal
  bonuses. The Homunculus is never healed by this skill.

  Both modes: a missing owner refuses the cast; a dead owner does not, the
  cast spends its SP and potion and heals nothing.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8_001,
    name: :hlif_heal,
    display_name: "Healing Touch",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    sp_cost: [13, 16, 19, 22, 25],
    cooldown: List.duplicate(20_000, 5),
    item_cost: [%{id: 545, amount: 1}]

  alias Aesir.ZoneServer.Mmo.Combat.SkillHeal
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState

  @behaviour Active

  @impl Active
  def validate(%HomunculusState{} = caster, :self, _level, _definition) do
    with {:ok, _owner} <- resolve_owner(caster), do: :ok
  end

  @impl Active
  def cast(
        %HomunculusState{} = caster,
        :self,
        level,
        %{item_cost: [%{id: item_id, amount: amount}]}
      ) do
    cost = {:owner_item_cost, item_id, amount}

    if owner_dead?(caster),
      do: {:local_effects, caster, [cost]},
      else: {:local_effects, caster, [cost, heal(caster, level)]}
  end

  defp owner_dead?(caster) do
    case resolve_owner(caster) do
      {:ok, owner} -> not Unit.living?(owner)
      {:error, _reason} -> false
    end
  end

  defp heal(caster, level) do
    owner = {:player, caster.owner_character_id}
    restored = SkillHeal.amount(SkillHeal.caster(caster), owner, definition().id, level, true)
    {:player, {:apply_heal, restored, {:homunculus, caster.world_gid}}}
  end

  defp resolve_owner(%HomunculusState{owner_character_id: owner_character_id}) do
    case TargetResolver.resolve({:player, owner_character_id}) do
      {:ok, _pid, owner, :player} -> {:ok, owner}
      {:error, _reason} -> {:error, :owner_not_found}
    end
  end
end
