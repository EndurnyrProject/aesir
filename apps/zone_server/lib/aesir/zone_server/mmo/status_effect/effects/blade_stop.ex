defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.BladeStop do
  @moduledoc """
  Root (SC_BLADESTOP).

  The paired lock held by both participants of a caught swing. Each record's
  state carries its peer reference, the shared link id, the Root level, and the
  participant role (`:monk` / `:caught`). Both participants are immobilized,
  cannot attack, and cannot use skills except the Root-level follow-up set (whose
  per-level gate is enforced by `Aesir.ZoneServer.Mmo.Skills.Monk.Root`).

  Teardown is edge-triggered plus convergent, with no coordinator:

    * ending either record removes the peer's record for the same link id through
      the ordinary removal path. The peer's back-reference is cleared first, so
      its own `on_expire` finds no peer and the removal echo terminates instead of
      bouncing back;
    * a per-second tick removes a record whose peer record (same link id) or peer
      unit has vanished without callbacks - the case a terminating session that
      cleared status storage directly leaves behind;
    * finite durations are the final backstop.

  The status is not persisted (`no_save`) and ends on a cross-map warp
  (`remove_on_map_change`): the pairing is tied to two live units on one map.

  Establishment is a deterministic consequence of a won claim, not a landed-effect
  roll, so both applications bypass status resistance (`bypass_resistance`) - a
  high-VIT participant, including the Monk rooting themselves, must never resist -
  and bypass boss immunity (`bypass_boss_immunity`), since Renewal explicitly roots
  a boss attacker through this status even though the Monk (not the boss itself) is
  the source.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_bladestop,
    no_dispel: false,
    no_save: true,
    remove_on_map_change: true,
    bypass_resistance: true,
    bypass_boss_immunity: true,
    properties: [:prevents_movement, :prevents_attack, :prevents_skills],
    flags: [:no_move, :no_attack, :no_skill],
    allow_skills: [266, 267, 271, 272],
    tick_interval: 1_000,
    icon: :bladestop,
    opt3: :bladestop

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @impl true
  def on_expire(_target, %StatusEntry{state: state}, _context) do
    close_peer(state)
    :ok
  end

  @impl true
  def on_tick(_target, %StatusEntry{state: state} = instance, _context) do
    if peer_intact?(state), do: {:ok, instance}, else: :remove
  end

  # Ends the peer's matching record through the ordinary removal path. The peer's
  # back-reference is cleared first so its `on_expire` sees no peer and the echo
  # terminates; a peer whose record is absent or carries a different link id is
  # left untouched, which is what makes closure idempotent.
  defp close_peer(%{peer: {peer_type, peer_id}, link_id: link_id}) do
    case StatusStorage.get_status(peer_type, peer_id, :sc_bladestop) do
      %StatusEntry{state: %{link_id: ^link_id}} ->
        StatusStorage.update_status(peer_type, peer_id, :sc_bladestop, fn entry ->
          %{entry | state: Map.put(entry.state, :peer, nil)}
        end)

        Interpreter.remove_status(peer_type, peer_id, :sc_bladestop)

      _ ->
        :ok
    end
  end

  defp close_peer(_state), do: :ok

  defp peer_intact?(%{peer: {peer_type, peer_id}, link_id: link_id}) do
    peer_record_matches?(peer_type, peer_id, link_id) and peer_alive?(peer_type, peer_id)
  end

  defp peer_intact?(_state), do: false

  defp peer_record_matches?(peer_type, peer_id, link_id) do
    match?(
      %StatusEntry{state: %{link_id: ^link_id}},
      StatusStorage.get_status(peer_type, peer_id, :sc_bladestop)
    )
  end

  defp peer_alive?(peer_type, peer_id) do
    case UnitRegistry.get_unit(peer_type, peer_id) do
      {:ok, {_module, state, _pid}} -> Unit.living?(state)
      _ -> false
    end
  end
end
