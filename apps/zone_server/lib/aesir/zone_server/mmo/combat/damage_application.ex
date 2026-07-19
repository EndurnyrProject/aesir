defmodule Aesir.ZoneServer.Mmo.Combat.DamageApplication do
  @moduledoc """
  Delivers already-calculated damage (and heals) to the owning unit session.

  The shared tail of every attack path: runs the hit through the pre-damage
  status absorption hook, routes the final damage to the target's session by
  unit type, and broadcasts combat packets to nearby players. Keeps the attack
  paths free of concrete session-module knowledge.
  """

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager, as: SkillUnitManager
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Phoenix.PubSub

  @doc """
  Applies damage to a living unit's session.

  Targets with positive damage first run the hit through the pre-damage status
  absorption hook (Kyrie, Safety Wall, Energy Coat) so statuses can reduce or
  block it before HP is reduced, regardless of whether the defender is a player
  or a mob.
  """
  @spec apply_unit_damage(:player | :mob, pid(), integer(), integer(), map(), integer() | nil) ::
          :ok
  def apply_unit_damage(target_type, target_pid, target_id, damage, hit_info, attacker_id) do
    final_damage = absorb_unit_damage(target_type, target_id, damage, hit_info)
    unit_session(target_type).apply_damage(target_pid, final_damage, attacker_id)
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
  Broadcasts a heal to a player session via PubSub.

  An offline player (no subscriber) is a silent no-op. Mobs are never healed;
  for undead/demon targets use the damage path instead.
  """
  @spec apply_heal(integer(), non_neg_integer(), integer() | nil) :: :ok
  def apply_heal(target_id, amount, source_id \\ nil) do
    PubSub.broadcast(Aesir.PubSub, "player:#{target_id}", {:apply_heal, amount, source_id})
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

  defp absorb_unit_damage(target_type, target_id, damage, hit_info) when damage > 0 do
    StatusInterpreter.absorb_damage(target_type, target_id, damage, hit_info)
  end

  defp absorb_unit_damage(_target_type, _target_id, damage, _hit_info), do: damage
end
