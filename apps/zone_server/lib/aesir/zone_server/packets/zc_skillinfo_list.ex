defmodule Aesir.ZoneServer.Packets.ZcSkillinfoList do
  @moduledoc """
  ZC_SKILLINFO_LIST (0x010F) - sends the player's learned skills to the client.

  Variable-size. Each 37-byte block:
  - id: 2 bytes
  - inf: 4 bytes (target info bitmask)
  - level: 2 bytes
  - sp: 2 bytes (SP cost at that level)
  - range: 2 bytes
  - name: 24 bytes (null-padded aegis name)
  - upgradable: 1 byte
  """
  use Aesir.Commons.Network.Packet

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Definition

  @packet_id 0x010F
  @packet_size :variable

  defstruct skills: []

  @impl true
  def packet_id, do: @packet_id

  @impl true
  def packet_size, do: @packet_size

  @spec from_learned(%{integer() => non_neg_integer()}) :: %__MODULE__{}
  def from_learned(learned_skills) do
    skills =
      Enum.flat_map(learned_skills, fn {skill_id, level} ->
        case Catalog.by_id(skill_id) do
          {:ok, definition} -> [to_block(definition, level)]
          :error -> []
        end
      end)

    %__MODULE__{skills: skills}
  end

  @impl true
  def build(%__MODULE__{skills: skills}) do
    blocks = skills |> Enum.map(&build_block/1) |> IO.iodata_to_binary()
    build_variable_packet(@packet_id, blocks)
  end

  defp to_block(%Definition{} = definition, level) do
    %{
      id: definition.id,
      inf: inf_for(definition.target_type),
      level: level,
      sp: Enum.at(definition.sp_cost, level - 1, 0),
      range: definition.range,
      name: definition.name |> Atom.to_string() |> String.upcase(),
      upgradable: 0
    }
  end

  defp build_block(%{
         id: id,
         inf: inf,
         level: level,
         sp: sp,
         range: range,
         name: name,
         upgradable: up
       }) do
    <<id::16-little, inf::32-little, level::16-little, sp::16-little, range::16-little,
      pack_string(name, 24)::binary, up::8>>
  end

  defp inf_for(:passive), do: 0
  defp inf_for(:target_enemy), do: 1
  defp inf_for(:ground), do: 2
  defp inf_for(:self), do: 4
  defp inf_for(:target_ally), do: 16
end
