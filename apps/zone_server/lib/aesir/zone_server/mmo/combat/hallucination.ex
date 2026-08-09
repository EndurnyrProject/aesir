defmodule Aesir.ZoneServer.Mmo.Combat.Hallucination do
  @moduledoc """
  Damage-number garbling for units afflicted with Hallucination
  (`:sc_hallucination`).

  A unit under Hallucination has the damage numbers displayed over it randomized
  on every observer's client. Only the *displayed* value is affected — the
  server's authoritative damage is untouched. A displayed value of `0` (miss,
  guard, perfect dodge) is never garbled.

  The transform is applied once per broadcast packet (the same struct is fanned
  out to every nearby observer), keyed on the packet's target and the target's
  unit type.
  """

  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @doc """
  Returns the packet with its displayed damage randomized when the target unit
  is under Hallucination, otherwise the packet unchanged.

  `unit_type` is the target's unit type; a `nil` type (e.g. a broadcast target
  without unit identity) is treated as never afflicted.
  """
  @spec maybe_garble(struct(), atom() | nil) :: struct()
  def maybe_garble(%DamageDealt{target_id: target_id} = packet, unit_type)
      when not is_nil(unit_type) do
    if afflicted?(unit_type, target_id) do
      %{packet | damage: garble(packet.damage), damage2: garble(packet.damage2)}
    else
      packet
    end
  end

  def maybe_garble(%SkillDamage{target_id: target_id} = packet, unit_type)
      when not is_nil(unit_type) do
    if afflicted?(unit_type, target_id) do
      %{packet | damage: garble(packet.damage)}
    else
      packet
    end
  end

  def maybe_garble(packet, _unit_type), do: packet

  @spec afflicted?(atom(), integer()) :: boolean()
  defp afflicted?(unit_type, unit_id) do
    StatusStorage.has_status?(unit_type, unit_id, :sc_hallucination)
  end

  # Randomized display value: a random magnitude bucket, then a random number
  # within it. A real hit is never shown as its true value; a 0 stays 0.
  @spec garble(integer()) :: integer()
  defp garble(0), do: 0

  defp garble(_damage) do
    case :rand.uniform(5) do
      1 -> :rand.uniform(10) - 1
      2 -> :rand.uniform(100) - 1
      3 -> :rand.uniform(1_000) - 1
      4 -> :rand.uniform(10_000) - 1
      5 -> :rand.uniform(32_767) - 1
    end
  end
end
