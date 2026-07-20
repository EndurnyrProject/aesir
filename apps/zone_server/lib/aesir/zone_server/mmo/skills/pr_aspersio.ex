defmodule Aesir.ZoneServer.Mmo.Skills.PrAspersio do
  @moduledoc """
  Aspersio (PR_ASPERSIO). Endows a player with Holy weapon element or deals
  fixed Holy magic damage to an undead enemy.

  rAthena Renewal: `db/re/skill_db.yml:2380-2425`, `skill.cpp:4419-4428`,
  `skills/acolyte/aspersio.cpp:26-28`, and `battle.cpp:5897-5899`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 68,
    name: :pr_aspersio,
    status: :sc_aspersio,
    display_name: "Aspersio",
    max_level: 5,
    target_type: :target_ally,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :holy,
    range: 9,
    after_cast_delay: List.duplicate(2_000, 5),
    sp_cost: [14, 18, 22, 26, 30],
    item_cost: [%{id: 523, amount: 1}],
    duration: [60_000, 90_000, 120_000, 150_000, 180_000]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(_caster, :self, _level, _definition), do: :ok

  def validate(_caster, {:unit, target_id}, _level, _definition) do
    case target_kind(target_id) do
      kind when kind in [:player, :undead_enemy] -> :ok
      :invalid -> {:error, :invalid_target}
      {:error, _reason} = error -> error
    end
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    apply_endow(caster, caster_id, caster_id, level, definition)
  end

  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    case target_kind(target_id) do
      :player -> apply_endow(caster, caster_id, target_id, level, definition)
      :undead_enemy -> damage_undead(caster, target_id, level, definition)
      :invalid -> {:error, :invalid_target}
      {:error, _reason} = error -> error
    end
  end

  defp damage_undead(caster, target_id, level, definition) do
    case Combat.execute_magic_damage(caster, target_id, 40,
           skill_id: definition.id,
           skill_level: level,
           element: definition.element,
           skip_range: true
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp apply_endow(caster, caster_id, target_id, level, definition) do
    case StatusInterpreter.apply_status(:player, target_id, :sc_aspersio,
           val1: level,
           caster_id: caster_id,
           duration: Enum.at(definition.duration, level - 1)
         ) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp undead?(%{race: race} = target),
    do: RaceModifiers.undead?(race) or undead_element?(Map.get(target, :element))

  defp undead_element?({:undead, _level}), do: true
  defp undead_element?(:undead), do: true
  defp undead_element?(_element), do: false

  defp target_kind(target_id) do
    case Combat.resolve_combatant(target_id) do
      {:ok, %{unit_type: :player}} -> :player
      {:ok, %{unit_type: :mob} = target} -> if undead?(target), do: :undead_enemy, else: :invalid
      {:ok, _target} -> :invalid
      {:error, _reason} = error -> error
    end
  end
end
