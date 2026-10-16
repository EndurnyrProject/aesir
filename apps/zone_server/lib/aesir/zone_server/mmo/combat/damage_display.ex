defmodule Aesir.ZoneServer.Mmo.Combat.DamageDisplay do
  @moduledoc """
  Final touches on a damage packet just before it is broadcast, keyed on its
  target: a damaging hit on a target that endures it (`Endure.shown?/2`) shows
  its endure display type, then Hallucination garbles the shown numbers.
  """

  alias Aesir.Net.DamageDealt
  alias Aesir.Net.SkillDamage
  alias Aesir.ZoneServer.Mmo.Combat.Endure
  alias Aesir.ZoneServer.Mmo.Combat.Hallucination
  alias Aesir.ZoneServer.Mmo.Combat.PacketFactory

  @doc """
  Finalizes `packet` for a target of `unit_type`. Packets other than damage
  packets, and targets without a unit type, are left as they are.
  """
  @spec finalize(struct(), atom() | nil) :: struct()
  def finalize(packet, unit_type) do
    packet
    |> with_endure(unit_type)
    |> Hallucination.maybe_garble(unit_type)
  end

  defp with_endure(%DamageDealt{} = packet, unit_type),
    do: endure_shown(packet, packet.damage + packet.damage2, unit_type)

  defp with_endure(%SkillDamage{} = packet, unit_type),
    do: endure_shown(packet, packet.damage, unit_type)

  defp with_endure(packet, _unit_type), do: packet

  defp endure_shown(packet, damage, unit_type) do
    if damage >= 1 and Endure.shown?(unit_type, packet.target_id),
      do: %{packet | type: PacketFactory.endure_type(packet.type, packet.div)},
      else: packet
  end
end
