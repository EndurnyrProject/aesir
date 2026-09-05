defmodule Aesir.ZoneServer.Mmo.Combat.DamageApplication do
  @moduledoc """
  Delivers already-calculated damage (and heals) to the owning unit session.

  The shared tail of every attack path: runs the hit through the pre-damage
  status absorption hook, routes the final damage to the target's session by
  unit type, runs the victim's post-damage reflect hook, and broadcasts combat
  packets to nearby players. Keeps the attack paths free of concrete
  session-module knowledge.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Combat.Hallucination
  alias Aesir.ZoneServer.Mmo.Combat.HandedAttack
  alias Aesir.ZoneServer.Mmo.Combat.MagicDefense
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Devotion
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @doc """
  Resolves pre-delivery equipment and status damage modifiers for one hit.

  Skill magic damage is reduced by the target's equipment first. On siege
  ground, eligibility precedes mutable hooks, absorption precedes the map rate,
  and Devotion forwards the settled amount. Elsewhere, Devotion still precedes
  absorption. Raw costs and status ticks do not acquire an attack's map rate.

  Attack paths that render damage must call this before constructing their
  packet, then pass the returned hit information to `apply_unit_damage/6`.
  Preparation records completion and, on ground, the distinct equipment
  pre-status basis and settled status-return basis. This keeps visible damage
  and HP loss identical without consuming modifiers such as Lex Aeterna twice.

  A valid Devotion link delivers to the Crusader with `redirected: true`,
  bypassing recipient absorption, map rates and return damage, and returns `0`
  for the devotee. A stale link is torn down and the hit lands normally.
  Reflected spells retain their metadata and settle at their actual recipient;
  unlike prepared weapon returns, they still receive equipment and status
  modifiers there. Reflected hits and self-damage are never rerouted.
  """
  @spec prepare_unit_damage(
          :player | :mob | :homunculus | :skill_unit,
          integer(),
          integer(),
          map(),
          integer() | Ref.t() | nil
        ) :: {integer(), map()}
  def prepare_unit_damage(target_type, target_id, damage, hit_info, attacker_id) do
    case ground_target(target_type, target_id, hit_info) do
      {:ok, target} ->
        prepare_ground_damage(target_type, target_id, damage, hit_info, attacker_id, target)

      :not_ground ->
        prepare_ordinary_damage(target_type, target_id, damage, hit_info, attacker_id)
    end
  end

  defp prepare_ordinary_damage(target_type, target_id, damage, hit_info, attacker_id) do
    damage = reduce_magic_damage(damage, target_type, target_id, hit_info)

    case reroute_to_crusader(target_type, target_id, damage, hit_info, attacker_id) do
      {:rerouted, _delivery} ->
        {0, Map.put(hit_info, :pre_delivery_prepared?, true)}

      :not_rerouted ->
        {absorb_unit_damage(target_type, target_id, damage, hit_info),
         Map.put(hit_info, :pre_delivery_prepared?, true)}
    end
  end

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

    settled = apply_ground_rate(absorbed, Rules.damage_rate(hit_info))
    finish_ground_hit(target_type, target_id, settled, prepared_hit, attacker)
  end

  defp absorb_ground_hit(target_type, target_id, damage, hit_info, attacker, target) do
    case Rules.validate_target(resolve_attacker(attacker), target, hit_info) do
      :ok ->
        equipment_basis = reduce_magic_damage(damage, target_type, target_id, hit_info)
        absorbed = absorb_unit_damage(target_type, target_id, equipment_basis, hit_info)

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
      {:rerouted, _delivery} -> {0, prepared_hit}
      :not_rerouted -> {settled, prepared_hit}
    end
  end

  defp reduce_magic_damage(damage, target_type, target_id, hit_info) do
    if Map.get(hit_info, :dmg_type) == :magic and is_integer(Map.get(hit_info, :skill_id)),
      do: MagicDefense.reduce(damage, target_type, target_id),
      else: damage
  end

  @doc """
  Settles and delivers one already-calculated ordinary weapon swing.

  Mutating status absorption sees the raw aggregate once. On siege ground,
  each resulting positive component receives its own map rate and minimum;
  Devotion forwards their sum. Outside ground, Devotion still sees the raw
  aggregate first. The returned swing retains its raw total and its settled
  components sum to the one delivered HP mutation (zero for a devotee).
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

    case ground_target(target_type, target_id, hit_info) do
      {:ok, target} ->
        {absorbed, prepared_hit} =
          absorb_ground_hit(target_type, target_id, raw_total, hit_info, attacker, target)

        settled =
          swing
          |> settle_components(absorbed)
          |> rate_components(Rules.damage_rate(hit_info))

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

        {if(damage == 0, do: settle_components(swing, 0), else: settled), delivery}

      :not_ground ->
        apply_ordinary_swing(target_type, target_pid, target_id, swing, hit_info, attacker)
    end
  end

  def apply_weapon_swing(
        _target_type,
        _target_pid,
        _target_id,
        %HandedAttack{} = swing,
        _hit_info,
        _attacker
      ) do
    {settle_components(swing, 0), :ok}
  end

  defp apply_ordinary_swing(target_type, target_pid, target_id, swing, hit_info, attacker) do
    raw_total = swing.raw_total

    case reroute_to_crusader(target_type, target_id, raw_total, hit_info, attacker) do
      {:rerouted, delivery} ->
        {settle_components(swing, 0), delivery}

      :not_rerouted ->
        final_damage = absorb_unit_damage(target_type, target_id, raw_total, hit_info)
        settled = settle_components(swing, final_damage)
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

        {settled, delivery}
    end
  end

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

    delivery =
      deliver_unit_damage(target_type, target_pid, target_id, final_damage, hit_info, attacker)

    post_delivery =
      after_damage_taken(delivery, target_type, target_id, final_damage, hit_info, attacker)

    merge_local_effects(delivery, post_delivery)
  end

  @doc "Builds aggregate-local Homunculus damage without sending to its owner process."
  @spec local_damage_effect(Ref.t(), integer(), map(), Ref.t() | nil) :: tuple()
  def local_damage_effect({:homunculus, world_gid} = target_ref, damage, hit_info, attacker)
      when is_integer(damage) and damage >= 0 do
    if Ref.valid?(target_ref) and (is_nil(attacker) or Ref.valid?(attacker)) do
      {final_damage, hit_info} =
        prepare_delivery(:homunculus, world_gid, damage, hit_info, attacker)

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

  def apply_vanish(:mob, target_pid, hp_percent, sp_percent, source) do
    MobSession.apply_vanish(target_pid, hp_percent, sp_percent, source)
  end

  def apply_vanish(_target_type, _target_pid, _hp_percent, _sp_percent, _source), do: :ok

  @doc """
  Heals a living unit.

  For `:player` this broadcasts to the player's PubSub topic; an offline
  player (no subscriber) is a silent no-op. For `:mob` this resolves the
  target's session pid via `UnitRegistry` and calls `MobSession.heal/2`; a
  target that no longer exists is a silent no-op.
  """
  @type heal_amount :: non_neg_integer() | {:potion, :hp | :sp, non_neg_integer()}

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
    packet = Hallucination.maybe_garble(packet, Map.get(target, :unit_type))
    Broadcast.to_in_range(target.map_name, x, y, Config.view_range(), packet)
  end

  # Redirects damage aimed at a devoted player to its Crusader. Runs entirely
  # against StatusStorage and the spatial index (no session calls), so the
  # decision is safe inside the attacker's own process. Only real, positive,
  # non-reflected/non-redirected damage from a distinct attacker is eligible;
  # self-damage (Grand Cross) carries `attacker_id == target_id` and is skipped.
  defp reroute_to_crusader(:player, target_id, damage, hit_info, attacker)
       when damage > 0 and not is_nil(attacker) do
    if attacker_id(attacker) != target_id and reroutable?(hit_info) do
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
      not Map.get(hit_info, :redirected, false)
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
      {:ok, crusader_pid, _state, :player} ->
        redirected_info =
          hit_info
          |> Map.put(:redirected, true)
          |> Map.put(:pre_delivery_prepared?, true)

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

  defp absorb_unit_damage(:skill_unit, _target_id, damage, _hit_info), do: damage

  defp absorb_unit_damage(target_type, target_id, damage, hit_info) when damage > 0 do
    StatusInterpreter.absorb_damage(target_type, target_id, damage, hit_info)
  end

  defp absorb_unit_damage(_target_type, _target_id, damage, _hit_info), do: damage

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

    amount = apply_ground_rate(status_return, rate) + apply_ground_rate(equipment_return, rate)

    apply_reflected_damage(amount, reflection_target(attacker), %{
      reflected: true,
      pre_delivery_prepared?: true
    })
  end

  defp after_damage_taken(_delivery, target_type, target_id, damage, hit_info, attacker)
       when damage > 0 do
    delivered_hit =
      hit_info
      |> Map.put(:damage, damage)
      |> Map.put(:attacker, typed_attacker(attacker))

    status_reflect = StatusInterpreter.after_damage_taken(target_type, target_id, delivered_hit)
    equip_reflect = equipment_damage_return(target_type, target_id, delivered_hit)

    apply_reflected_damage(status_reflect + equip_reflect, reflection_target(attacker))
  end

  defp after_damage_taken(_delivery, _target_type, _target_id, _damage, _hit_info, _attacker),
    do: :ok

  defp apply_reflected_damage(amount, attacker, hit_info \\ %{reflected: true})

  defp apply_reflected_damage(amount, attacker_id, hit_info)
       when amount > 0 and is_integer(attacker_id) do
    case TargetResolver.resolve(attacker_id) do
      {:ok, attacker_pid, _state, attacker_type} ->
        apply_unit_damage(
          attacker_type,
          attacker_pid,
          attacker_id,
          amount,
          hit_info,
          nil
        )

      {:error, _reason} ->
        :ok
    end
  end

  defp apply_reflected_damage(amount, {attacker_type, attacker_id} = attacker_ref, hit_info)
       when amount > 0 do
    case TargetResolver.resolve(attacker_ref) do
      {:ok, attacker_pid, _state, ^attacker_type} ->
        apply_unit_damage(
          attacker_type,
          attacker_pid,
          attacker_id,
          amount,
          hit_info,
          nil
        )

      {:error, _reason} ->
        :ok
    end
  end

  defp apply_reflected_damage(_amount, _attacker, _hit_info), do: :ok

  # Equipment-granted melee damage reflect (`bShortWeaponDamageReturn`): the
  # defender's gear returns a percent of the supplied basis to the attacker on
  # a short-range physical hit. Shares Reflect Shield's hit-shape filter, so an
  # already-reflected, redirected, ranged, or magic hit reflects nothing. Only
  # players carry equipment, so mobs and other unit types never reflect here.
  defp equipment_damage_return(:player, target_id, hit_info) do
    if melee_reflectable?(hit_info) do
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

  defp melee_reflectable?(hit_info) do
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
        {absorb_unit_damage(target_type, target_id, damage, hit_info),
         Map.put(hit_info, :pre_delivery_prepared?, true)}
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
       when target_type in [:player, :mob, :homunculus] and damage > 0 do
    deliver_coma(target_type, target_pid, target_id, hit_info, attacker)
  end

  defp deliver_unit_damage(_target_type, _pid, _id, damage, %{coma?: true}, _attacker)
       when damage <= 0,
       do: :ok

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
    note_kill_attack_type(target_pid, mob_attacker, kill_attack_type(hit_info))
    MobSession.apply_damage(target_pid, damage, mob_attacker)
  end

  defp deliver_unit_damage(
         :player,
         target_pid,
         _target_id,
         damage,
         %{skill_id: skill_id, skill_level: skill_level},
         attacker
       )
       when is_integer(skill_id) and is_integer(skill_level) do
    PlayerSession.apply_damage(target_pid, damage, typed_attacker(attacker))
    PlayerSession.record_skill_hit(target_pid, skill_id, skill_level)
  end

  defp deliver_unit_damage(:player, target_pid, _target_id, damage, _hit_info, attacker) do
    PlayerSession.apply_damage(target_pid, damage, typed_attacker(attacker))
  end

  defp deliver_coma(
         :player,
         target_pid,
         _target_id,
         %{skill_id: skill_id, skill_level: skill_level},
         attacker
       )
       when is_integer(skill_id) and is_integer(skill_level) do
    PlayerSession.apply_coma(target_pid, typed_attacker(attacker))
    PlayerSession.record_skill_hit(target_pid, skill_id, skill_level)
  end

  defp deliver_coma(:player, target_pid, _target_id, _hit_info, attacker) do
    PlayerSession.apply_coma(target_pid, typed_attacker(attacker))
  end

  defp deliver_coma(:mob, target_pid, _target_id, _hit_info, attacker) do
    MobSession.apply_coma(target_pid, typed_attacker(attacker))
  end

  defp deliver_coma(:homunculus, target_pid, target_id, _hit_info, attacker)
       when target_pid == self() do
    {:local_effects, [{:homunculus, {:apply_coma, target_id, typed_attacker(attacker)}}]}
  end

  defp deliver_coma(:homunculus, target_pid, target_id, _hit_info, attacker) do
    GenServer.cast(target_pid, {:homunculus, {:apply_coma, target_id, typed_attacker(attacker)}})
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
  defp note_kill_attack_type(_target_pid, nil, _bf), do: :ok
  defp note_kill_attack_type(_target_pid, _attacker, :other), do: :ok

  defp note_kill_attack_type(target_pid, attacker, bf) do
    MobSession.note_hit_type(target_pid, attacker, bf)
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
