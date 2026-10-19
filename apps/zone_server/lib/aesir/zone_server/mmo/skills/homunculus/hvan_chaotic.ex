defmodule Aesir.ZoneServer.Mmo.Skills.Homunculus.HvanChaotic do
  @moduledoc """
  Benediction of Chaos heals Vanilmirth, its owner, or one current owner-attacker,
  by `Combat.SkillHeal`'s recipe at a random level from 1 to the skill level.

  In both modes the attacker is rolled among the first 30 characters within
  14 cells of the owner that have it as a standing attack or skill target,
  taken in map block order. Renewal has a three-second cooldown; pre-renewal
  has none.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 8_014,
    name: :hvan_chaotic,
    display_name: "Benediction of Chaos",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    sp_cost: List.duplicate(40, 5),
    cooldown: [renewal: List.duplicate(3_000, 5), pre_renewal: []]

  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.SkillHeal
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.Attackers
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @homunculus_thresholds [20, 50, 25, 50, 34]
  @owner_thresholds [50, 60, 75, 54, 67]

  @impl Active
  def cast(%HomunculusState{} = caster, :self, level, _definition) do
    recipient = recipient(caster, level, :rand.uniform(100))
    amount = heal_amount(caster, recipient, :rand.uniform(level))
    {:local_effects, caster, [heal_effect(caster, recipient, amount)]}
  end

  defp recipient(caster, level, roll) do
    homunculus_threshold = Enum.fetch!(@homunculus_thresholds, level - 1)
    owner_threshold = Enum.fetch!(@owner_thresholds, level - 1)

    cond do
      roll <= homunculus_threshold -> :homunculus
      roll <= owner_threshold -> :owner
      true -> random_attacker(caster)
    end
  end

  defp random_attacker(caster) do
    with {:ok, {_module, owner, _pid}} <-
           UnitRegistry.get_unit(:player, caster.owner_character_id),
         {:ok, target_ref} <- Attackers.random(owner) do
      target_ref
    else
      _none -> :homunculus
    end
  end

  defp heal_amount(caster, recipient, rank) do
    target = recipient_ref(caster, recipient)
    SkillHeal.amount(SkillHeal.caster(caster), target, definition().id, rank, true)
  end

  defp recipient_ref(caster, :homunculus), do: {:homunculus, caster.world_gid}
  defp recipient_ref(caster, :owner), do: {:player, caster.owner_character_id}
  defp recipient_ref(_caster, {_type, _id} = target_ref), do: target_ref

  defp heal_effect(caster, :homunculus, amount) do
    source = {:homunculus, caster.world_gid}
    DamageApplication.local_heal_effect(source, amount, source)
  end

  defp heal_effect(caster, :owner, amount) do
    {:player, {:apply_heal, amount, {:homunculus, caster.world_gid}}}
  end

  defp heal_effect(caster, {:mob, id}, amount) do
    {:mob, {:apply_heal, id, amount, {:homunculus, caster.world_gid}}}
  end

  defp heal_effect(%{world_gid: gid} = caster, {:homunculus, gid}, amount),
    do: heal_effect(caster, :homunculus, amount)

  defp heal_effect(caster, target_ref, amount) do
    {:external_heal, target_ref, amount, {:homunculus, caster.world_gid}}
  end
end
