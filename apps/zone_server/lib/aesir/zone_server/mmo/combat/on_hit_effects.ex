defmodule Aesir.ZoneServer.Mmo.Combat.OnHitEffects do
  @moduledoc """
  On-hit status infliction from equipment (`bAddEff` / `bAddEffWhenHit`).

  Invoked from the physical attack paths (`AutoAttack`, physical `SkillAttack`)
  after a hit lands with positive damage. For each attacker `{:add_eff, sc}` the
  effective chance is `rate - defender {:res_eff, sc}` (per-10000, floored at 0);
  a successful roll delegates to `StatusEffect.Interpreter.apply_status/4` for the
  defender, naming the attacker as the source so the interpreter's boss-immunity
  and resistance chain still gates the attempt. Defender `{:add_eff_when_hit, sc}`
  rolls symmetrically against the attacker, with the defender as the source.

  The per-10000 roll only decides whether infliction is *attempted*; durations and
  resistance stay the status system's job. Because the `{:res_eff, sc}` tolerance
  is already subtracted here at the proc rate, `apply_status` is called with
  `res_eff_exempt: true` so the interpreter's own tolerance step does not apply it
  a second time. The roll is injectable through the `:roll` option (mirroring
  `roll_resistance`'s `resistance_roll`) so tests are deterministic.
  """

  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.ModifierCalculator
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @roll_ceiling 10_000
  @normal_short BattleFlags.build(:weapon, :short, false)
  @normal_long BattleFlags.build(:weapon, :long, false)
  @defender_procs [
    %{
      status: :sc_defset,
      rate: :def_set_race_rate,
      duration: :def_set_race_duration,
      value: :def_set_race_value
    },
    %{
      status: :sc_mdefset,
      rate: :mdef_set_race_rate,
      duration: :mdef_set_race_duration,
      value: :mdef_set_race_value
    },
    %{
      status: :sc_norecover_state,
      rate: :no_recover_race_rate,
      duration: :no_recover_race_duration
    }
  ]

  @typedoc "A per-10000 chance/tolerance predicate: given an effective rate, is the roll a hit."
  @type roll_fun :: (non_neg_integer() -> boolean())

  @doc """
  Rolls both on-hit infliction families for one landed physical hit.

  A miss or zero-damage hit never reaches here from the attack paths; the
  zero-damage clause guards direct callers. Skill-unit targets carry no living
  state to inflict on and are skipped.

  A bonus written with a trigger flag (`bonus3 bAddEff,Eff_Stun,500,ATF_MAGIC`)
  only rolls when the flag matches `:attack_flag`, and its victim axis decides
  who the status lands on: the attack's other party, the bonus's own wearer, or
  both. Unflagged bonuses always roll against the other party.

  ## Options
    - `:roll` - a `t:roll_fun/0` used for every per-10000 roll (default `:rand`).
    - `:attack_flag` - the hit's `BattleFlags` classification, matched against
      flagged bonuses. The default `0` carries no classification, so flagged
      bonuses stay inert.
    - `:skill_id` - the skill that landed this hit, matched against the
      infliction bonuses armed for one named skill. A normal attack passes none.
  """
  @spec after_hit(Combatant.t(), Combatant.t(), map(), keyword()) :: :ok
  def after_hit(attacker, defender, damage_result, opts \\ [])

  def after_hit(_attacker, _defender, %{damage: damage}, _opts) when damage <= 0, do: :ok

  def after_hit(_attacker, %Combatant{unit_type: :skill_unit}, _damage_result, _opts), do: :ok

  def after_hit(%Combatant{} = attacker, %Combatant{} = defender, _damage_result, opts) do
    roll = Keyword.get(opts, :roll, &default_roll/1)
    attack_flag = Keyword.get(opts, :attack_flag, 0)

    inflict(attacker, defender, :add_eff, roll, attack_flag)
    inflict(defender, attacker, :add_eff_when_hit, roll, attack_flag)
    inflict(attacker, attacker, :add_eff2, roll, attack_flag)
    inflict_on_skill(attacker, defender, Keyword.get(opts, :skill_id), roll)
    inflict_defender_procs(attacker, defender, roll, attack_flag)
    :ok
  end

  # Rolls every bonus of `family` carried by `source`. An unflagged entry
  # (`{family, sc}`) targets `other`; a flagged one (`{family, {sc, flag}}`)
  # rolls only on a matching attack and can name `other`, `source`, or both as
  # its victim.
  @spec inflict(Combatant.t(), Combatant.t(), atom(), roll_fun(), BattleFlags.flag()) :: :ok
  defp inflict(source, other, family, roll, attack_flag) do
    Enum.each(source.equip_modifiers, fn
      {{^family, {sc, flag}}, rate} when is_atom(sc) and is_integer(flag) ->
        duration = status_duration(source, family, {sc, flag})
        inflict_flagged(source, other, sc, rate, duration, roll, flag, attack_flag)

      {{^family, sc}, rate} when is_atom(sc) ->
        try_inflict(source, other, sc, rate, roll, status_duration(source, family, sc))

      _entry ->
        :ok
    end)
  end

  # `bAddEffOnSkill` arms a status on one named skill landing, whatever kind of
  # attack that skill is; a hit from any other skill, or a normal attack, rolls
  # nothing.
  @spec inflict_on_skill(Combatant.t(), Combatant.t(), integer() | nil, roll_fun()) :: :ok
  defp inflict_on_skill(_attacker, _defender, nil, _roll), do: :ok

  defp inflict_on_skill(attacker, defender, skill_id, roll) do
    Enum.each(attacker.equip_modifiers, fn
      {{:add_eff_on_skill, ^skill_id, sc}, rate} when is_atom(sc) ->
        try_inflict(attacker, defender, sc, rate, roll)

      _entry ->
        :ok
    end)
  end

  # A flagged bonus rolls only on a matching attack, once per victim its flag
  # names.
  @spec inflict_flagged(
          Combatant.t(),
          Combatant.t(),
          atom(),
          integer(),
          non_neg_integer(),
          roll_fun(),
          BattleFlags.flag(),
          BattleFlags.flag()
        ) :: :ok
  defp inflict_flagged(source, other, sc, rate, duration, roll, flag, attack_flag) do
    if BattleFlags.matches_trigger?(flag, attack_flag) do
      victims =
        [
          BattleFlags.target_victim?(flag) && other,
          BattleFlags.self_victim?(flag) && source
        ]
        |> Enum.filter(& &1)

      Enum.each(victims, &try_inflict(source, &1, sc, rate, roll, duration))
    end

    :ok
  end

  # Applies `sc` to `victim` when the roll lands, with `source` named as the
  # caster so boss immunity gates. The victim's tolerance for the status is
  # subtracted from the proc rate here, so the status system does not apply it
  # a second time.
  @spec try_inflict(Combatant.t(), Combatant.t(), atom(), integer(), roll_fun()) :: :ok
  defp try_inflict(source, victim, sc, rate, roll),
    do: try_inflict(source, victim, sc, rate, roll, 0)

  @spec try_inflict(
          Combatant.t(),
          Combatant.t(),
          atom(),
          integer(),
          roll_fun(),
          non_neg_integer()
        ) :: :ok
  defp try_inflict(source, victim, sc, rate, roll, duration) do
    effective = rate - Map.get(victim.equip_modifiers, {:res_eff, sc}, 0)

    if effective > 0 and roll.(effective) do
      params =
        [
          caster_id: source.unit_id,
          source_type: source.unit_type,
          res_eff_exempt: true
        ]
        |> maybe_duration(duration)

      StatusInterpreter.apply_status(victim.unit_type, victim.unit_id, sc, params)
    end

    :ok
  end

  defp status_duration(source, family, param) do
    case duration_family(family) do
      nil -> 0
      duration_family -> Map.get(source.equip_modifiers, {duration_family, param}, 0)
    end
  end

  defp duration_family(:add_eff), do: :add_eff_duration
  defp duration_family(:add_eff_when_hit), do: :add_eff_when_hit_duration
  defp duration_family(_family), do: nil

  defp maybe_duration(params, duration) when is_integer(duration) and duration > 0,
    do: Keyword.put(params, :duration, duration)

  defp maybe_duration(params, _duration), do: params

  defp inflict_defender_procs(
         %Combatant{unit_type: :player} = source,
         %Combatant{unit_type: :player} = victim,
         roll,
         attack_flag
       ) do
    if normal_weapon_attack?(attack_flag) do
      Enum.each(@defender_procs, &try_defender_proc(&1, source, victim, roll))
    end

    :ok
  end

  defp inflict_defender_procs(_source, _victim, _roll, _attack_flag), do: :ok

  defp try_defender_proc(proc, source, victim, roll) do
    modifiers = source.equip_modifiers
    rate = Map.get(modifiers, {proc.rate, victim.race}, 0)

    if rate > 0 do
      duration = Map.get(modifiers, {proc.duration, victim.race}, 0)
      {rate, duration} = adjust_defender_proc(proc.status, rate, duration, victim)
      apply_defender_proc(proc, source, victim, modifiers, rate, duration, roll)
    end
  end

  defp apply_defender_proc(proc, source, victim, modifiers, rate, duration, roll) do
    if rate > 0 and roll.(rate) do
      params = [
        caster_id: source.unit_id,
        source_type: source.unit_type,
        duration: max(duration, 1)
      ]

      params = maybe_proc_value(params, proc, modifiers, victim.race)
      StatusInterpreter.apply_status(:player, victim.unit_id, proc.status, params)
    end
  end

  defp adjust_defender_proc(:sc_norecover_state, rate, duration, victim) do
    tolerance = Map.get(victim.equip_modifiers, {:res_eff, :sc_norecover_state}, 0)
    rate = max(0, rate - div(rate * tolerance, 10_000))
    {rate, duration - effective_luk(victim) * 100}
  end

  defp adjust_defender_proc(_status, rate, duration, _victim), do: {rate, duration}

  defp effective_luk(victim) do
    case UnitRegistry.get_unit(:player, victim.unit_id) do
      {:ok, {_module, %{stats: stats}, _pid}} -> PlayerStats.get_effective_stat(stats, :luk)
      _missing -> fallback_luk(victim)
    end
  end

  defp fallback_luk(victim) do
    status_luk =
      victim.unit_type
      |> ModifierCalculator.get_all_modifiers(victim.unit_id)
      |> Map.get(:luk, 0)

    Map.get(victim.base_stats, :luk, 0) + Map.get(victim.equip_modifiers, :luk, 0) + status_luk
  end

  defp maybe_proc_value(params, %{value: value_family}, modifiers, race) do
    Keyword.put(params, :val1, Map.get(modifiers, {value_family, race}, 0))
  end

  defp maybe_proc_value(params, _proc, _modifiers, _race), do: params

  defp normal_weapon_attack?(attack_flag) do
    BattleFlags.matches_battle?(@normal_short, attack_flag) or
      BattleFlags.matches_battle?(@normal_long, attack_flag)
  end

  @spec default_roll(non_neg_integer()) :: boolean()
  defp default_roll(effective), do: :rand.uniform(@roll_ceiling) <= effective
end
