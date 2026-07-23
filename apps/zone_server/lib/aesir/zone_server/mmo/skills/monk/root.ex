defmodule Aesir.ZoneServer.Mmo.Skills.Monk.Root do
  @moduledoc """
  Pure reads and closure over the paired `sc_bladestop` Root records.

  Establishment lives in
  `Aesir.ZoneServer.Mmo.StatusEffect.Effects.BladeStopWaiting`; this module is the
  read side the level-gated follow-up skills consume to resolve their locked
  target and validate eligibility, plus the idempotent closure both the
  follow-ups and teardown paths call.

  Each participant's own Root level gates its follow-up set: Throw Spirit Sphere
  from level 2, Occult Impaction from level 3, Raging Quadruple Blow from level 4,
  and Asura Strike from level 5. The caught side keys on its own stored level (0
  for a non-Monk, the trained level for a caught Monk), matching the source, so no
  role concept is needed.
  """

  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit

  @type peer :: {Unit.unit_type(), integer()}

  # Minimum Root level that unlocks each follow-up skill id.
  @min_root_level %{
    # MO_FINGEROFFENSIVE - Throw Spirit Sphere
    267 => 2,
    # MO_INVESTIGATE - Occult Impaction
    266 => 3,
    # MO_CHAINCOMBO - Raging Quadruple Blow
    272 => 4,
    # MO_EXTREMITYFIST - Asura Strike
    271 => 5
  }

  @doc """
  Resolves the peer a unit is Root-linked to, or `nil` when it holds no Root.
  """
  @spec linked_peer(Unit.unit_type(), integer()) :: peer() | nil
  def linked_peer(unit_type, unit_id) do
    case StatusStorage.get_status(unit_type, unit_id, :sc_bladestop) do
      %StatusEntry{state: %{peer: {_type, _id} = peer}} -> peer
      _ -> nil
    end
  end

  @doc """
  Validates a level-gated Root follow-up by the caller against `target`.

  True only when the caller holds a `sc_bladestop` whose peer is `target`, the
  peer still holds a `sc_bladestop` with the same link id, and the caller's own
  stored Root level meets the follow-up's minimum. Any missing record, mismatched
  link, wrong target, or unknown skill is `false`.
  """
  @spec follow_up_allowed?(Unit.unit_type(), integer(), integer(), peer()) :: boolean()
  def follow_up_allowed?(caster_type, caster_id, skill_id, target) do
    with min_level when is_integer(min_level) <- Map.get(@min_root_level, skill_id),
         %StatusEntry{state: %{peer: ^target, link_id: link_id, root_level: root_level}} <-
           StatusStorage.get_status(caster_type, caster_id, :sc_bladestop),
         {peer_type, peer_id} <- target,
         %StatusEntry{state: %{link_id: ^link_id}} <-
           StatusStorage.get_status(peer_type, peer_id, :sc_bladestop) do
      root_level >= min_level
    else
      _ -> false
    end
  end

  @doc """
  Initiates idempotent pair closure from `unit`'s side.

  Removing `unit`'s `sc_bladestop` cascades to the peer through the ordinary
  removal path; removing an already-absent record is a no-op.
  """
  @spec close(Unit.unit_type(), integer()) :: :ok
  def close(unit_type, unit_id) do
    Interpreter.remove_status(unit_type, unit_id, :sc_bladestop)
    :ok
  end
end
