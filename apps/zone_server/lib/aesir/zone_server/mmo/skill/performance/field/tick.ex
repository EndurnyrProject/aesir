defmodule Aesir.ZoneServer.Mmo.Skill.Performance.Field.Tick do
  @moduledoc """
  The per-unit effects of a performance cell on the skill-unit pass:
  Dissonance damage, Ugly Dance SP drain, Apple of Idun healing and Lullaby
  sleep, and who each may reach. Ugly Dance and Lullaby run the performer's
  bAddEff entries on each target first (`OnHitEffects.direct/5`).

  Dissonance, Ugly Dance and Lullaby reach the caster's living enemies, Apple of
  Idun every living unit. None reaches a performer. Which unit types a cell can
  reach comes from the field's own skill, even on a dissonant cell (rAthena's
  dance switch keeps the unit's `bl_flag`): a NoMob song never reaches a
  monster. Dissonance, Ugly Dance and Apple of Idun read the performer's
  current lesson (and Idun its current VIT).
  """

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.OnHitEffects
  alias Aesir.ZoneServer.Mmo.Combat.SkillHeal
  alias Aesir.ZoneServer.Mmo.Skill.Performance.Caster
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Resource
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @typedoc "A performance cell's effect."
  @type effect :: :dissonance | :ugly_dance | :idun_heal | :lullaby

  # Songs whose Unit row carries NoMob.
  @no_mob [
    :ba_whistle,
    :ba_assassincross,
    :ba_poembragi,
    :ba_appleidun,
    :dc_humming,
    :dc_fortunekiss,
    :dc_serviceforyou
  ]

  # Lullaby and Ugly Dance reach their targets as a long-range misc skill.
  @song_flag BattleFlags.build(:misc, :long, true)

  @music_lessons 315
  @apple_of_idun 322
  @dancing_lessons 323

  @doc "Whether `effect` may reach `target` from this field."
  @spec target?(Group.t(), effect(), {atom(), integer()}) :: boolean()
  def target?(%Group{} = group, effect, {type, id} = target) do
    performer? =
      target == {group.caster_type, group.caster_id} or
        (type == :player and id in group.state.performance.performers)

    with false <- performer?,
         true <- type in types(group),
         {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(type, id),
         true <- Unit.living?(state) do
      effect == :idun_heal or enemy?(group, state)
    else
      _ -> false
    end
  end

  @doc "Applies `effect` to one unit, while the field's caster is present."
  @spec apply(effect(), Group.t(), {atom(), integer()}) :: :ok
  def apply(effect, %Group{} = group, target) do
    case UnitRegistry.get_unit(group.caster_type, group.caster_id) do
      {:ok, {_module, caster_state, _pid}} -> apply_effect(effect, group, caster_state, [target])
      _gone -> :ok
    end
  end

  defp types(%Group{skill_name: name}) when name in @no_mob, do: [:player, :homunculus]
  defp types(%Group{}), do: [:player, :mob, :homunculus]

  defp enemy?(group, state) do
    case Combat.resolve_combatant(group.caster_type, group.caster_id) do
      {:ok, caster} -> Targeting.validate_enemy(caster, state) == :ok
      _gone -> false
    end
  end

  @doc "Strikes each eligible target with neutral Dissonance misc damage."
  @spec dissonance(Group.t(), struct(), [{atom(), integer()}]) :: :ok
  def dissonance(group, caster, targets) do
    level = group.level
    lesson = Caster.lesson_level(caster, @music_lessons)

    Enum.each(targets, fn target ->
      Combat.execute_misc_attack(caster, target,
        skill_id: 317,
        skill_level: level,
        base_damage: 30 + 10 * level + level * lesson,
        element: :neutral,
        delivery: :unit
      )
    end)
  end

  @doc "Drains SP from each eligible Ugly Dance target."
  @spec ugly_dance(Group.t(), struct(), [{atom(), integer()}]) :: :ok
  def ugly_dance(group, caster, targets) do
    amount = 5 + 5 * group.level + group.level * Caster.lesson_level(caster, @dancing_lessons)

    Enum.each(targets, fn {type, id} = target ->
      OnHitEffects.direct(caster, target, @song_flag, group.skill_id)
      Resource.drain_sp(type, id, amount)
    end)
  end

  @doc """
  Heals each Idun occupant by `Combat.SkillHeal`'s recipe from the performer as
  it is now (VIT, Music Lessons, Apple of Idun's own skill-heal bonus) and each
  occupant's received-heal bonuses.
  """
  @spec idun_heal(Group.t(), struct(), [{atom(), integer()}]) :: :ok
  def idun_heal(group, caster, targets) do
    healer = SkillHeal.caster(caster)

    Enum.each(targets, fn {type, id} = target ->
      amount = SkillHeal.amount(healer, target, @apple_of_idun, group.level, true)
      DamageApplication.apply_heal(type, id, amount, group.caster_id)
    end)
  end

  @doc "Attempts a thirty-second sleep using both performers' INT every six seconds."
  @spec lullaby(Group.t(), struct(), [{atom(), integer()}]) :: :ok
  def lullaby(group, caster, targets) do
    intelligence =
      Enum.reduce(group.state.performance.performers, 0, fn id, total ->
        case UnitRegistry.get_unit(:player, id) do
          {:ok, {_module, performer, _pid}} -> total + Caster.stat(performer, :int)
          _ -> total
        end
      end)

    Enum.each(targets, fn {type, id} = target ->
      OnHitEffects.direct(caster, target, @song_flag, group.skill_id)

      StatusInterpreter.apply_status(type, id, :sc_sleep,
        val1: group.level,
        caster_id: caster.character_id,
        success_rate: (intelligence + 99 + :rand.uniform(201)) / 10,
        duration: 30_000,
        owner_refresh: :notify
      )
    end)
  end

  defp apply_effect(:dissonance, group, caster, targets), do: dissonance(group, caster, targets)
  defp apply_effect(:ugly_dance, group, caster, targets), do: ugly_dance(group, caster, targets)
  defp apply_effect(:idun_heal, group, caster, targets), do: idun_heal(group, caster, targets)
  defp apply_effect(:lullaby, group, caster, targets), do: lullaby(group, caster, targets)
end
