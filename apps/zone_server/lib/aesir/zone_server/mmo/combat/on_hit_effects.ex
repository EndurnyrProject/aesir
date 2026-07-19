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

  ## Options
    - `:roll` - a `t:roll_fun/0` used for every per-10000 roll (default `:rand`).
  """
  @spec after_hit(Combatant.t(), Combatant.t(), map(), keyword()) :: :ok
  def after_hit(attacker, defender, damage_result, opts \\ [])

  def after_hit(_attacker, _defender, %{damage: damage}, _opts) when damage <= 0, do: :ok

  def after_hit(_attacker, %Combatant{unit_type: :skill_unit}, _damage_result, _opts), do: :ok

  def after_hit(%Combatant{} = attacker, %Combatant{} = defender, _damage_result, opts) do
    roll = Keyword.get(opts, :roll, &default_roll/1)

    inflict(attacker, defender, :add_eff, roll)
    inflict(defender, attacker, :add_eff_when_hit, roll)
    :ok
  end

  # Rolls every `{family, sc}` bonus on `source` against `victim`, applying the
  # status to `victim` with `source` named as the caster so boss immunity gates.
  @spec inflict(Combatant.t(), Combatant.t(), atom(), roll_fun()) :: :ok
  defp inflict(source, victim, family, roll) do
    for {{^family, sc}, rate} <- source.equip_modifiers do
      effective = rate - Map.get(victim.equip_modifiers, {:res_eff, sc}, 0)

      if effective > 0 and roll.(effective) do
        StatusInterpreter.apply_status(victim.unit_type, victim.unit_id, sc,
          caster_id: source.unit_id,
          source_type: source.unit_type,
          res_eff_exempt: true
        )
      end
    end

    :ok
  end

  @spec default_roll(non_neg_integer()) :: boolean()
  defp default_roll(effective), do: :rand.uniform(@roll_ceiling) <= effective
end
