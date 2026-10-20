defmodule Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch do
  @moduledoc """
  Hands one logical hit's equipment procs to the players who wear them.

  Every attack path (normal swings, physical, magic and misc skills, fields)
  attaches a `t:spec/0` to its hit as `:proc`. `DamageApplication` turns it
  into an `t:event/0` once the hit is settled and sends it with the hit to the
  target's own damage handler, which calls `when_hit/3` after its HP changed,
  so a recipient that died to the hit gets no when-hit proc and nothing is
  rolled in the attacker's process on the recipient's behalf. The attack path
  dispatches the attacker's side (`dispatch_hit/2`) after the hit's additional
  effects.

  Attack-side autocasts belong to the additional-effect stage: they need the
  target to survive and the hit to have connected (`:hit`). Autobonuses and
  when-hit procs belong to the counter stage, whose gate the producer decides
  per stage (`counter_effects?`): a positive damage for an immediate hit, a
  connected hit for a delayed one. A damaging skill hit also arms the caster's
  on-skill procs.

  Polymorph closes the additional-effect stage: a weapon hit from a wearer
  carrying `bClassChange` changes a monster that is not status-immune into a
  random form from the pool, when the hit left it alive. A monster a player
  summoned answers that stage with its master's procs; the counter stage and
  the on-skill procs stay the attacker's own, as the reference's two stages do.

  Selection is pure (`EquipAutocast`, `EquipAutobonus`); each selected autocast
  goes to its wearer's session as `{:skill, {:equip_proc, candidate}}`, where the
  usability check and the level and chance draws run in their branch's order.
  The usability check sets and then resets the wearer's autocast flag; that
  reset is applied here too, in the dispatching process, because it clears a
  flag an enclosing proc of the same wearer had set.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutobonus
  alias Aesir.ZoneServer.Mmo.Combat.EquipAutocast
  alias Aesir.ZoneServer.Mmo.Combat.RaceModifiers
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.MobManagement.PolymorphPool
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Skill.Origin
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @grand_cross 254
  @lock {__MODULE__, :on_skill_lock}
  @polymorph_scale 10_000

  @typedoc """
  One resolved hit as its procs see it.

    * `attack_flag` - the hit's damage type, range and origin.
    * `divisions` - the normalized division count; the hit rolls once.
    * `hit_class` - connected (`:hit`), blocked or missed.
    * `damage` - the damage the counter stage is gated on.
    * `attack_effects?` - the additional-effect stage runs (the target survived).
    * `counter_effects?` - the counter stage runs.
    * `arrow_attack?` - the attacker is in the arrow-attack state.
    * `skill_id` - the skill that hit, `nil` for a normal swing.
  """
  @type event :: %{
          attack_flag: BattleFlags.flag(),
          divisions: non_neg_integer(),
          hit_class: :miss | :block | :hit,
          damage: integer(),
          attack_effects?: boolean(),
          counter_effects?: boolean(),
          arrow_attack?: boolean(),
          skill_id: pos_integer() | nil
        }

  @typedoc "A wearer as on-skill selection needs it: a player combatant or its subset."
  @type wearer :: %{
          required(:unit_id) => integer(),
          required(:equip_modifiers) => map(),
          required(:equip_autobonuses) => map(),
          optional(atom()) => term()
        }

  @typedoc "A party to a hit known only by identity: a monster attacker or target wears nothing."
  @type party_ref :: %{unit_type: atom(), unit_id: integer()}

  @typedoc """
  What an attack path attaches to a hit as `:proc`, so `DamageApplication`
  dispatches its equipment procs once the hit is settled: the two combatants,
  the target's HP before the hit (nil when unknown), and the static options of
  `event/4`.
  """
  @type spec :: %{
          required(:attacker) => Combatant.t() | party_ref(),
          required(:target) => Combatant.t() | party_ref(),
          required(:target_hp) => integer() | nil,
          required(:attack_flag) => BattleFlags.flag(),
          optional(:divisions) => non_neg_integer(),
          optional(:skill_id) => pos_integer() | nil,
          optional(:immediate?) => boolean(),
          optional(:arrow_attack?) => boolean()
        }

  @doc """
  Builds the `:proc` spec for one hit of `attacker` on `target`, whose pre-hit
  unit state (or HP) is `target_state`. `opts` are `event/4`'s static options.
  A party that wears nothing (a monster) may be given as a `t:party_ref/0`.
  """
  @spec spec(
          Combatant.t() | party_ref(),
          Combatant.t() | party_ref(),
          term(),
          BattleFlags.flag(),
          keyword()
        ) :: spec()
  def spec(attacker, target, target_state, attack_flag, opts \\ []) do
    opts
    |> Map.new()
    |> Map.merge(%{
      attacker: attacker,
      target: target,
      target_hp: hp(target_state),
      attack_flag: attack_flag
    })
  end

  defp hp(hp) when is_integer(hp), do: hp
  defp hp(%{stats: %{current_state: %{hp: hp}}}) when is_integer(hp), do: hp
  defp hp(%{hp: hp}) when is_integer(hp), do: hp
  defp hp(_state), do: nil

  @doc """
  Builds the event for one prepared hit.

  `hit_info` is the hit as `DamageApplication.prepare_unit_damage/5` returned
  it, classified by `DamageShared.hit_class/3`: a total below 1 is a miss, so it
  runs neither stage. An immediate Devotion-forwarded hit gates its counter
  stage on the damage before forwarding.

  ## Options
    - `:immediate?` - the hit resolves immediately (ground skills and fields)
      rather than after the attack motion (normal swings, targeted skills).
    - `:target_survives?` - whether the target outlives the hit (default true).
    - `:divisions` (default 1), `:skill_id`, `:arrow_attack?` (default false).
  """
  @spec event(BattleFlags.flag(), integer(), map(), keyword()) :: event()
  def event(attack_flag, damage, hit_info, opts \\ []) do
    immediate? = Keyword.get(opts, :immediate?, false)
    gate_damage = DamageShared.settled_total(hit_info, damage)
    hit_class = DamageShared.hit_class(hit_info, damage, immediate?)

    %{
      attack_flag: attack_flag,
      divisions: Keyword.get(opts, :divisions, 1),
      hit_class: hit_class,
      damage: gate_damage,
      attack_effects?: Keyword.get(opts, :target_survives?, true),
      counter_effects?: if(immediate?, do: gate_damage > 0, else: hit_class == :hit),
      arrow_attack?: Keyword.get(opts, :arrow_attack?, false),
      skill_id: Keyword.get(opts, :skill_id)
    }
  end

  @doc """
  The event of a prepared hit carrying a `:proc` spec, settled at `damage`;
  nil without a spec. A target known to outlive the hit, left alive by coma,
  or a skill unit keeps the additional-effect stage.
  """
  @spec hit_event(map(), integer()) :: event() | nil
  def hit_event(%{proc: proc} = hit_info, damage) do
    survives? =
      Map.get(hit_info, :coma?, false) or proc.target.unit_type == :skill_unit or
        (is_integer(proc.target_hp) and proc.target_hp > damage)

    opts =
      proc
      |> Map.take([:divisions, :skill_id, :immediate?, :arrow_attack?])
      |> Map.put(:target_survives?, survives?)
      |> Enum.to_list()

    event(proc.attack_flag, damage, hit_info, opts)
  end

  def hit_event(_hit_info, _damage), do: nil

  @doc """
  Dispatches the attacker's side of a prepared hit settled at `damage`.

  Called by the attack path after the hit's additional effects, as the
  reference rolls the attack-side autospell after them.
  """
  @spec dispatch_hit(map(), integer()) :: :ok
  def dispatch_hit(%{proc: proc} = hit_info, damage),
    do: dispatch(proc.attacker, proc.target, hit_event(hit_info, damage))

  def dispatch_hit(_hit_info, _damage), do: :ok

  @doc """
  Dispatches the attacker's side of a hit once its delivery succeeded; see
  `dispatch_hit/2`.
  """
  @spec dispatch_delivered(term(), map(), integer()) :: :ok
  def dispatch_delivered({:error, _reason}, _hit_info, _damage), do: :ok
  def dispatch_delivered(_delivery, hit_info, damage), do: dispatch_hit(hit_info, damage)

  @doc """
  Whether a hit of `skill_id` delivered as `delivery` resolves immediately: a
  ground skill's hits and every hit whose actual source is a field do; a
  targeted skill's land after the attack motion.
  """
  @spec immediate?(pos_integer(), atom() | tuple()) :: boolean()
  def immediate?(_skill_id, :unit), do: true

  def immediate?(skill_id, _delivery),
    do: match?({:ok, %{target_type: :ground}}, Catalog.by_id(skill_id))

  @doc """
  Dispatches the attacker's side of one hit: attack-side autocasts, polymorph,
  attack autobonuses and, for a damaging skill hit, on-skill procs. A monster
  that wears nothing dispatches nothing, except that a player's summon answers
  the additional-effect stage with its master's procs.
  """
  @spec dispatch(Combatant.t(), Combatant.t(), event()) :: :ok
  def dispatch(%Combatant{} = attacker, %Combatant{} = target, event) do
    dispatch_attack_effects(attacker, target, event)
    dispatch_own_effects(attacker, target, event)
  end

  def dispatch(_attacker, _target, _event), do: :ok

  # The additional-effect stage: attack autocasts and polymorph. A summon's
  # master answers for this stage, per the reference's summon inheritance.
  defp dispatch_attack_effects(attacker, target, event) do
    case wearer(attacker) do
      nil ->
        :ok

      wearer ->
        if event.attack_effects? and event.hit_class == :hit do
          wearer
          |> EquipAutocast.on_attack(target, event.attack_flag, event.arrow_attack?)
          |> send_candidates(wearer.unit_id)
        end

        if polymorph_target?(target, event), do: roll_polymorph(wearer, target)

        :ok
    end
  end

  # The counter stage and on-skill procs read the attacker itself: the
  # reference hands a summon only its master's additional-effect stage down.
  defp dispatch_own_effects(%Combatant{unit_type: :player} = attacker, target, event) do
    if event.counter_effects? do
      attacker.equip_autobonuses
      |> EquipAutobonus.on_attack(counter_flag(event, attacker.unit_id, ref(target)))
      |> send_autobonuses(attacker)
    end

    if is_integer(event.skill_id) and event.damage > 0 do
      on_skill(attacker, event.skill_id, {:unit, target.unit_id})
    end

    :ok
  end

  defp dispatch_own_effects(_attacker, _target, _event), do: :ok

  # A player's hits wear the player's equipment. A monster summoned by a player
  # lends its master's equipment procs to the summon's hits, so the reference
  # passes the owner's bonuses down to what the summon attacks.
  defp wearer(%Combatant{unit_type: :player} = attacker), do: attacker

  defp wearer(%Combatant{unit_type: :mob, proc_owner_id: owner}) when is_integer(owner) do
    case TargetResolver.resolve_combatant({:player, owner}) do
      {:ok, master} -> master
      _unresolved -> nil
    end
  end

  defp wearer(_attacker), do: nil

  # The reference rolls polymorph at the tail of its additional-effect stage:
  # a weapon hit that left a living, status-immune-free monster can change its
  # form to a random entry of the shared pool.
  defp polymorph_target?(%Combatant{unit_type: :mob, status_immune: false}, event) do
    event.attack_effects? and event.hit_class != :miss and
      BattleFlags.weapon?(event.attack_flag)
  end

  defp polymorph_target?(_target, _event), do: false

  defp roll_polymorph(wearer, target) do
    rate = Map.get(wearer.equip_modifiers, :class_change, 0)

    if is_integer(rate) and rate > 0 and :rand.uniform(@polymorph_scale) <= rate do
      case PolymorphPool.pick() do
        0 -> :ok
        replacement_id -> polymorph(target.unit_id, replacement_id)
      end
    end

    :ok
  end

  defp polymorph(unit_id, replacement_id) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) -> MobSession.polymorph(pid, replacement_id)
      _unresolved -> :ok
    end
  end

  @doc """
  Dispatches the recipient's side of one hit from its own damage handler,
  after its HP changed: when-hit autocasts, then when-hit autobonuses. Runs only
  when the counter stage does, the recipient is a living player, and the
  hitting skill deals damage. Grand Cross striking its own caster counts as a
  weapon hit here. `wearer` is the recipient player (a combatant or its subset).
  """
  @spec when_hit(wearer(), Ref.t() | nil, event()) :: :ok
  def when_hit(_wearer, nil, _event), do: :ok

  def when_hit(wearer, attacker, event) do
    if event.counter_effects? and not no_damage_skill?(event.skill_id) do
      attack_flag = counter_flag(event, wearer.unit_id, attacker)

      wearer
      |> EquipAutocast.when_hit(attacker_id(attacker), attack_flag)
      |> send_candidates(wearer.unit_id)

      wearer.equip_autobonuses
      |> EquipAutobonus.when_hit(attack_flag)
      |> send_autobonuses(wearer)
    end

    :ok
  end

  @doc """
  Dispatches a caster's on-skill procs for one use of `skill_id` at `target`.

  Entries whose own proc is executing in this process are locked and skipped,
  so a proc cannot re-trigger the entry that cast it.
  """
  @spec on_skill(wearer(), pos_integer(), :self | {:unit, integer()} | nil) :: :ok
  def on_skill(wearer, skill_id, target) do
    locked = Process.get(@lock, [])

    wearer.equip_modifiers
    |> EquipAutocast.on_skill(skill_id, target)
    |> Enum.reject(&({wearer.unit_id, &1.entry} in locked))
    |> send_candidates(wearer.unit_id)

    wearer.equip_autobonuses
    |> EquipAutobonus.on_skill(skill_id)
    |> send_autobonuses(wearer)
  end

  @doc """
  Where a completed cast of `definition` at `target` arms on-skill procs.

  A damage skill arms them per damaging hit instead (`dispatch/3`), so it
  returns `:none`. Support, self and no-damage skills arm them at their target,
  self skills at their caster. Ground skills and self skills placed as a unit
  (Grand Cross, Gospel, Moonlit Water Mill; classic songs, Basilica and
  Hermode too) arm them without a target. Heal, Resurrection and Aspersio cast
  at an undead-element target become damage casts and return `:none`.
  """
  # Cast at an undead-element target, these turn into a damage cast (or fail),
  # so their castend arms nothing; the damaging hit arms the on-skill procs.
  @undead_strike_skills [:al_heal, :all_resurrection, :pr_aspersio]

  @spec castend_target(Definition.t(), term()) ::
          {:ok, :self | {:unit, integer()} | nil} | :none
  def castend_target(%Definition{target_type: :ground}, _target), do: {:ok, nil}

  def castend_target(%Definition{} = definition, target) do
    cond do
      definition.name in self_unit_skills() -> {:ok, nil}
      definition.name in @undead_strike_skills and undead_target?(target) -> :none
      no_damage_cast?(definition) -> {:ok, castend_unit(target)}
      true -> :none
    end
  end

  defp undead_target?({:unit, target}) do
    case TargetResolver.resolve_combatant(target) do
      {:ok, combatant} -> RaceModifiers.undead_target?(combatant)
      _unresolved -> false
    end
  end

  defp undead_target?(_target), do: false

  defp no_damage_cast?(definition), do: Definition.cast_type(definition) != :damage

  defp castend_unit({:unit, {_type, id}}), do: {:unit, id}
  defp castend_unit({:unit, id}), do: {:unit, id}
  defp castend_unit(:self), do: :self
  defp castend_unit(_target), do: nil

  @doc """
  The on-skill target of one target's per-target cast-end tail: the hit
  target's unit id, or `nil` for a target with no unit (a cell).
  """
  @spec hit_target(term()) :: {:unit, integer()} | nil
  def hit_target(target), do: castend_unit(target)

  @renewal_self_units [:cr_grandcross, :pa_gospel, :cg_moonlit]
  @classic_self_units @renewal_self_units ++
                        [
                          :bd_lullaby,
                          :bd_richmankim,
                          :bd_eternalchaos,
                          :bd_drumbattlefield,
                          :bd_ringnibelungen,
                          :bd_rokisweil,
                          :bd_intoabyss,
                          :bd_siegfried,
                          :ba_dissonance,
                          :ba_whistle,
                          :ba_assassincross,
                          :ba_poembragi,
                          :ba_appleidun,
                          :dc_uglydance,
                          :dc_humming,
                          :dc_dontforgetme,
                          :dc_fortunekiss,
                          :dc_serviceforyou,
                          :hp_basilica,
                          :cg_hermode
                        ]

  @doc "Whether a self cast of `definition` is placed as a ground unit at the caster."
  @spec self_unit_skill?(Definition.t()) :: boolean()
  def self_unit_skill?(%Definition{name: name}), do: name in self_unit_skills()

  defp self_unit_skills do
    if GameMode.mode() == :renewal, do: @renewal_self_units, else: @classic_self_units
  end

  @doc """
  Runs `fun` with the wearer's on-skill `entry` locked against re-triggering.
  """
  @spec with_on_skill_lock(integer(), term(), (-> result)) :: result when result: term()
  def with_on_skill_lock(wearer_id, entry, fun) do
    previous = Process.get(@lock, [])
    Process.put(@lock, [{wearer_id, entry} | previous])

    try do
      fun.()
    after
      Process.put(@lock, previous)
    end
  end

  defp send_candidates([], _wearer_id), do: :ok

  defp send_candidates(candidates, wearer_id) do
    ref = {:player, wearer_id}
    Enum.each(candidates, fn _candidate -> Origin.set_autocast_flag(ref, false) end)

    with {:ok, pid} <- UnitRegistry.get_player_pid(wearer_id) do
      Enum.each(candidates, &GenServer.cast(pid, {:skill, {:equip_proc, &1}}))
    end

    :ok
  end

  defp send_autobonuses([], _wearer), do: :ok

  defp send_autobonuses(keys, %{unit_id: unit_id, equip_autobonuses: registrations}) do
    with {:ok, pid} <- UnitRegistry.get_player_pid(unit_id) do
      Enum.each(keys, fn key ->
        source_identity = registrations |> Map.fetch!(key) |> Map.fetch!(:source_identity)
        GenServer.cast(pid, {:equipment, {:autobonus_activate, key, source_identity}})
      end)
    end

    :ok
  end

  defp no_damage_skill?(skill_id) when is_integer(skill_id),
    do: match?({:ok, %{damage_type: :no_damage}}, Catalog.by_id(skill_id))

  defp no_damage_skill?(_skill_id), do: false

  # The counter stage's attack flag. Grand Cross striking its own caster turns
  # it into a weapon hit for the attack autobonuses and when-hit procs alike.
  defp counter_flag(%{skill_id: @grand_cross, attack_flag: flag}, caster_id, {:player, caster_id}) do
    flag
    |> Bitwise.bor(BattleFlags.type_bit(:weapon))
    |> Bitwise.band(Bitwise.bnot(BattleFlags.type_bit(:magic)))
  end

  defp counter_flag(%{attack_flag: flag}, _wearer_id, _other), do: flag

  defp ref(%{unit_type: type, unit_id: id}), do: {type, id}

  defp attacker_id({_type, id}), do: id
end
