defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaGospel.Effects do
  @moduledoc """
  The random effect tables of Battle Chant and how each entry is applied.

  Party members draw one of thirteen blessings; enemies draw one of ten
  afflictions. Every status carries the chanting Paladin as its caster. Damage
  rolls go through the field misc path with a neutral element: the "reduced by
  DEF" roll is pre-reduced here because the misc path ignores DEF by contract
  (renewal subtracts hard and soft DEF flat, pre-renewal takes hard DEF as a
  percentage and then subtracts soft DEF).

  A DEF-reduced roll floored to zero deals nothing (the misc path would otherwise
  clamp it to one point).

  Accepted deviation: the reference applies Provoke with an infinite duration;
  Aesir has no per-instance infinite form, so it lasts 30 minutes like the
  other long afflictions.
  """

  require Logger

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.DamageApplication
  alias Aesir.ZoneServer.Mmo.Combat.SkillAttack
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.StatusEffect.Dispel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @typedoc "One table entry: a status, a status pair, a heal, a cleanse, or a damage roll."
  @type effect ::
          {:status, atom(), integer(), pos_integer()}
          | {:status_pair, {atom(), integer()}, {atom(), integer()}, pos_integer()}
          | {:heal, Range.t()}
          | :cleanse
          | {:damage, :def_reduced | :flat, Range.t()}

  @skill_id 369
  @duration 60_000
  @long_affliction 1_800_000

  @bless [
    {:heal, 1_000..9_999},
    :cleanse,
    {:status, :sc_scresist, 100, @duration},
    {:status, :sc_incmhprate, 100, @duration},
    {:status, :sc_incmsprate, 100, @duration},
    {:status, :sc_incallstatus, 20, @duration},
    {:status, :sc_blessing, 10, 240_000},
    {:status, :sc_increaseagi, 10, 240_000},
    {:status, :sc_aspersio, 1, @duration},
    {:status, :sc_benedictio, 1, @duration},
    {:status, :sc_incdefrate, 25, 10_000},
    {:status, :sc_incatkrate, 100, @duration},
    {:status_pair, {:sc_inchit, 50}, {:sc_incflee, 50}, @duration}
  ]

  @afflict [
    {:damage, :def_reduced, 3_000..7_999},
    {:damage, :flat, 1_500..5_499},
    {:status, :sc_curse, 1, @long_affliction},
    {:status, :sc_blind, 1, @long_affliction},
    {:status, :sc_poison, 1, @long_affliction},
    {:status, :sc_provoke, 10, @long_affliction},
    {:status, :sc_incdefrate, -100, 20_000},
    {:status, :sc_incatkrate, -100, 20_000},
    {:status, :sc_incfleerate, -100, 20_000},
    {:status, :sc_gospel_slow, 1, 20_000}
  ]

  @doc "The thirteen blessings a party member may receive."
  @spec bless_table() :: [effect()]
  def bless_table, do: @bless

  @doc "The ten afflictions an enemy may receive."
  @spec afflict_table() :: [effect()]
  def afflict_table, do: @afflict

  @doc "Applies one random blessing to a party member."
  @spec bless(Group.t(), {:player, integer()}) :: :ok
  def bless(%Group{} = group, target), do: apply(Enum.random(@bless), group, nil, target)

  @doc "Applies one random affliction to an enemy standing in the field."
  @spec afflict(Group.t(), struct(), {atom(), integer()}) :: :ok
  def afflict(%Group{} = group, caster_state, target),
    do: apply(Enum.random(@afflict), group, caster_state, target)

  @doc "Applies one table entry to `target`."
  @spec apply(effect(), Group.t(), struct() | nil, {atom(), integer()}) :: :ok
  def apply({:status, status_id, value, duration}, group, _caster, {type, id}) do
    apply_status(group, type, id, status_id, value, duration)
  end

  def apply({:status_pair, {first, v1}, {second, v2}, duration}, group, _caster, {type, id}) do
    apply_status(group, type, id, first, v1, duration)
    apply_status(group, type, id, second, v2, duration)
  end

  def apply({:heal, range}, %Group{caster_id: caster_id}, _caster, {type, id}) do
    DamageApplication.apply_heal(type, id, Enum.random(range), caster_id)
  end

  def apply(:cleanse, _group, _caster, target), do: Dispel.dispel_debuffs(target)

  def apply({:damage, kind, range}, %Group{level: level} = group, caster, target) do
    case roll_damage(kind, Enum.random(range), target) do
      {:ok, 0} -> :ok
      {:ok, damage} -> strike(caster, target, group, level, damage)
      {:error, _gone} -> :ok
    end
  end

  defp strike(caster, target, group, level, damage) do
    opts = [skill_id: @skill_id, skill_level: level, base_damage: damage, element: :neutral]

    case SkillAttack.execute_field_misc_attack(caster, target, group, opts) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning("Gospel affliction on #{inspect(target)} refused: #{inspect(reason)}")
        :ok
    end
  end

  defp roll_damage(:flat, roll, _target), do: {:ok, roll}

  defp roll_damage(:def_reduced, roll, {type, id}) do
    with {:ok, combatant} <- Combat.resolve_combatant(type, id),
         do: {:ok, def_reduced(roll, combatant)}
  end

  @doc "Reduces a damage roll by the defender's DEF the way the mode's misc formula does."
  @spec def_reduced(non_neg_integer(), map()) :: non_neg_integer()
  def def_reduced(roll, %{combat_stats: combat_stats}) do
    hard = Map.get(combat_stats, :def, 0)
    soft = Map.get(combat_stats, :soft_def, 0)

    case GameMode.mode() do
      :renewal -> max(roll - hard - soft, 0)
      :pre_renewal -> max(roll - div(roll * hard, 100) - soft, 0)
    end
  end

  defp apply_status(
         %Group{caster_id: caster_id, caster_type: caster_type},
         type,
         id,
         status,
         v,
         d
       ) do
    _ =
      StatusInterpreter.apply_status(type, id, status,
        val1: v,
        duration: d,
        caster_id: caster_id,
        source_type: caster_type
      )

    :ok
  end
end
