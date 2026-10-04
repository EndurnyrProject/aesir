defmodule Aesir.ZoneServer.Mmo.Skills.Shared.PartySplash do
  @moduledoc "Living same-map party member selection for renewal and pre-renewal area buffs."

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Returns online, living party members within tile range, excluding the caster."
  @spec nearby_member_ids(PlayerState.t(), non_neg_integer()) :: [integer()]
  def nearby_member_ids(caster, radius) do
    with party_id when party_id != 0 <- Map.get(caster, :party_id, 0),
         {:ok, party} <- PartyManager.get(party_id) do
      party
      |> PartyState.online_members()
      |> Enum.reject(&(&1.char_id == caster.character_id))
      |> Enum.filter(&nearby?(&1.char_id, caster, radius))
      |> Enum.map(& &1.char_id)
    else
      _ -> []
    end
  end

  defp nearby?(id, caster, radius) do
    case UnitRegistry.get_unit(:player, id) do
      {:ok, {_module, member, _pid}} ->
        member.map_name == caster.map_name and Unit.living?(member) and
          Geometry.in_tile_range?(caster.x, caster.y, member.x, member.y, radius)

      {:error, :not_found} ->
        false
    end
  end
end
