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

  @roll_ceiling 10_000

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
        inflict_flagged(source, other, sc, rate, roll, flag, attack_flag)

      {{^family, sc}, rate} when is_atom(sc) ->
        try_inflict(source, other, sc, rate, roll)

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
          roll_fun(),
          BattleFlags.flag(),
          BattleFlags.flag()
        ) :: :ok
  defp inflict_flagged(source, other, sc, rate, roll, flag, attack_flag) do
    if BattleFlags.matches_trigger?(flag, attack_flag) do
      victims =
        [
          BattleFlags.target_victim?(flag) && other,
          BattleFlags.self_victim?(flag) && source
        ]
        |> Enum.filter(& &1)

      Enum.each(victims, &try_inflict(source, &1, sc, rate, roll))
    end

    :ok
  end

  # Applies `sc` to `victim` when the roll lands, with `source` named as the
  # caster so boss immunity gates. The victim's tolerance for the status is
  # subtracted from the proc rate here, so the status system does not apply it
  # a second time.
  @spec try_inflict(Combatant.t(), Combatant.t(), atom(), integer(), roll_fun()) :: :ok
  defp try_inflict(source, victim, sc, rate, roll) do
    effective = rate - Map.get(victim.equip_modifiers, {:res_eff, sc}, 0)

    if effective > 0 and roll.(effective) do
      StatusInterpreter.apply_status(victim.unit_type, victim.unit_id, sc,
        caster_id: source.unit_id,
        source_type: source.unit_type,
        res_eff_exempt: true
      )
    end

    :ok
  end

  @spec default_roll(non_neg_integer()) :: boolean()
  defp default_roll(effective), do: :rand.uniform(@roll_ceiling) <= effective
end
