defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomknife do
  @moduledoc "Throw Venom Knife (AS_VENOMKNIFE), the Assassin platinum active skill."

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1004,
    name: :as_venomknife,
    display_name: "Throw Venom Knife",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 9,
    sp_cost: [35],
    requires_ammo: true,
    quest_skill: true,
    quest_owner_job: :assassin

  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Inventory.Ammo
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  def validate(%PlayerState{inventory: inventory}, _target, _level, _definition) do
    case Ammo.equipped_ammo(inventory) do
      {:ok, %{nameid: 1771}, %{id: 1771}} -> :ok
      {:error, :no_ammo} -> {:error, :no_ammo}
      _other -> {:error, :wrong_ammo}
    end
  end

  @impl Active
  def cast(%PlayerState{} = caster, {:unit, target}, level, definition) do
    with {:ok, _row, ammo} <- Ammo.equipped_ammo(caster.inventory) do
      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: 500,
        bonus_atk: ammo.attack,
        skip_crit: true,
        report_hit: true,
        skip_range: true
      ]

      case SkillAttack.execute_forced_no_card_attack(caster, target, opts) do
        {:ok, %{hit?: true}} ->
          apply_poison(caster, target)
          {:ok, caster}

        {:ok, %{hit?: false}} ->
          {:ok, caster}

        {:error, _reason} = error ->
          error
      end
    end
  end

  defp apply_poison(caster, target) do
    {target_type, target_id} = target_ref(target)

    _ =
      StatusInterpreter.apply_status(target_type, target_id, :sc_poison,
        duration: 18_000,
        success_rate: 100,
        caster_id: caster.character_id,
        source_type: :player
      )

    :ok
  end

  defp target_ref({unit_type, unit_id}), do: {unit_type, unit_id}

  defp target_ref(target_id) do
    if UnitRegistry.unit_exists?(:mob, target_id),
      do: {:mob, target_id},
      else: {:player, target_id}
  end
end
