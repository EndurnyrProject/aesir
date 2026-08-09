defmodule Aesir.ZoneServer.Unit.Concealment do
  @moduledoc """
  Observer-side concealment reveal for the intravision equipment flag.

  Hiding/Cloaking/Chase Walk are not omitted from other players' view on the
  server; they are carried as concealment bits in the unit's shared sprite
  `effect_state` (an `Option` bitmask) and rendered as concealed by the client.
  A unit whose wearer carries the `:intravision` equipment flag must instead see
  those units normally, so this module masks the concealment bits out of the
  `effect_state` of a spawn/state packet *for that observer only*, leaving the
  concealed unit's status untouched (unlike Sight/Ruwach, which force-end it).
  """

  import Bitwise

  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  The `Option` bitmask of every concealment state intravision reveals
  (Hiding, Cloaking, Chase Walk).
  """
  @spec conceal_mask() :: non_neg_integer()
  def conceal_mask, do: Option.id(:hide) ||| Option.id(:cloak) ||| Option.id(:chasewalk)

  @doc "Whether an `effect_state` bitmask carries any concealment bit."
  @spec concealed?(integer()) :: boolean()
  def concealed?(effect_state), do: (effect_state &&& conceal_mask()) != 0

  @doc "Clears the concealment bits from an `effect_state` bitmask."
  @spec reveal_effect_state(integer()) :: integer()
  def reveal_effect_state(effect_state), do: effect_state &&& bnot(conceal_mask())

  @doc """
  Masks the concealment bits out of a packet's `effect_state` when `reveal?` is
  true, otherwise returns the packet unchanged. The packet must carry an
  `:effect_state` field (`UnitSpawn`/`UnitStateChange`).
  """
  @spec reveal(struct(), boolean()) :: struct()
  def reveal(packet, false), do: packet
  def reveal(packet, true), do: Map.update!(packet, :effect_state, &reveal_effect_state/1)

  @doc """
  Reveals a packet's concealed unit for `observer_char_id` when that player
  carries the intravision flag; a no-op for a missing or non-intravision
  observer.
  """
  @spec reveal_for(struct(), integer()) :: struct()
  def reveal_for(packet, observer_char_id) do
    reveal(packet, intravision?(observer_char_id))
  end

  @doc "Whether the player `char_id` currently carries the intravision flag."
  @spec intravision?(integer()) :: boolean()
  def intravision?(char_id) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{} = state, _pid}} -> PlayerState.intravision?(state)
      _ -> false
    end
  end
end
