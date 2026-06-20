defmodule Aesir.CharServer.CharacterMapper do
  @moduledoc """
  Maps an `Aesir.Commons.Models.Character` Ecto struct to the protobuf
  `Aesir.Net.Character` message used on the QUIC/protobuf wire.

  This module is the single source of truth for all field derivation rules
  that were previously encoded in the legacy 175-byte `CharacterInfo` serializer:

    - `sex`: "M" maps to 1; any other value maps to 0.
    - `weapon`: forced to 0 when any riding bit is set in `option`.
    - `delete_date`: `NaiveDateTime` converted to a UTC unix timestamp; `nil` maps to 0.
  """

  import Bitwise

  alias Aesir.Commons.Models.Character
  alias Aesir.Net.Character, as: NetCharacter

  @riding_mask 0x20 ||| 0x80000 ||| 0x100000 ||| 0x200000 ||| 0x400000 ||| 0x800000 |||
                 0x1000000 ||| 0x2000000 ||| 0x4000000 ||| 0x8000000

  @doc """
  Converts a fully-persisted `%Character{}` into an `%Aesir.Net.Character{}`.

  All field derivation follows the same rules as the legacy `CharacterInfo.serialize/1`.
  """
  @spec to_proto(Character.t()) :: NetCharacter.t()
  def to_proto(%Character{} = c) do
    %NetCharacter{
      gid: c.id,
      name: c.name,
      class: c.class,
      base_level: c.base_level,
      job_level: c.job_level,
      base_exp: c.base_exp,
      job_exp: c.job_exp,
      zeny: c.zeny,
      hp: c.hp,
      max_hp: c.max_hp,
      sp: c.sp,
      max_sp: c.max_sp,
      str: c.str,
      agi: c.agi,
      vit: c.vit,
      int: c.int,
      dex: c.dex,
      luk: c.luk,
      status_point: c.status_point,
      skill_point: c.skill_point,
      hair: c.hair,
      hair_color: c.hair_color,
      clothes_color: c.clothes_color,
      weapon: weapon(c.option, c.weapon),
      shield: c.shield,
      head_top: c.head_top,
      head_mid: c.head_mid,
      head_bottom: c.head_bottom,
      robe: c.robe,
      char_num: c.char_num,
      last_map: c.last_map,
      sex: sex(c.sex),
      option: c.option,
      karma: c.karma,
      manner: c.manner,
      rename: c.rename,
      delete_date: delete_date(c.delete_date)
    }
  end

  defp weapon(option, weapon) do
    if (option &&& @riding_mask) != 0, do: 0, else: weapon
  end

  defp sex("M"), do: 1
  defp sex(_), do: 0

  defp delete_date(nil), do: 0

  defp delete_date(%NaiveDateTime{} = dt) do
    dt |> DateTime.from_naive!("Etc/UTC") |> DateTime.to_unix()
  end
end
