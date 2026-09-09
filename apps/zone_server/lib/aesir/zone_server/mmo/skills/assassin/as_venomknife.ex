defmodule Aesir.ZoneServer.Mmo.Skills.Assassin.AsVenomknife do
  @moduledoc """
  Throw Venom Knife (AS_VENOMKNIFE). The Assassin platinum skill: throws one
  equipped Venom Knife at 9 cells as a forced ranged hit that always poisons.

  Renewal: 500% weapon damage, 35 SP, poison 18 s. Pre-renewal: 100% weapon
  damage, 15 SP, poison 60 s.
  """

  use Aesir.ZoneServer.Mmo.Skill,
    id: 1004,
    name: :as_venomknife,
    display_name: "Throw Venom Knife",
    max_level: 1,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 9,
    sp_cost: [renewal: [35], pre_renewal: [15]],
    duration: [renewal: [18_000], pre_renewal: [60_000]],
    requires_ammo: true,
    quest_skill: true,
    quest_owner_job: :assassin

  alias Aesir.Commons.GameMode
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
        skill_ratio: skill_ratio(),
        bonus_atk: ammo.attack,
        skip_crit: true,
        report_hit: true,
        skip_range: true
      ]

      case SkillAttack.execute_forced_no_card_attack(caster, target, opts) do
        {:ok, %{hit?: true}} ->
          apply_poison(caster, target, definition)
          {:ok, caster}

        {:ok, %{hit?: false}} ->
          {:ok, caster}

        {:error, _reason} = error ->
          error
      end
    end
  end

  @doc "Renewal throws at 500% weapon damage; pre-renewal at 100%."
  @spec skill_ratio() :: pos_integer()
  def skill_ratio, do: if(GameMode.mode() == :renewal, do: 500, else: 100)

  defp apply_poison(caster, target, definition) do
    {target_type, target_id} = target_ref(target)

    _ =
      StatusInterpreter.apply_status(target_type, target_id, :sc_poison,
        duration: hd(definition.duration),
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
