defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkHeadcrush do
  @moduledoc """
  Head Crush (LK_HEADCRUSH) delivers 100% plus 40% per level weapon damage.
  On a landed hit it may cause Bleeding, except against bosses, undead, and
  demons. Renewal Bleeding lasts 108 seconds; pre-renewal lasts 120 seconds.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 398,
    name: :lk_headcrush,
    display_name: "Head Crush",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    range: 4,
    sp_cost: List.duplicate(23, 5),
    after_cast_delay: List.duplicate(500, 5)

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  @spec validate(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(_caster, {:unit, target_id}, _level, _definition) do
    with {:ok, _pid, target, _type} <- TargetResolver.resolve(target_id) do
      if target.__struct__.is_boss?(target), do: {:error, :boss_immune}, else: :ok
    end
  end

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    case Combat.execute_skill_attack(caster, target_id,
           skill_id: definition.id,
           skill_level: level,
           skill_ratio: 100 + 40 * level,
           skip_crit: true,
           skip_range: true,
           report_hit: true
         ) do
      {:ok, %{hit?: true}} ->
        maybe_bleed(caster, target_id, level)
        {:ok, caster}

      {:ok, %{hit?: false}} ->
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp maybe_bleed(caster, target_id, level) do
    with {:ok, target} <- Combat.resolve_combatant(target_id),
         true <- target.race not in [:undead, :demon],
         false <- undead_element?(target.element),
         true <- :rand.uniform(100) <= 50 do
      type = caster.__struct__.get_unit_type(caster)
      id = caster.__struct__.get_unit_id(caster)
      duration = if(GameMode.mode() == :renewal, do: 108_000, else: 120_000)

      _ =
        StatusInterpreter.apply_status(target.unit_type, target.unit_id, :sc_bleeding,
          val1: level,
          duration: duration,
          caster_id: id,
          source_type: type
        )
    end

    :ok
  end

  defp undead_element?({:undead, _level}), do: true
  defp undead_element?(:undead), do: true
  defp undead_element?(_element), do: false
end
