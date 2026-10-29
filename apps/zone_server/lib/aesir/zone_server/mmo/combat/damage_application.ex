defmodule Aesir.ZoneServer.Mmo.Combat.DamageApplication do
  @moduledoc """
  Delivers already-calculated damage (and heals) to the owning unit session.

  The shared tail of every attack path: runs the hit through the pre-damage
  status absorption hook, routes the final damage to the target's session by
  unit type, runs the victim's post-damage reflect hook, and broadcasts combat
  packets to nearby players. Keeps the attack paths free of concrete
  session-module knowledge.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Combat.DamageDisplay
  alias Aesir.ZoneServer.Mmo.Combat.DamageShared
  alias Aesir.ZoneServer.Mmo.Combat.Endure
  alias Aesir.ZoneServer.Mmo.Combat.EquipComa
  alias Aesir.ZoneServer.Mmo.Combat.EquipProcDispatch
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Devotion
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  # Counter Instinct, the skill a final weapon stage counter is dealt as.
  @counter_skill_id 390

  @doc """
  Resolves pre-delivery equipment and status damage modifiers for one hit.

  Skill magic damage is reduced by the target's equipment first, then the
  target's damage statuses run in their fixed stage order. On siege ground,
  eligibility precedes mutable hooks and absorption precedes the map rate.
  Devotion then forwards a skill hit's settled amount even when it is zero;
  a normal swing forwards only positive damage. Raw costs
  and status ticks do not acquire an attack's map rate.

  Attack paths that render damage must call this before constructing their
  packet, then pass the returned hit information to `apply_unit_damage/6`.
  Preparation records completion and, on ground, the distinct equipment
  pre-status basis and settled status-return basis. This keeps visible damage
  and HP loss identical without consuming modifiers such as Lex Aeterna twice.

  A valid Devotion link delivers the devotee's settled damage to the Crusader
  with `redirected: true`, bypassing the Crusader's own statuses, map rates and
  return damage, and returns `0` for the devotee with `devotion_rerouted?: true`
  in the hit information, since the hit still connected. A stale link is torn down and
  the hit lands normally. Pre-renewal Gloria Domini (skill 367) and Gravitation
  Field (skill 484) are never rerouted: they strike the devotee directly.
  Reflected spells retain their metadata and settle at their actual recipient;
  unlike prepared weapon returns, they still receive equipment and status
  modifiers there. Reflected hits and self-damage are
  never rerouted.
  """
  @spec prepare_unit_damage(
          :player | :mob | :homunculus | :skill_unit,
          integer(),
          integer(),
          map(),
          integer() | Ref.t() | nil
        ) :: {integer(), map()}
  def prepare_unit_damage(
        :mob,
        target_id,
        damage,
        %{infinite_defense: _} = hit_info,
        attacker_id
      ),
      do: settle_infinite_defense(target_id, damage, hit_info, attacker_id)

  def prepare_unit_damage(target_type, target_id, damage, hit_info, attacker_id) do
    case ground_target(target_type, target_id, hit_info) do
      {:ok, target} ->
        prepare_ground_damage(target_type, target_id, damage, hit_info, attacker_id, target)

      :not_ground ->
        prepare_ordinary_damage(target_type, target_id, damage, hit_info, attacker_id)
    end
  end

  # A hit flagged `bypass_reductions` (pre-renewal Gravitation Field and Gloria
  # Domini) keeps its full amount: no magic reduction, no absorbing status.
  defp prepare_ordinary_damage(
         target_type,
         target_id,
         damage,
         %{bypass_reductions: true} = hit_info,
         attacker_id
       ) do
    case reroute_to_crusader(target_type, target_id, damage, hit_info, attacker_id) do
      {:rerouted, _delivery} -> {0, rerouted(hit_info, damage)}
      :not_rerouted -> {damage, Map.put(hit_info, :pre_delivery_prepared?, true)}
    end
  end

  defp prepare_ordinary_damage(target_type, target_id, damage, hit_info, attacker_id) do
    {settled, hit_info} =
      damage
      |> reduce_magic_damage(target_type, target_id, hit_info)
      |> absorb_unit_damage(target_type, target_id, hit_info, attacker_id)

    {settled, hit_info} = intercept_magic(target_type, target_id, settled, hit_info)
    settled = final_weapon_hit(settled, target_type, target_id, hit_info, attacker_id)

    case reroute_to_crusader(target_type, target_id, settled, hit_info, attacker_id) do
      {:rerouted, _delivery} -> {0, rerouted(hit_info, settled)}
      :not_rerouted -> {settled, Map.put(hit_info, :pre_delivery_prepared?, true)}
    end
  end

  # The devotee takes nothing, but the hit still connected: its additional
  # effects apply to the devotee as if the damage had landed. The forwarded
  # amount is kept for the counter stage of an immediate hit.
  defp rerouted(hit_info, forwarded) do
    hit_info
    |> Map.merge(%{
      pre_delivery_prepared?: true,
      devotion_rerouted?: true,
      devotion_damage: forwarded
    })
    |> drop_immediate_coma()
  end

  # An immediate hit never strikes the devotee at all, so only the Crusader
  # rolls coma; a delayed hit still lands on the devotee for nothing and keeps
  # the devotee's own decision.
  defp drop_immediate_coma(%{proc: %{immediate?: true}} = hit_info),
    do: Map.put(hit_info, :coma?, false)

  defp drop_immediate_coma(hit_info), do: hit_info

  defp prepare_ground_damage(
         target_type,
         target_id,
         damage,
         hit_info,
         attacker,
         target
       ) do
    {absorbed, prepared_hit} =
      absorb_ground_hit(target_type, target_id, damage, hit_info, attacker, target)

    {absorbed, prepared_hit} =
      if Map.has_key?(prepared_hit, :settlement_error),
        do: {absorbed, prepared_hit},
        else: intercept_magic(target_type, target_id, absorbed, prepared_hit)

    settled =
      absorbed
      |> apply_ground_rate(Rules.damage_rate(hit_info))
      |> final_weapon_hit(target_type, target_id, prepared_hit, attacker)

    finish_ground_hit(target_type, target_id, settled, prepared_hit, attacker)
  end

  defp absorb_ground_swing(target_type, target_id, swing, hit_info, attacker, target) do
    case Rules.validate_target(resolve_attacker(attacker), target, hit_info) do
      :ok ->
        rate = Rules.damage_rate(hit_info)

        {settled, hit_info} =
          absorb_swing(swing, target_type, target_id, hit_info, attacker, rate)

        {settled,
         Map.merge(hit_info, %{
           pre_delivery_prepared?: true,
           ground_damage_rate: rate,
           equipment_return_basis: swing.raw_total
         })}

      {:error, reason} ->
        {settle_components(swing, 0),
         Map.merge(hit_info, %{pre_delivery_prepared?: true, settlement_error: reason})}
    end
  end

  defp absorb_ground_hit(target_type, target_id, damage, hit_info, attacker, target) do
    case Rules.validate_target(resolve_attacker(attacker), target, hit_info) do
      :ok ->
        equipment_basis = reduce_magic_damage(damage, target_type, target_id, hit_info)

        {absorbed, hit_info} =
          absorb_unit_damage(equipment_basis, target_type, target_id, hit_info, attacker)

        {absorbed,
         Map.merge(hit_info, %{
           pre_delivery_prepared?: true,
           ground_damage_rate: Rules.damage_rate(hit_info),
           equipment_return_basis: equipment_basis
         })}

      {:error, reason} ->
        {0,
         Map.merge(hit_info, %{
           pre_delivery_prepared?: true,
           settlement_error: reason
         })}
    end
  end

  defp finish_ground_hit(target_type, target_id, settled, hit_info, attacker) do
    prepared_hit = Map.put(hit_info, :status_return_basis, settled)

    case reroute_to_crusader(target_type, target_id, settled, prepared_hit, attacker) do
      {:rerouted, _delivery} -> {0, rerouted(prepared_hit, settled)}
      :not_rerouted -> {settled, prepared_hit}
    end
  end

  defp intercept_magic(target_type, target_id, damage, hit_info) do
    case StatusInterpreter.intercept_magic(target_type, target_id, hit_info) do
      :miss -> {0, Map.put(hit_info, :magic_rod_miss?, true)}
      :continue -> {damage, hit_info}
    end
  end

  defp reduce_magic_damage(damage, target_type, target_id, hit_info) do
    if Map.get(hit_info, :dmg_type) == :magic and is_integer(Map.get(hit_info, :skill_id)),
      do: MagicDefense.reduce(damage, target_type, target_id),
      else: damage
  end

  @doc """
  Marks `hit_info` as an infinite-defense weapon contact when the calculated
  `result` is one (`DamageCalculator.damage_result/0` `:plant`).

  A marked hit on a monster skips the damage arithmetic statuses, the
  attacker's damage statuses, the siege map rate and every damage return: only
  the blocking statuses run, against a single point of damage, and any of them
  leaving nothing (Kyrie Eleison absorbing the point included) makes the whole
  contact deal nothing. Only Safety Wall, Pneuma and Basilica make it a block.
  A contact on the Emperium on siege ground must also be a valid siege attack.
  """
  @spec mark_infinite_defense(map(), map()) :: map()
  def mark_infinite_defense(hit_info, %{plant: plant}),
    do: Map.put(hit_info, :infinite_defense, plant)

  def mark_infinite_defense(hit_info, _result), do: hit_info

  defp settle_infinite_defense(target_id, damage, hit_info, attacker) do
    blocker_hit = Map.put(hit_info, :attacker, absorb_attacker(attacker))

    {damage, hit_info} =
      case StatusInterpreter.block_hit(:mob, target_id, blocker_hit) do
        {0, :block} -> {0, Map.put(hit_info, :blocked?, true)}
        {0, _stopped} -> {0, hit_info}
        {_point, :hit} -> {damage, hit_info}
      end

    {damage, hit_info} = emperium_siege_check(target_id, damage, hit_info, attacker)
    {damage, Map.put(hit_info, :pre_delivery_prepared?, true)}
  end

  defp emperium_siege_check(
         target_id,
         damage,
         %{infinite_defense: :emperium} = hit_info,
         attacker
       )
       when damage > 0 do
    with {:ok, target} <- ground_target(:mob, target_id, hit_info),
         {:error, reason} <- Rules.validate_target(resolve_attacker(attacker), target, hit_info) do
      {0, Map.put(hit_info, :settlement_error, reason)}
    else
      _valid_or_off_ground -> {damage, hit_info}
    end
  end

  defp emperium_siege_check(_target_id, damage, hit_info, _attacker), do: {damage, hit_info}

  @doc """
  Settles and delivers one already-calculated ordinary weapon swing.

  The target's damage statuses run once per hand, right hand first, and on
  siege ground each hand then receives its own map rate and minimum. Devotion
  then forwards the settled sum when it is above zero. The returned swing
  retains its raw total, its settled components sum to the one
  delivered HP mutation (zero for a devotee), and `stages` holds the hit's
  `EquipProcDispatch.hit_event/2` (nil for a swing that dealt nothing raw).
  """
  @spec apply_weapon_swing(
          :player | :mob | :homunculus | :skill_unit,
          pid(),
          integer(),
          HandedAttack.t(),
          map(),
          integer() | Ref.t() | nil
        ) :: {HandedAttack.t(), delivery_result()}
  def apply_weapon_swing(
        target_type,
        target_pid,
        target_id,
        %HandedAttack{raw_total: raw_total} = swing,
        hit_info,
        attacker
      )
      when raw_total > 0 do
    hit_info = Map.put(hit_info, :components, component_metadata(swing))
    settle_weapon_swing(target_type, target_pid, target_id, swing, hit_info, attacker)
  end

  def apply_weapon_swing(
        target_type,
        target_pid,
        target_id,
        %HandedAttack{} = swing,
        hit_info,
        attacker
      ) do
    {settle_components(swing, 0),
     swing_coma(target_type, target_pid, target_id, hit_info, attacker)}
  end

  # A swing that dealt nothing raw is a miss, which still lands its coma.
  defp swing_coma(target_type, target_pid, target_id, %{coma?: true} = hit_info, attacker) do
    coma_hit =
      hit_info
      |> Map.delete(:proc)
      |> Map.put(:pre_delivery_prepared?, true)

    apply_unit_damage(target_type, target_pid, target_id, 0, coma_hit, attacker)
  end

  defp swing_coma(_target_type, _target_pid, _target_id, _hit_info, _attacker), do: :ok

  @doc """
  Rolls and delivers the equipment coma of an attack that reaches `target`
  without dealing anything (a miss, a perfect dodge), sourced
  as `source`. The coma leaves the target at 1 HP and 1 SP and is active
  damage, but the miss schedules no attacked event and no equipment procs.
  Returns whether the coma triggered.
  """
  @spec apply_missed_coma(Combatant.t(), Combatant.t(), pid(), integer() | Ref.t()) ::
          boolean()
  def apply_missed_coma(attacker, %Combatant{unit_type: target_type} = target, target_pid, source)
      when target_type in [:player, :mob, :homunculus] do
    coma? = EquipComa.trigger?(attacker, target)

    if coma? do
      coma_hit = %{coma?: true, div: 1, pre_delivery_prepared?: true}
      apply_unit_damage(target_type, target_pid, target.unit_id, 0, coma_hit, source)
    end

    coma?
  end

  def apply_missed_coma(_attacker, _target, _target_pid, _source), do: false

  defp settle_weapon_swing(
         :mob,
         target_pid,
         target_id,
         swing,
         %{infinite_defense: _} = hit_info,
         attacker
       ) do
    {damage, prepared_hit} =
      settle_infinite_defense(target_id, swing.raw_total, hit_info, attacker)

    settled = settle_components(swing, damage)
    delivery = apply_unit_damage(:mob, target_pid, target_id, damage, prepared_hit, attacker)
    dispatch_swing_procs(delivery, prepared_hit, damage)
    {with_stages(settled, prepared_hit, damage), delivery}
  end

  defp settle_weapon_swing(target_type, target_pid, target_id, swing, hit_info, attacker) do
    case ground_target(target_type, target_id, hit_info) do
      {:ok, target} ->
        {settled, prepared_hit} =
          absorb_ground_swing(target_type, target_id, swing, hit_info, attacker, target)

        settled = final_weapon_swing(settled, target_type, target_id, prepared_hit, attacker)

        {damage, prepared_hit} =
          finish_ground_hit(
            target_type,
            target_id,
            component_total(settled),
            prepared_hit,
            attacker
          )

        delivery =
          apply_unit_damage(target_type, target_pid, target_id, damage, prepared_hit, attacker)

        dispatch_swing_procs(delivery, prepared_hit, damage)
        settled = if(damage == 0, do: settle_components(swing, 0), else: settled)
        {with_stages(settled, prepared_hit, damage), delivery}

      :not_ground ->
        apply_ordinary_swing(target_type, target_pid, target_id, swing, hit_info, attacker)
    end
  end

  defp apply_ordinary_swing(target_type, target_pid, target_id, swing, hit_info, attacker) do
    {absorbed, hit_info} = absorb_swing(swing, target_type, target_id, hit_info, attacker, nil)
    settled = final_weapon_swing(absorbed, target_type, target_id, hit_info, attacker)

    final_damage = component_total(settled)

    case reroute_to_crusader(target_type, target_id, final_damage, hit_info, attacker) do
      {:rerouted, delivery} ->
        rerouted_hit = rerouted(hit_info, final_damage)
        dispatch_swing_procs(delivery, rerouted_hit, 0)
        {with_stages(settle_components(swing, 0), rerouted_hit, 0), delivery}

      :not_rerouted ->
        prepared_hit = Map.put(hit_info, :pre_delivery_prepared?, true)

        delivery =
          apply_unit_damage(
            target_type,
            target_pid,
            target_id,
            final_damage,
            prepared_hit,
            attacker
          )

        dispatch_swing_procs(delivery, prepared_hit, final_damage)
        {with_stages(settled, prepared_hit, final_damage), delivery}
    end
  end

  # The settled swing carries its hit's stages for the attack path's on-hit effects.
  defp with_stages(swing, hit_info, damage),
    do: %{swing | stages: EquipProcDispatch.hit_event(hit_info, damage)}

  # A normal swing always resolves in its attacker's own session, so the
  # attacker's procs sent here queue behind the rest of the swing's effects,
  # exactly as if the attack path dispatched them last.
  defp dispatch_swing_procs(delivery, hit_info, damage),
    do: EquipProcDispatch.dispatch_delivered(delivery, hit_info, damage)

  @doc """
  Applies damage to a living unit's session.

  Callers without a packet may pass an ordinary hit and the modifier hook runs
  here. Packet-producing paths pass hit information returned by
  `prepare_unit_damage/5`, which prevents applying the same modifier twice.
  """
  @type local_effect :: {:homunculus, tuple()}
  @type delivery_result :: :ok | {:local_effects, [local_effect()]} | {:error, atom()}

  @spec apply_unit_damage(
          :player | :mob | :homunculus | :skill_unit,
          pid(),
          integer(),
          integer(),
          map(),
          integer() | Ref.t() | nil
        ) :: delivery_result()
  def apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker) do
    {final_damage, hit_info} =
      prepare_delivery(target_type, target_id, damage, hit_info, attacker)

    hit_info =
      hit_info
      |> attach_proc_event(final_damage)
      |> capture_damage_broken(target_type, target_id)
      |> stamp_walk_delay(final_damage, target_type, target_id)

    delivery =
      deliver_unit_damage(target_type, target_pid, target_id, final_damage, hit_info, attacker)

    post_delivery =
      after_damage_taken(delivery, target_type, target_id, final_damage, hit_info, attacker)

    merge_local_effects(delivery, post_delivery)
  end

  @doc """
  Hands a delivery's same-session effects to the owning session as the ordinary
  messages a different owner would have received, for attack paths that cannot
  return them to their caller. Returns `delivery` unchanged.
  """
  @spec forward_local_effects(delivery_result()) :: delivery_result()
  def forward_local_effects({:local_effects, effects} = delivery) do
    Enum.each(effects, &GenServer.cast(self(), &1))
    delivery
  end

  def forward_local_effects(delivery), do: delivery

  # The settled hit's equipment-proc event rides to the recipient's own handler
  # as `:proc_event`; the attack path dispatches the attacker's side itself.
  defp attach_proc_event(%{settlement_error: _} = hit_info, _damage),
    do: Map.delete(hit_info, :proc)

  defp attach_proc_event(%{proc: _} = hit_info, damage) do
    event = EquipProcDispatch.hit_event(hit_info, damage)
    hit_info |> Map.delete(:proc) |> Map.put(:proc_event, event)
  end

  defp attach_proc_event(hit_info, _damage), do: hit_info

  # The recipient's damage-broken statuses as the hit is dealt, before the attack
  # path runs its additional effects; see `StatusInterpreter.damage_broken_snapshot/2`.
  defp capture_damage_broken(hit_info, target_type, target_id)
       when target_type in [:player, :mob, :homunculus],
       do:
         Map.put_new_lazy(hit_info, :damage_broken, fn ->
           StatusInterpreter.damage_broken_snapshot(target_type, target_id)
         end)

  defp capture_damage_broken(hit_info, _target_type, _target_id), do: hit_info

  # Whether the hit asks the target's own handler to stop it walking, decided
  # on the settled damage before its HP clamps it, and on the target's endure
  # time as the hit is dealt, before the attack's own effects may set it.
  defp stamp_walk_delay(hit_info, damage, target_type, target_id) do
    walk_delay? =
      DamageShared.walk_delay?(hit_info, damage) and
        not Endure.tick_active?(target_type, target_id)

    Map.put(hit_info, :walk_delay?, walk_delay?)
  end

  @doc "Builds aggregate-local Homunculus damage without sending to its owner process."
  @spec local_damage_effect(Ref.t(), integer(), map(), Ref.t() | nil) :: tuple()
  def local_damage_effect({:homunculus, world_gid} = target_ref, damage, hit_info, attacker)
      when is_integer(damage) and damage >= 0 do
    if Ref.valid?(target_ref) and (is_nil(attacker) or Ref.valid?(attacker)) do
      {final_damage, hit_info} =
        prepare_delivery(:homunculus, world_gid, damage, hit_info, attacker)

      hit_info =
        hit_info
        |> capture_damage_broken(:homunculus, world_gid)
        |> stamp_walk_delay(final_damage, :homunculus, world_gid)

      {:homunculus, {:apply_damage, world_gid, final_damage, hit_info, attacker}}
    else
      raise ArgumentError, "invalid typed Homunculus damage effect"
    end
  end

  @doc "Builds aggregate-local Homunculus healing without sending to its owner process."
  @spec local_heal_effect(Ref.t(), heal_amount(), Ref.t() | nil) :: tuple()
  def local_heal_effect({:homunculus, _world_gid} = target_ref, amount, source) do
    if Ref.valid?(target_ref) and (is_nil(source) or Ref.valid?(source)) do
      {:homunculus, {:apply_heal, elem(target_ref, 1), amount, source}}
    else
      raise ArgumentError, "invalid typed Homunculus heal effect"
    end
  end

  @doc """
  Applies damage to a targetable skill-unit cell (e.g. Ice Wall).

  Both `{:ok, cell}` and `{:destroyed, cell}` count as a delivered hit.
  """
  @spec damage_skill_unit(pid(), integer(), integer(), {atom(), integer()} | nil) ::
          :ok | {:error, atom()}
  def damage_skill_unit(manager_pid, target_id, damage, source) do
    case SkillUnitManager.damage_targetable_cell(manager_pid, target_id, damage, source) do
      {:ok, _cell} -> :ok
      {:destroyed, _cell} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Restores SP to a player through that player's session.
  """
  @spec apply_sp_heal(:player, integer(), non_neg_integer()) :: :ok
  def apply_sp_heal(:player, unit_id, amount) do
    PubSub.broadcast(Aesir.PubSub, "player:#{unit_id}", {:combat, {:restore_sp, amount}})
  end

  @doc "Applies nonlethal percentage HP/SP vanish through the target's owning session."
  @spec apply_vanish(
          :player | :mob | :homunculus | :skill_unit,
          pid(),
          non_neg_integer(),
          non_neg_integer(),
          Ref.t()
        ) :: :ok
  def apply_vanish(:player, target_pid, hp_percent, sp_percent, source) do
    PlayerSession.apply_vanish(target_pid, hp_percent, sp_percent, source)
  end

  def apply_vanish(:mob, target_pid, hp_percent, _sp_percent, source) do
    MobSession.apply_vanish(target_pid, hp_percent, source)
  end

  def apply_vanish(_target_type, _target_pid, _hp_percent, _sp_percent, _source), do: :ok

  @typedoc """
  A heal as the recipient takes it: an integer is a final amount a unit in
  Frenzy refuses, `{:passive, amount}` one Frenzy does not stop (an HP drain),
  and `{:potion, hp, sp}` a thrown potion's final HP and SP, whose HP Frenzy
  refuses.
  """
  @type heal_amount ::
          non_neg_integer()
          | {:passive, non_neg_integer()}
          | {:potion, non_neg_integer(), non_neg_integer()}

  @doc """
  Whether a unit refuses an ordinary heal: one in Frenzy takes no HP from it.
  """
  @spec heal_refused?(:player | :mob | :homunculus, integer()) :: boolean()
  def heal_refused?(unit_type, unit_id),
    do: StatusStorage.has_status?(unit_type, unit_id, :sc_berserk)

  @doc """
  Heals a living unit with an amount that is already final; the recipient adds
  no rate of its own (see `heal_amount/0`).

  For `:player` this broadcasts to the player's PubSub topic; an offline
  player (no subscriber) is a silent no-op. For `:mob` this resolves the
  target's session pid via `UnitRegistry` and calls `MobSession.heal/2`; a
  target that no longer exists is a silent no-op.
  """

  @spec apply_heal(
          :player | :mob | :homunculus,
          integer(),
          heal_amount(),
          integer() | Ref.t() | nil
        ) :: :ok
  def apply_heal(:player, unit_id, amount, source_id) do
    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{unit_id}",
      {:combat, {:apply_heal, amount, source_id}}
    )
  end

  def apply_heal(:mob, unit_id, amount, _source_id) when is_integer(amount) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} -> MobSession.heal(pid, amount)
      {:error, :not_found} -> :ok
    end
  end

  def apply_heal(:homunculus, unit_id, amount, source) do
    case UnitRegistry.get_unit(:homunculus, unit_id) do
      {:ok, {_module, _state, pid}} when is_pid(pid) ->
        ensure_external_owner!(pid)
        GenServer.cast(pid, {:homunculus, {:apply_heal, unit_id, amount, typed_source(source)}})

      {:error, :not_found} ->
        :ok
    end
  end

  @doc """
  Resolves the session module owning units of the given type.
  """
  @spec unit_session(:player | :mob) :: module()
  def unit_session(:mob), do: MobSession
  def unit_session(:player), do: PlayerSession

  @doc """
  Broadcasts a combat packet to players near the target. Works for both
  combatant structs and map-based target stats (both carry position/map_name).
  """
  @spec broadcast_nearby(map(), struct()) :: :ok
  def broadcast_nearby(target, packet) do
    {x, y} = target.position
    packet = DamageDisplay.finalize(packet, Map.get(target, :unit_type))
    Broadcast.to_in_range(target.map_name, x, y, Config.view_range(), packet)
  end

  # Redirects damage aimed at a devoted player to its Crusader. Runs entirely
  # against StatusStorage and the spatial index (no session calls), so the
  # decision is safe inside the attacker's own process. A skill forwards even
  # zero damage; a normal swing needs positive damage. Only non-reflected,
  # non-redirected damage from a distinct attacker is eligible;
  # self-damage (Grand Cross) carries `attacker_id == target_id` and is skipped.
  defp reroute_to_crusader(:player, target_id, damage, hit_info, attacker)
       when not is_nil(attacker) do
    skill? = is_integer(hit_info[:skill_id]) and hit_info[:skill_id] > 0

    if (damage > 0 or skill?) and attacker_id(attacker) != target_id and reroutable?(hit_info) do
      dispatch_reroute(target_id, damage, hit_info, attacker)
    else
      :not_rerouted
    end
  end

  defp reroute_to_crusader(_target_type, _target_id, _damage, _hit_info, _attacker_id),
    do: :not_rerouted

  defp dispatch_reroute(target_id, damage, hit_info, attacker_id) do
    case Devotion.redirect_target(target_id) do
      {:ok, crusader_id} ->
        {:rerouted, redirect_damage(crusader_id, damage, hit_info, attacker_id)}

      :stale ->
        Devotion.teardown(target_id)
        :not_rerouted

      :none ->
        :not_rerouted
    end
  end

  defp reroutable?(hit_info) do
    not Map.get(hit_info, :reflected, false) and
      not Map.get(hit_info, :redirected, false) and
      Map.get(hit_info, :skill_id) not in devotion_bypass_skill_ids()
  end

  defp devotion_bypass_skill_ids do
    case GameMode.mode() do
      :pre_renewal -> [367, 484]
      :renewal -> []
    end
  end

  # Applies the full computed damage to the Crusader through the async apply
  # path. `redirected: true` exempts it from the reflect hook and re-redirect;
  # `pre_delivery_prepared?: true` skips the Crusader's own absorb. Its
  # damage-taken reductions and before-hooks are never on this path to begin
  # with. A Crusader that vanished between the pull-check and here is a rare
  # race: the hit is dropped (the devotee already takes zero) and the tick
  # self-heals the link.
  defp redirect_damage(crusader_id, damage, hit_info, attacker_id) do
    case TargetResolver.resolve(:player, crusader_id) do
      {:ok, crusader_pid, crusader_state, :player} ->
        redirected_info =
          hit_info
          |> Map.drop([:proc, :proc_event])
          |> Map.put(:redirected, true)
          |> Map.put(:pre_delivery_prepared?, true)
          |> Map.put(:coma?, fresh_coma?(attacker_id, :player, crusader_state))

        apply_unit_damage(
          :player,
          crusader_pid,
          crusader_id,
          damage,
          redirected_info,
          attacker_id
        )

      {:error, _reason} ->
        :ok
    end
  end

  defp ground_target(target_type, target_id, hit_info) do
    with true <- attack_hit?(hit_info),
         {:ok, {module, state, _pid}} <- target_snapshot(target_type, target_id),
         %{map_name: map_name} when is_binary(map_name) <- state,
         true <- Rules.ground?(map_name) do
      {:ok, module.to_combatant(state)}
    else
      _ -> :not_ground
    end
  end

  defp target_snapshot(:skill_unit, target_id) do
    with {:ok, pid, state, :skill_unit} <- TargetResolver.resolve(:skill_unit, target_id) do
      {:ok, {state.__struct__, state, pid}}
    end
  end

  defp target_snapshot(target_type, target_id), do: UnitRegistry.get_unit(target_type, target_id)

  defp attack_hit?(%{skill_id: skill_id}) when is_integer(skill_id), do: true
  defp attack_hit?(%{basic_attack?: true}), do: true

  defp attack_hit?(%{dmg_type: :physical, is_short: is_short}) when is_boolean(is_short),
    do: true

  defp attack_hit?(_hit_info), do: false

  defp resolve_attacker(nil), do: %{}

  defp resolve_attacker(attacker) do
    {type, id} = typed_attacker(attacker)

    case UnitRegistry.get_unit(type, id) do
      {:ok, {module, state, _pid}} -> module.to_combatant(state)
      {:error, :not_found} -> %{}
    end
  end

  defp apply_ground_rate(damage, rate) when damage > 0,
    do: max(div(damage * rate, 100), 1)

  defp apply_ground_rate(damage, _rate), do: damage

  # Status absorb hooks see the hit's source as `hit_info.attacker` (a typed
  # unit ref, or nil when unknown), e.g. Basilica letting only bosses through.
  # A hit a blocking status stopped is marked `blocked?: true`.
  defp absorb_unit_damage(damage, :skill_unit, _target_id, hit_info, _attacker),
    do: {damage, hit_info}

  defp absorb_unit_damage(damage, target_type, target_id, hit_info, attacker) when damage > 0 do
    absorb_hit = Map.put(hit_info, :attacker, absorb_attacker(attacker))

    case StatusInterpreter.absorb_hit(target_type, target_id, damage, absorb_hit) do
      {absorbed, :block} -> {absorbed, Map.put(hit_info, :blocked?, true)}
      {absorbed, _connected_or_miss} -> {absorbed, hit_info}
    end
  end

  defp absorb_unit_damage(damage, _target_type, _target_id, hit_info, _attacker),
    do: {damage, hit_info}

  # A swing runs the target's damage statuses once per hand, right hand first,
  # so each hand spends its own status charges and rolls its own blockers; a
  # siege `rate` then applies to each hand. When both hands dealt raw damage
  # and the right still deals more than 1, a stopped left hand deals 1. A
  # swing left with nothing takes the class of the last hand a blocker
  # classified: a Guard on the left makes it a miss after a Safety Wall on the
  # right, a Safety Wall on the left a block after a Guard on the right.
  defp absorb_swing(swing, target_type, target_id, hit_info, attacker, rate) do
    absorb_hit = Map.merge(hit_info, %{attacker: absorb_attacker(attacker), swing: make_ref()})
    {right, right_class} = absorb_hand(swing.primary.damage, target_type, target_id, absorb_hit)

    {left, left_class} =
      absorb_hand(secondary_damage(swing), target_type, target_id, absorb_hit)

    settled =
      %{swing | primary: %{swing.primary | damage: right}}
      |> Map.update!(:secondary, &settle_secondary(&1, left))
      |> rate_components(rate)
      |> keep_left_hand(swing)

    class = if left_class == :hit, do: right_class, else: left_class

    if component_total(settled) == 0 and class == :block,
      do: {settled, Map.put(hit_info, :blocked?, true)},
      else: {settled, hit_info}
  end

  defp absorb_hand(damage, target_type, target_id, hit)
       when damage > 0 and target_type != :skill_unit,
       do: StatusInterpreter.absorb_hit(target_type, target_id, damage, hit)

  defp absorb_hand(damage, _target_type, _target_id, _hit), do: {damage, :hit}

  defp secondary_damage(%HandedAttack{secondary: nil}), do: 0
  defp secondary_damage(%HandedAttack{secondary: secondary}), do: secondary.damage

  defp keep_left_hand(
         %{primary: %{damage: right}, secondary: %{damage: left} = secondary} = settled,
         %HandedAttack{primary: %{damage: raw_right}, secondary: %{damage: raw_left}}
       )
       when raw_right > 0 and raw_left > 0 and right > 1 and left < 1,
       do: %{settled | secondary: %{secondary | damage: 1}}

  defp keep_left_hand(settled, _swing), do: settled

  # The holder's final weapon stage (Counter Instinct) over a weapon hit's
  # settled damage, after the siege map rate and before Devotion. A cut hit's
  # owed part is dealt back to the attacker at once.
  defp final_weapon_hit(damage, target_type, target_id, hit_info, attacker)
       when damage > 0 and target_type in [:player, :mob, :homunculus] do
    with {_type, _id} = attacker_ref <- absorb_attacker(attacker),
         true <- weapon_attack?(hit_info) do
      stage_hit = Map.put(hit_info, :attacker, attacker_ref)

      {settled, owed} =
        StatusInterpreter.final_weapon_hit(target_type, target_id, damage, stage_hit)

      counter_attacker(owed, attacker_ref, {target_type, target_id}, hit_info)
      settled
    else
      _not_staged -> damage
    end
  end

  defp final_weapon_hit(damage, _target_type, _target_id, _hit_info, _attacker), do: damage

  # A dual-wield swing's stage sees only its right-hand part.
  defp final_weapon_swing(swing, target_type, target_id, hit_info, attacker) do
    primary =
      final_weapon_hit(swing.primary.damage, target_type, target_id, hit_info, attacker)

    %{swing | primary: %{swing.primary | damage: primary}}
  end

  defp weapon_attack?(hit_info) do
    Map.get(hit_info, :dmg_type) == :physical and
      not Map.get(hit_info, :reflected, false) and
      not Map.get(hit_info, :redirected, false) and
      not Map.get(hit_info, :bypass_reductions, false) and
      not Map.get(hit_info, :status_tick?, false) and
      not Map.has_key?(hit_info, :infinite_defense)
  end

  # The counter is a fixed hit the holder deals its attacker as the weapon hit
  # is calculated: shown on the attacker, then dealt without the attacker's
  # damage statuses, map rate or returned-damage reduction, with the holder's
  # own coma roll.
  defp counter_attacker(0, _attacker, _holder, _hit_info), do: :ok

  defp counter_attacker(owed, {_type, attacker_id} = attacker, {_, holder_id} = holder, hit_info) do
    case TargetResolver.resolve(attacker) do
      {:ok, pid, state, type} ->
        state
        |> state.__struct__.to_combatant()
        |> broadcast_nearby(
          PacketFactory.build_counter_damage_packet(holder_id, attacker_id, owed)
        )

        counter_hit = %{
          reflected: true,
          skill_id: @counter_skill_id,
          dmg_type: :misc,
          div: Map.get(hit_info, :div, 1),
          pre_delivery_prepared?: true,
          coma?: reflected_coma?(holder, type, state)
        }

        type
        |> apply_unit_damage(pid, attacker_id, owed, counter_hit, holder)
        |> forward_local_effects()

      {:error, _reason} ->
        :ok
    end
  end

  defp absorb_attacker(attacker_id) when is_integer(attacker_id), do: {:player, attacker_id}

  defp absorb_attacker({_unit_type, _unit_id} = ref),
    do: if(Ref.valid?(ref), do: ref, else: nil)

  defp absorb_attacker(_attacker), do: nil

  defp component_metadata(%HandedAttack{} = swing) do
    primary = {:primary, swing.primary.damage, swing.primary_element}

    case swing.secondary do
      nil -> [primary]
      secondary -> [primary, {:secondary, secondary.damage, swing.primary_element}]
    end
  end

  defp settle_components(%HandedAttack{raw_total: raw_total} = swing, final_damage)
       when raw_total > 0 do
    secondary_damage =
      case swing.secondary do
        nil -> 0
        secondary -> div(final_damage * secondary.damage, raw_total)
      end

    %{
      swing
      | primary: %{swing.primary | damage: final_damage - secondary_damage},
        secondary: settle_secondary(swing.secondary, secondary_damage)
    }
  end

  defp settle_components(%HandedAttack{} = swing, _final_damage) do
    %{
      swing
      | primary: %{swing.primary | damage: 0},
        secondary: settle_secondary(swing.secondary, 0)
    }
  end

  defp rate_components(swing, nil), do: swing

  defp rate_components(swing, rate) do
    %{
      swing
      | primary: rate_component(swing.primary, rate),
        secondary: rate_component(swing.secondary, rate)
    }
  end

  defp rate_component(nil, _rate), do: nil

  defp rate_component(component, rate),
    do: %{component | damage: apply_ground_rate(component.damage, rate)}

  defp component_total(%{primary: primary, secondary: nil}), do: primary.damage
  defp component_total(swing), do: swing.primary.damage + swing.secondary.damage

  defp settle_secondary(nil, _damage), do: nil
  defp settle_secondary(secondary, damage), do: %{secondary | damage: damage}

  # Runs every victim post-delivery hook once for positive damage. Individual
  # statuses own their hit-shape filters; reflected damage remains asynchronous.
  defp after_damage_taken(
         {:error, _reason},
         _target_type,
         _target_id,
         _damage,
         _hit_info,
         _attacker
       ),
       do: :ok

  defp after_damage_taken(
         _delivery,
         target_type,
         target_id,
         _damage,
         %{ground_damage_rate: rate} = hit_info,
         attacker
       ) do
    status_hit =
      hit_info
      |> Map.put(:damage, hit_info.status_return_basis)
      |> Map.put(:attacker, typed_attacker(attacker))
      |> mark_trap_return(target_type, target_id)

    status_return =
      if status_hit.damage > 0,
        do: StatusInterpreter.after_damage_taken(target_type, target_id, status_hit),
        else: 0

    equipment_return =
      equipment_damage_return(
        target_type,
        target_id,
        Map.put(status_hit, :damage, hit_info.equipment_return_basis)
      )

    returns = [
      apply_ground_rate(status_return, rate),
      apply_ground_rate(equipment_return, rate)
    ]

    apply_reflected_damage(returns, reflection_target(attacker), {target_type, target_id}, %{
      reflected: true,
      div: 1,
      pre_delivery_prepared?: true
    })
  end

  defp after_damage_taken(_delivery, target_type, target_id, damage, hit_info, attacker)
       when damage > 0 do
    delivered_hit =
      hit_info
      |> Map.put(:damage, damage)
      |> Map.put(:attacker, typed_attacker(attacker))
      |> mark_trap_return(target_type, target_id)

    status_reflect = StatusInterpreter.after_damage_taken(target_type, target_id, delivered_hit)
    equip_reflect = equipment_damage_return(target_type, target_id, delivered_hit)

    apply_reflected_damage(
      [status_reflect, equip_reflect],
      reflection_target(attacker),
      {target_type, target_id}
    )
  end

  defp after_damage_taken(_delivery, _target_type, _target_id, _damage, _hit_info, _attacker),
    do: :ok

  # Returned damage lands on the original attacker as a one-division battle
  # hit whose attacker is the unit that returned it.
  defp apply_reflected_damage(
         amount,
         attacker,
         reflector,
         hit_info \\ %{reflected: true, div: 1}
       )

  defp apply_reflected_damage(returns, attacker_id, reflector, hit_info)
       when is_integer(attacker_id) do
    if returnable?(returns) do
      case TargetResolver.resolve(attacker_id) do
        {:ok, attacker_pid, attacker_state, attacker_type} ->
          deliver_returned_damage(
            returns,
            attacker_state,
            {attacker_type, attacker_pid, attacker_id},
            reflector,
            hit_info
          )

        {:error, _reason} ->
          :ok
      end
    else
      :ok
    end
  end

  defp apply_reflected_damage(
         returns,
         {attacker_type, attacker_id} = attacker_ref,
         reflector,
         hit_info
       ) do
    if returnable?(returns) do
      case TargetResolver.resolve(attacker_ref) do
        {:ok, attacker_pid, attacker_state, ^attacker_type} ->
          deliver_returned_damage(
            returns,
            attacker_state,
            {attacker_type, attacker_pid, attacker_id},
            reflector,
            hit_info
          )

        {:error, _reason} ->
          :ok
      end
    else
      :ok
    end
  end

  defp apply_reflected_damage(_returns, _attacker, _reflector, _hit_info), do: :ok

  # Nothing returns to a hit whose returns are all empty, as a zero return
  # never needs the unit it would have gone back to.
  defp returnable?(returns), do: Enum.any?(returns, &(&1 > 0))

  # The unit the damage is returned to cuts each return by its own
  # `bReduceDamageReturn` percent (`battle_calc_return_damage`); only players
  # carry equipment, and the two returns are reduced separately.
  defp deliver_returned_damage(
         returns,
         attacker_state,
         {attacker_type, pid, id},
         reflector,
         hit_info
       ) do
    reduction = returned_damage_rate(attacker_state)

    case returns |> Enum.map(&reduce_return(&1, reduction)) |> Enum.sum() do
      amount when amount > 0 ->
        apply_unit_damage(
          attacker_type,
          pid,
          id,
          amount,
          Map.put(hit_info, :coma?, reflected_coma?(reflector, attacker_type, attacker_state)),
          reflector
        )

      _nothing ->
        :ok
    end
  end

  defp returned_damage_rate(%PlayerState{stats: %{modifiers: %{equipment: equip}}}),
    do: Map.get(equip, :reduce_damage_return, 0)

  defp returned_damage_rate(_attacker_state), do: 0

  # A forwarded or returned hit is its own battle hit: its source rolls its own
  # coma against its new victim. Only a player source carries coma bonuses,
  # and only a player, mob or homunculus victim takes a coma.
  defp fresh_coma?(source, victim_type, victim_state),
    do: owner_coma?(resolve_attacker(source), victim_type, victim_state)

  # A return whose reflector is gone by the time it lands is dealt by the
  # victim to itself: a player victim rolls its own coma bonuses.
  defp reflected_coma?(reflector, victim_type, victim_state) do
    case resolve_attacker(reflector) do
      %Combatant{} = owner ->
        owner_coma?(owner, victim_type, victim_state)

      _gone when victim_type == :player ->
        victim = victim_state.__struct__.to_combatant(victim_state)
        EquipComa.trigger?(victim, victim)

      _gone ->
        false
    end
  end

  defp owner_coma?(%Combatant{unit_type: :player} = owner, victim_type, victim_state)
       when victim_type in [:player, :mob, :homunculus],
       do: EquipComa.trigger?(owner, victim_state.__struct__.to_combatant(victim_state))

  defp owner_coma?(_owner, _victim_type, _victim_state), do: false

  @doc """
  Takes the returned unit's `bReduceDamageReturn` percent (at most 100) off one
  returned amount, which then keeps at least 1. The equipment return and the
  status return are separate returns, each reduced and floored on its own.
  """
  @spec reduce_return(integer(), integer()) :: integer()
  def reduce_return(amount, _rate) when amount <= 0, do: amount
  def reduce_return(amount, rate), do: max(amount - div(amount * min(100, rate), 100), 1)

  # Equipment-granted melee damage reflect (`bShortWeaponDamageReturn`): the
  # defender's gear returns a percent of the supplied basis to the attacker on
  # a short-range physical hit, or on a short-range trap hit (`trap_return?`,
  # which then keeps Reflect Shield out). Shares Reflect Shield's hit-shape
  # filter, so an already-reflected, redirected, ranged, or magic hit reflects
  # nothing. Only players carry equipment, so mobs and other unit types never
  # reflect here.
  defp equipment_damage_return(:player, target_id, hit_info) do
    if melee_reflectable?(hit_info) or Map.get(hit_info, :trap_return?, false) do
      div(hit_info.damage * short_weapon_return_percent(target_id), 100)
    else
      0
    end
  end

  defp equipment_damage_return(_target_type, _target_id, _hit_info), do: 0

  defp short_weapon_return_percent(target_id) do
    case UnitRegistry.get_unit_info(:player, target_id) do
      {:ok, %{equip_modifiers: equip}} -> max(Map.get(equip, :short_weapon_damage_return, 0), 0)
      _ -> 0
    end
  end

  # A short trap hit on a player whose equipment returns melee damage is
  # returned by that equipment alone; any other short misc hit is left to
  # Reflect Shield, and a long one returns nothing.
  # Only the original target returns: a redirected (Devotion) or already
  # reflected hit returns nothing.
  defp mark_trap_return(%{dmg_type: :misc} = hit_info, :player, target_id) do
    trap_return? =
      Map.get(hit_info, :is_short, false) == true and
        not Map.get(hit_info, :reflected, false) and
        not Map.get(hit_info, :redirected, false) and
        trap_skill?(hit_info.skill_id) and
        short_weapon_return_percent(target_id) > 0

    Map.put(hit_info, :trap_return?, trap_return?)
  end

  defp mark_trap_return(hit_info, _target_type, _target_id), do: hit_info

  defp trap_skill?(skill_id), do: match?({:ok, %{is_trap: true}}, Catalog.by_id(skill_id))

  defp melee_reflectable?(hit_info) do
    not Map.has_key?(hit_info, :infinite_defense) and
      Map.get(hit_info, :dmg_type) == :physical and
      Map.get(hit_info, :is_short, false) == true and
      not Map.get(hit_info, :reflected, false) and
      not Map.get(hit_info, :redirected, false)
  end

  defp prepare_delivery(
         _type,
         _id,
         damage,
         %{pre_delivery_prepared?: true} = hit_info,
         _attacker
       ),
       do: {damage, hit_info}

  defp prepare_delivery(target_type, target_id, damage, hit_info, attacker) do
    case ground_target(target_type, target_id, hit_info) do
      {:ok, target} ->
        prepare_ground_damage(target_type, target_id, damage, hit_info, attacker, target)

      :not_ground ->
        {absorbed, hit_info} =
          absorb_unit_damage(damage, target_type, target_id, hit_info, attacker)

        settled = final_weapon_hit(absorbed, target_type, target_id, hit_info, attacker)
        {settled, Map.put(hit_info, :pre_delivery_prepared?, true)}
    end
  end

  defp deliver_unit_damage(
         _target_type,
         _target_pid,
         _target_id,
         _damage,
         %{settlement_error: reason},
         _attacker
       ),
       do: {:error, reason}

  defp deliver_unit_damage(
         target_type,
         target_pid,
         target_id,
         damage,
         %{coma?: true} = hit_info,
         attacker
       )
       when target_type in [:player, :mob, :homunculus] do
    deliver_coma(
      target_type,
      target_pid,
      target_id,
      Map.put(hit_info, :hit_damage, damage),
      attacker
    )
  end

  defp deliver_unit_damage(:homunculus, target_pid, target_id, damage, hit_info, attacker)
       when target_pid == self() do
    effect =
      local_damage_effect(
        {:homunculus, target_id},
        damage,
        hit_info,
        typed_attacker(attacker)
      )

    {:local_effects, [effect]}
  end

  defp deliver_unit_damage(:homunculus, target_pid, target_id, damage, hit_info, attacker) do
    GenServer.cast(
      target_pid,
      {:homunculus, {:apply_damage, target_id, damage, hit_info, typed_attacker(attacker)}}
    )
  end

  defp deliver_unit_damage(:skill_unit, target_pid, target_id, damage, _hit_info, attacker) do
    damage_skill_unit(target_pid, target_id, damage, typed_source(attacker))
  end

  defp deliver_unit_damage(:mob, target_pid, _target_id, damage, hit_info, attacker) do
    mob_attacker = mob_attacker(attacker)

    note_kill_attack_type(
      target_pid,
      mob_attacker,
      kill_attack_type(hit_info),
      Map.get(hit_info, :skill_id)
    )

    MobSession.apply_damage(target_pid, damage, mob_attacker, hit_info)
  end

  defp deliver_unit_damage(
         :player,
         target_pid,
         _target_id,
         damage,
         %{skill_id: skill_id, skill_level: skill_level} = hit_info,
         attacker
       )
       when is_integer(skill_id) and is_integer(skill_level) do
    PlayerSession.apply_damage(target_pid, damage, typed_attacker(attacker), hit_info)
    PlayerSession.record_skill_hit(target_pid, skill_id, skill_level)
  end

  defp deliver_unit_damage(:player, target_pid, _target_id, damage, hit_info, attacker) do
    PlayerSession.apply_damage(target_pid, damage, typed_attacker(attacker), hit_info)
  end

  defp deliver_coma(
         :player,
         target_pid,
         _target_id,
         %{skill_id: skill_id, skill_level: skill_level} = hit_info,
         attacker
       )
       when is_integer(skill_id) and is_integer(skill_level) do
    PlayerSession.apply_coma(target_pid, typed_attacker(attacker), hit_info)
    PlayerSession.record_skill_hit(target_pid, skill_id, skill_level)
  end

  defp deliver_coma(:player, target_pid, _target_id, hit_info, attacker) do
    PlayerSession.apply_coma(target_pid, typed_attacker(attacker), hit_info)
  end

  defp deliver_coma(:mob, target_pid, _target_id, hit_info, attacker) do
    MobSession.apply_coma(target_pid, typed_attacker(attacker), hit_info)
  end

  defp deliver_coma(:homunculus, target_pid, target_id, hit_info, attacker)
       when target_pid == self() do
    {:local_effects, [homunculus_coma(target_id, hit_info, attacker)]}
  end

  defp deliver_coma(:homunculus, target_pid, target_id, hit_info, attacker) do
    GenServer.cast(target_pid, homunculus_coma(target_id, hit_info, attacker))
  end

  defp homunculus_coma(target_id, hit_info, attacker) do
    metadata = Map.take(hit_info, [:damage_broken, :walk_delay?, :hit_damage])
    {:homunculus, {:apply_coma, target_id, typed_attacker(attacker), metadata}}
  end

  # Classifies a hit for the on-kill HP/SP gain equipment bonuses: a physical
  # hit is melee within melee range, ranged otherwise; magic is magic; every
  # other shape (misc skills, reflected damage) grants nothing.
  defp kill_attack_type(%{dmg_type: :magic}), do: :magic
  defp kill_attack_type(%{dmg_type: :physical, is_short: true}), do: :melee
  defp kill_attack_type(%{dmg_type: :physical}), do: :ranged
  defp kill_attack_type(_hit_info), do: :other

  # Records the classification on the target just before the paired damage, so
  # a lethal blow grants the killer's on-kill gain. Only gain-eligible attacks
  # from a real attacker are worth a message.
  defp note_kill_attack_type(_target_pid, nil, _bf, _skill_id), do: :ok
  defp note_kill_attack_type(_target_pid, _attacker, :other, _skill_id), do: :ok

  defp note_kill_attack_type(target_pid, attacker, bf, skill_id) do
    MobSession.note_hit_type(target_pid, attacker, bf, skill_id)
  end

  defp merge_local_effects({:error, _reason} = error, :ok), do: error
  defp merge_local_effects(:ok, :ok), do: :ok
  defp merge_local_effects({:local_effects, effects}, :ok), do: {:local_effects, effects}
  defp merge_local_effects(:ok, {:local_effects, effects}), do: {:local_effects, effects}

  defp merge_local_effects({:local_effects, first}, {:local_effects, second}),
    do: {:local_effects, first ++ second}

  defp ensure_external_owner!(pid) when pid == self() do
    raise ArgumentError,
          "aggregate-local Homunculus healing must use local_heal_effect/3"
  end

  defp ensure_external_owner!(_pid), do: :ok

  defp reflection_target(nil), do: nil
  defp reflection_target(attacker_id) when is_integer(attacker_id), do: attacker_id
  defp reflection_target(attacker_ref), do: typed_attacker(attacker_ref)

  defp typed_attacker(nil), do: nil

  defp typed_attacker({_unit_type, _unit_id} = ref) do
    if Ref.valid?(ref), do: ref, else: raise(ArgumentError, "invalid attacker reference")
  end

  defp typed_attacker(attacker_id) when is_integer(attacker_id), do: {:player, attacker_id}

  defp typed_source(nil), do: nil
  defp typed_source({_unit_type, _unit_id} = source), do: typed_attacker(source)
  defp typed_source(source_id) when is_integer(source_id), do: {:player, source_id}

  defp mob_attacker({_unit_type, _unit_id} = attacker), do: typed_attacker(attacker)
  defp mob_attacker(attacker), do: attacker

  defp attacker_id({_unit_type, unit_id}), do: unit_id
  defp attacker_id(unit_id), do: unit_id
end
