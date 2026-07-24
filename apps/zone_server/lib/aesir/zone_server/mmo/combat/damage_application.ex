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
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Devotion
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry
  alias Phoenix.PubSub

  @doc """
  Resolves pre-delivery status damage modifiers for one hit.

  Attack paths that render damage must call this before constructing their
  packet, then pass the returned hit information to `apply_unit_damage/6`.
  This keeps the visible number and HP loss identical while ensuring a
  consumable modifier such as Lex Aeterna runs exactly once.

  Damage aimed at a player holding a valid Devotion link is rerouted to the
  Crusader instead: the full computed damage is applied to the Crusader through
  the async path flagged `redirected: true` (bypassing the Crusader's own
  absorb/reductions/reflect), and this call returns `0` so the devotee takes and
  displays nothing. A stale link (Crusader dead, cross-map, or out of range) is
  torn down here and the hit lands on the devotee normally. Reflected packets
  and self-damage (attacker equals target) are never rerouted.
  """
  @spec prepare_unit_damage(:player | :mob, integer(), integer(), map(), integer() | nil) ::
          {integer(), map()}
  def prepare_unit_damage(target_type, target_id, damage, hit_info, attacker_id) do
    case reroute_to_crusader(target_type, target_id, damage, hit_info, attacker_id) do
      :rerouted ->
        {0, Map.put(hit_info, :pre_delivery_prepared?, true)}

      :not_rerouted ->
        {absorb_unit_damage(target_type, target_id, damage, hit_info),
         Map.put(hit_info, :pre_delivery_prepared?, true)}
    end
  end

  @doc """
  Applies damage to a living unit's session.

  Callers without a packet may pass an ordinary hit and the modifier hook runs
  here. Packet-producing paths pass hit information returned by
  `prepare_unit_damage/5`, which prevents applying the same modifier twice.
  """
  @spec apply_unit_damage(:player | :mob, pid(), integer(), integer(), map(), integer() | nil) ::
          :ok
  def apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker_id) do
    final_damage =
      if Map.get(hit_info, :pre_delivery_prepared?, false) do
        damage
      else
        absorb_unit_damage(target_type, target_id, damage, hit_info)
      end

    unit_session(target_type).apply_damage(target_pid, final_damage, attacker_id)
    reflect_unit_damage(target_type, target_id, final_damage, hit_info, attacker_id)
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
  Heals a living unit.

  For `:player` this broadcasts to the player's PubSub topic; an offline
  player (no subscriber) is a silent no-op. For `:mob` this resolves the
  target's session pid via `UnitRegistry` and calls `MobSession.heal/2`; a
  target that no longer exists is a silent no-op.
  """
  @spec apply_heal(:player | :mob, integer(), non_neg_integer(), integer() | nil) :: :ok
  def apply_heal(:player, unit_id, amount, source_id) do
    PubSub.broadcast(
      Aesir.PubSub,
      "player:#{unit_id}",
      {:combat, {:apply_heal, amount, source_id}}
    )
  end

  def apply_heal(:mob, unit_id, amount, _source_id) do
    case UnitRegistry.get_unit(:mob, unit_id) do
      {:ok, {_module, _state, pid}} -> MobSession.heal(pid, amount)
      {:error, :not_found} -> :ok
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
    Broadcast.to_in_range(target.map_name, x, y, Config.view_range(), packet)
  end

  # Redirects damage aimed at a devoted player to its Crusader. Runs entirely
  # against StatusStorage and the spatial index (no session calls), so the
  # decision is safe inside the attacker's own process. Only real, positive,
  # non-reflected/non-redirected damage from a distinct attacker is eligible;
  # self-damage (Grand Cross) carries `attacker_id == target_id` and is skipped.
  defp reroute_to_crusader(:player, target_id, damage, hit_info, attacker_id)
       when damage > 0 and is_integer(attacker_id) and attacker_id != target_id do
    if reroutable?(hit_info) do
      dispatch_reroute(target_id, damage, hit_info, attacker_id)
    else
      :not_rerouted
    end
  end

  defp reroute_to_crusader(_target_type, _target_id, _damage, _hit_info, _attacker_id),
    do: :not_rerouted

  defp dispatch_reroute(target_id, damage, hit_info, attacker_id) do
    case Devotion.redirect_target(target_id) do
      {:ok, crusader_id} ->
        redirect_damage(crusader_id, damage, hit_info, attacker_id)
        :rerouted

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

  defp absorb_unit_damage(target_type, target_id, damage, hit_info) when damage > 0 do
    StatusInterpreter.absorb_damage(target_type, target_id, damage, hit_info)
  end

  defp absorb_unit_damage(_target_type, _target_id, damage, _hit_info), do: damage

  # Runs the victim's post-damage statuses and sends any reflected damage back to
  # the attacker. Fires only for short-range weapon damage that is neither a
  # reflected nor a redirected packet, so reflection can never loop or re-trigger.
  # The reflected packet goes through the async apply path (a session cast) - this
  # runs inside the attacker's own process, so a synchronous self-application would
  # deadlock.
  defp reflect_unit_damage(target_type, target_id, damage, hit_info, attacker_id)
       when damage > 0 and is_integer(attacker_id) do
    if reflectable?(hit_info) do
      target_type
      |> StatusInterpreter.after_damage_taken(target_id, Map.put(hit_info, :damage, damage))
      |> apply_reflected_damage(attacker_id)
    else
      :ok
    end
  end

  defp reflect_unit_damage(_target_type, _target_id, _damage, _hit_info, _attacker_id), do: :ok

  defp reflectable?(hit_info) do
    Map.get(hit_info, :dmg_type) == :physical and
      Map.get(hit_info, :is_short, false) == true and
      not Map.get(hit_info, :reflected, false) and
      not Map.get(hit_info, :redirected, false)
  end

  defp apply_reflected_damage(amount, attacker_id) when amount > 0 do
    case TargetResolver.resolve(attacker_id) do
      {:ok, attacker_pid, _state, attacker_type} ->
        apply_unit_damage(
          attacker_type,
          attacker_pid,
          attacker_id,
          amount,
          %{reflected: true},
          nil
        )

      {:error, _reason} ->
        :ok
    end
  end

  defp apply_reflected_damage(_amount, _attacker_id), do: :ok
end
