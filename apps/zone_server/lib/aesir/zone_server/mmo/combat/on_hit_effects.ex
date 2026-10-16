defmodule Aesir.ZoneServer.Mmo.Combat.OnHitEffects do
  @moduledoc """
  On-hit status infliction from equipment (`bAddEff`, `bAddEff2`,
  `bAddEffOnSkill`, `bAddEffWhenHit`) and the attacker's race procs.

  Two stages, as rAthena runs them for every hit that reaches the damage step:

    * the additional-effect stage (`attack_stage/4`, `skill_additional_effect`)
      rolls the attacker's bAddEff/bAddEff2 entries and its bAddEffOnSkill
      entries for the skill that hit, for a connected or blocked hit on a target
      that lives and can hold statuses, then, for a connected normal weapon
      attack on a player, the race procs (bDefSetRace and its siblings);
    * the counter stage (`counter_stage/4`, `skill_counter_additional_effect`)
      rolls the bAddEffWhenHit entries of a player that was hit.

  Each entry is read as `pc_bonus_addeff` stores it: a flag naming its attack
  types (weapon unless named), ranges (both unless named) and victims (the
  enemy unless named), entries of one status and one flag merged into one rate.
  A bonus from the equipped ammunition counts only for a ranged attack. A type
  or range the entry narrows must match the attack. The status starts at level
  7 with the attacker as its source, whose status defense makes the one roll at
  the entry's per-10000 rate; the roll is injectable through `:roll` (the
  interpreter's `resistance_roll`) so tests are deterministic.
  """

  import Bitwise

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.AutoTriggerFlag
  alias Aesir.ZoneServer.Mmo.BattleFlag
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @normal_short BattleFlags.build(:weapon, :short, false)
  @normal_long BattleFlags.build(:weapon, :long, false)

  @atf_self AutoTriggerFlag.id(:self)
  @atf_target AutoTriggerFlag.id(:target)
  @atf_short AutoTriggerFlag.id(:short)
  @atf_long AutoTriggerFlag.id(:long)
  @atf_weapon AutoTriggerFlag.id(:weapon)
  @atf_magic AutoTriggerFlag.id(:magic)
  @atf_misc AutoTriggerFlag.id(:misc)
  @atf_types @atf_weapon ||| @atf_magic ||| @atf_misc
  @atf_ranges @atf_short ||| @atf_long

  @bf_weapon BattleFlag.id(:weapon)
  @bf_magic BattleFlag.id(:magic)
  @bf_misc BattleFlag.id(:misc)
  @bf_short BattleFlag.id(:short)
  @bf_long BattleFlag.id(:long)

  # Skills whose hits never roll the attacker's bAddEff entries: Cart
  # Termination, Bomb, Reflect Shield (and the mercenary's), Hell's Plant, and
  # classic Soul Breaker.
  @no_add_eff_skills [485, 229, 252, 8205, 2491]
  @classic_no_add_eff_skills [379]

  @add_eff_level 7

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

  @typedoc """
  A settled hit's stages: its class (`DamageShared.hit_class/3`), whether its
  additional-effect stage runs (the target survived) and whether its counter
  stage runs.
  """
  @type stages :: %{
          required(:hit_class) => :miss | :block | :hit,
          required(:attack_effects?) => boolean(),
          required(:counter_effects?) => boolean(),
          optional(atom()) => term()
        }

  @typedoc """
  A party to a hit: a combatant, or a monster known only by identity
  (`EquipProcDispatch.party_ref/0`), which wears nothing.
  """
  @type party :: Combatant.t() | %{unit_type: atom(), unit_id: integer()}

  @typedoc "One merged bAddEff entry: its status, full flag, rates and duration."
  @type entry :: %{
          sc: atom(),
          flag: BattleFlags.flag(),
          rate: integer(),
          arrow_rate: integer(),
          duration: non_neg_integer()
        }

  @doc """
  Runs both stages of one settled hit, the additional-effect stage first.

  ## Options
    - `:roll` - a `t:roll_fun/0` used for every per-10000 roll (default `:rand`).
    - `:attack_flag` - the hit's `BattleFlags` classification.
    - `:skill_id` - the skill that landed this hit; a normal attack passes none.
  """
  @spec after_hit(party(), party(), stages() | nil, keyword()) :: :ok
  def after_hit(attacker, defender, stages, opts \\ []) do
    attack_stage(attacker, defender, stages, opts)
    counter_stage(attacker, defender, stages, opts)
  end

  @doc """
  The additional-effect stage of a prepared hit carrying a `:proc` spec
  (`EquipProcDispatch.spec/5`), settled at `damage`; a hit without a spec runs
  nothing.
  """
  @spec attack_stage(map(), integer()) :: :ok
  def attack_stage(%{proc: proc} = hit_info, damage),
    do:
      attack_stage(
        proc.attacker,
        proc.target,
        EquipProcDispatch.hit_event(hit_info, damage),
        spec_opts(proc)
      )

  def attack_stage(_hit_info, _damage), do: :ok

  @doc "Both stages of a prepared hit carrying a `:proc` spec (`attack_stage/2`)."
  @spec after_hit(map(), integer()) :: :ok
  def after_hit(hit_info, damage) do
    attack_stage(hit_info, damage)
    counter_stage(hit_info, damage)
  end

  @doc "The counter stage of a prepared hit carrying a `:proc` spec (`attack_stage/2`)."
  @spec counter_stage(map(), integer()) :: :ok
  def counter_stage(%{proc: proc} = hit_info, damage),
    do:
      counter_stage(
        proc.attacker,
        proc.target,
        EquipProcDispatch.hit_event(hit_info, damage),
        spec_opts(proc)
      )

  def counter_stage(_hit_info, _damage), do: :ok

  defp spec_opts(proc), do: [attack_flag: proc.attack_flag, skill_id: Map.get(proc, :skill_id)]

  @doc """
  The additional-effect stage of one settled hit (`after_hit/4`'s options).
  A target that cannot hold statuses (a skill unit) is skipped.
  """
  @spec attack_stage(party(), party(), stages() | nil, keyword()) :: :ok
  def attack_stage(_attacker, %{unit_type: :skill_unit}, _stages, _opts), do: :ok

  def attack_stage(
        %{unit_type: _, unit_id: _} = attacker,
        %{unit_type: _, unit_id: _} = defender,
        %{attack_effects?: true, hit_class: hit_class},
        opts
      )
      when hit_class in [:block, :hit] do
    roll = Keyword.get(opts, :roll, &default_roll/1)
    attack_flag = Keyword.get(opts, :attack_flag, 0)
    skill_id = Keyword.get(opts, :skill_id)

    if add_eff_skill?(skill_id), do: inflict_add_eff(attacker, defender, roll, attack_flag)
    inflict_on_skill(attacker, defender, skill_id, roll)

    if hit_class == :hit, do: inflict_defender_procs(attacker, defender, roll, attack_flag)
    :ok
  end

  def attack_stage(_attacker, _defender, _stages, _opts), do: :ok

  @doc """
  The counter stage of one settled hit (`after_hit/4`'s options): a player
  that was hit rolls its bAddEffWhenHit entries. An entry's enemy victim is
  the attacker (never the wearer itself); its self victim is the wearer.
  """
  @spec counter_stage(party(), party(), stages() | nil, keyword()) :: :ok
  def counter_stage(
        %{unit_type: _, unit_id: _} = attacker,
        %{unit_type: :player} = wearer,
        %{counter_effects?: true},
        opts
      ) do
    roll = Keyword.get(opts, :roll, &default_roll/1)
    attack_flag = Keyword.get(opts, :attack_flag, 0)

    if (attack_flag &&& (@bf_weapon ||| @bf_magic ||| @bf_misc)) != 0 do
      wearer
      |> entries(:add_eff_when_hit)
      |> Enum.each(&roll_when_hit(&1, attacker, wearer, roll, attack_flag))
    end

    :ok
  end

  def counter_stage(_attacker, _wearer, _stages, _opts), do: :ok

  @doc """
  The additional-effect stage of an effect the source starts at ATK_DEF
  without dealing damage (a song, a no-damage trap, Frost Joke, Scream, Ki
  Explosion's push, a successful Wink of Charm), from `attacker` (a unit state
  or combatant) against `target` (a unit ref or party). Only a player carries
  bAddEff entries, so any other attacker rolls nothing.
  """
  @spec direct(
          struct(),
          party() | {atom(), integer()},
          BattleFlags.flag(),
          integer() | nil,
          keyword()
        ) ::
          :ok
  def direct(attacker, target, attack_flag, skill_id, opts \\ [])

  def direct(%Combatant{unit_type: :player} = attacker, target, attack_flag, skill_id, opts),
    do: run_direct(attacker, target, attack_flag, skill_id, opts)

  def direct(%PlayerState{character_id: id, stats: stats}, target, attack_flag, skill_id, opts) do
    wearer = %{unit_type: :player, unit_id: id, equip_modifiers: equipment(stats)}
    run_direct(wearer, target, attack_flag, skill_id, opts)
  end

  def direct(_attacker, _target, _attack_flag, _skill_id, _opts), do: :ok

  defp run_direct(attacker, target, attack_flag, skill_id, opts) do
    stages = %{hit_class: :hit, attack_effects?: true, counter_effects?: false}

    attack_stage(
      attacker,
      party(target),
      stages,
      Keyword.merge(opts, attack_flag: attack_flag, skill_id: skill_id)
    )
  end

  defp equipment(%{modifiers: %{equipment: equipment}}) when is_map(equipment), do: equipment
  defp equipment(_stats), do: %{}

  defp party({unit_type, unit_id}), do: %{unit_type: unit_type, unit_id: unit_id}
  defp party(%PlayerState{character_id: id}), do: %{unit_type: :player, unit_id: id}
  defp party(%{unit_type: _, unit_id: _} = party), do: party

  @doc """
  The merged entries of one family (`:add_eff`, which also reads `:add_eff2`
  and the ammunition's entries, or `:add_eff_when_hit`) carried by `source`.
  """
  @spec entries(party(), :add_eff | :add_eff_when_hit) :: [entry()]
  def entries(source, family) do
    modifiers = Map.get(source, :equip_modifiers, %{})

    modifiers
    |> Enum.flat_map(&entry(&1, family))
    |> Enum.group_by(&{&1.sc, &1.flag})
    |> Enum.sort()
    |> Enum.map(fn {{sc, flag}, parts} ->
      %{
        sc: sc,
        flag: flag,
        rate: parts |> Enum.map(& &1.rate) |> Enum.sum(),
        arrow_rate: parts |> Enum.map(& &1.arrow_rate) |> Enum.sum(),
        duration: duration(modifiers, family, sc, flag)
      }
    end)
  end

  defp entry({{family, param}, rate}, family) when is_integer(rate),
    do: normalized(param, 0, rate, 0)

  defp entry({{:add_eff2, param}, rate}, :add_eff) when is_integer(rate),
    do: normalized(param, @atf_self, rate, 0)

  defp entry({{:arrow_add_eff, param}, rate}, :add_eff) when is_integer(rate),
    do: normalized(param, 0, 0, rate)

  defp entry({{:arrow_add_eff2, param}, rate}, :add_eff) when is_integer(rate),
    do: normalized(param, @atf_self, 0, rate)

  defp entry(_modifier, _family), do: []

  defp normalized({sc, flag}, _implied, rate, arrow_rate) when is_atom(sc) and is_integer(flag),
    do: [%{sc: sc, flag: BattleFlags.fill_trigger(flag), rate: rate, arrow_rate: arrow_rate}]

  defp normalized(sc, implied, rate, arrow_rate) when is_atom(sc),
    do: [%{sc: sc, flag: BattleFlags.fill_trigger(implied), rate: rate, arrow_rate: arrow_rate}]

  defp normalized(_param, _implied, _rate, _arrow_rate), do: []

  defp duration(modifiers, family, sc, flag),
    do: max(Map.get(modifiers, {duration_family(family), {sc, flag}}, 0), 0)

  defp duration_family(:add_eff), do: :add_eff_duration
  defp duration_family(:add_eff_when_hit), do: :add_eff_when_hit_duration

  defp add_eff_skill?(nil), do: true

  defp add_eff_skill?(skill_id) do
    skill_id not in @no_add_eff_skills and
      not (GameMode.mode() == :pre_renewal and
             skill_id in @classic_no_add_eff_skills)
  end

  defp inflict_add_eff(attacker, defender, roll, attack_flag) do
    attacker
    |> entries(:add_eff)
    |> Enum.each(&roll_add_eff(&1, attacker, defender, roll, attack_flag))
  end

  defp roll_add_eff(entry, attacker, defender, roll, attack_flag) do
    rate = entry.rate + if((attack_flag &&& @bf_long) != 0, do: entry.arrow_rate, else: 0)

    if rate != 0 and matches?(entry.flag, attack_flag) do
      if (entry.flag &&& @atf_target) != 0,
        do: try_inflict(attacker, defender, entry.sc, rate, roll, entry.duration)

      if (entry.flag &&& @atf_self) != 0,
        do: try_inflict(attacker, attacker, entry.sc, rate, roll, entry.duration)
    end
  end

  defp roll_when_hit(entry, attacker, wearer, roll, attack_flag) do
    if entry.rate != 0 and matches?(entry.flag, attack_flag) do
      if (entry.flag &&& @atf_target) != 0 and not same_unit?(attacker, wearer),
        do: try_inflict(attacker, attacker, entry.sc, entry.rate, roll, entry.duration)

      if (entry.flag &&& @atf_self) != 0,
        do: try_inflict(attacker, wearer, entry.sc, entry.rate, roll, entry.duration)
    end
  end

  defp same_unit?(a, b), do: {a.unit_type, a.unit_id} == {b.unit_type, b.unit_id}

  # A type or range the entry narrows must match the attack: any named type
  # the attack is, and every named range the attack is.
  defp matches?(flag, attack_flag),
    do: type_matches?(flag, attack_flag) and range_matches?(flag, attack_flag)

  defp type_matches?(flag, _attack_flag) when (flag &&& @atf_types) == @atf_types, do: true

  defp type_matches?(flag, attack_flag) do
    ((flag &&& @atf_weapon) != 0 and (attack_flag &&& @bf_weapon) != 0) or
      ((flag &&& @atf_magic) != 0 and (attack_flag &&& @bf_magic) != 0) or
      ((flag &&& @atf_misc) != 0 and (attack_flag &&& @bf_misc) != 0)
  end

  defp range_matches?(flag, _attack_flag) when (flag &&& @atf_ranges) == @atf_ranges, do: true

  defp range_matches?(flag, attack_flag) do
    not ((flag &&& @atf_long) != 0 and (attack_flag &&& @bf_long) == 0) and
      not ((flag &&& @atf_short) != 0 and (attack_flag &&& @bf_short) == 0)
  end

  # `bAddEffOnSkill` arms a status on one named skill landing, whatever kind of
  # attack that skill is; a hit from any other skill, or a normal attack, rolls
  # nothing.
  defp inflict_on_skill(_attacker, _defender, nil, _roll), do: :ok

  defp inflict_on_skill(attacker, defender, skill_id, roll) do
    Enum.each(Map.get(attacker, :equip_modifiers, %{}), fn
      {{:add_eff_on_skill, ^skill_id, sc}, rate} when is_atom(sc) and rate != 0 ->
        try_inflict(attacker, defender, sc, rate, roll, 0)

      _entry ->
        :ok
    end)
  end

  # Hands `sc` to the status system for `victim` at the entry's rate at level
  # 7, naming `source` as its source; the status defense makes the one roll.
  defp try_inflict(source, victim, sc, rate, roll, duration) do
    params =
      source
      |> chance_params(rate, roll)
      |> Keyword.put(:val1, @add_eff_level)
      |> maybe_duration(duration)

    StatusInterpreter.apply_status(victim.unit_type, victim.unit_id, sc, params)
    :ok
  end

  defp chance_params(source, rate, roll) do
    [
      caster_id: source.unit_id,
      source_type: source.unit_type,
      success_rate: rate / 100,
      resistance_roll: roll
    ]
  end

  defp maybe_duration(params, duration) when is_integer(duration) and duration > 0,
    do: Keyword.put(params, :duration, duration)

  defp maybe_duration(params, _duration), do: params

  defp inflict_defender_procs(
         %Combatant{unit_type: :player} = source,
         %{unit_type: :player, race: _} = victim,
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

      params =
        source
        |> chance_params(rate, roll)
        |> Keyword.put(:duration, max(duration, 1))
        |> maybe_proc_value(proc, modifiers, victim.race)

      StatusInterpreter.apply_status(:player, victim.unit_id, proc.status, params)
    end
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
  defp default_roll(rate), do: Resistance.roll_rate(rate)
end
