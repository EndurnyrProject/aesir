defmodule Aesir.CharServer.Packets.CharacterInfo do
  @moduledoc """
  Canonical serializer for the 175-byte `CHARACTER_INFO` block.

  This is the single source of truth used by every char-list packet
  (`HC_ACCEPT_ENTER`, `HC_ACCEPT_MAKECHAR`, `HC_ACK_CHARINFO_PER_PAGE`). It
  encodes exactly rAthena's `char_mmo_char_tobuf` for the target packetver
  (`PACKETVER_RE_NUM >= 20211103`), where exp/jobexp and hp/maxhp/sp/maxsp are
  64-bit. The build's packetver is enforced against this layout below; older
  layouts are not implemented yet, so a lower `:commons` `:packetver` fails the
  build rather than silently emitting wrong bytes.

  Fields are read directly off a fully-persisted `%Character{}`; there is no
  defensive defaulting since all call sites pass Repo-loaded records.

  Byte layout (little-endian):

      offset  size  field
      0       4     GID (id)
      4       8     exp (base_exp)
      12      4     money (zeny)
      16      8     jobexp (job_exp)
      24      4     joblevel (job_level)
      28      4     bodystate (0)
      32      4     healthstate (0)
      36      4     effectstate (option)
      40      4     virtue (karma)
      44      4     honor (manner)
      48      2     jobpoint (status_point)
      50      8     hp
      58      8     maxhp (max_hp)
      66      8     sp
      74      8     maxsp (max_sp)
      82      2     speed (150)
      84      2     job (class)
      86      2     head (hair)
      88      2     body (0)
      90      2     weapon (riding guard)
      92      2     level (base_level)
      94      2     sppoint (skill_point)
      96      2     accessory (head_bottom)
      98      2     shield
      100     2     accessory2 (head_top)
      102     2     accessory3 (head_mid)
      104     2     headpalette (hair_color)
      106     2     bodypalette (clothes_color)
      108     24    name
      132     1     Str
      133     1     Agi
      134     1     Vit
      135     1     Int
      136     1     Dex
      137     1     Luk
      138     1     CharNum (char_num)
      139     1     hairColor (hair_color)
      140     2     bIsChangedCharName
      142     16    mapName (last_map)
      158     4     DelRevDate (0)
      162     4     robePalette (robe)
      166     4     chr_slot_changeCnt (0)
      170     4     chr_name_changeCnt
      174     1     sex

  Total: 175 bytes.
  """
  import Bitwise

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Network.Packet
  alias Aesir.Commons.Network.Packetver

  @target_packetver "20211103"

  unless Packetver.at_least?(@target_packetver) do
    raise "CharacterInfo's 175-byte layout requires :commons :packetver >= " <>
            "#{@target_packetver}, got #{Packetver.current()}; older layouts are not implemented"
  end

  @byte_size 175

  @riding_mask 0x20 ||| 0x80000 ||| 0x100000 ||| 0x200000 ||| 0x400000 ||| 0x800000 ||| 0x1000000 |||
                 0x2000000 ||| 0x4000000 ||| 0x8000000

  @doc """
  Returns the fixed size in bytes of a serialized `CHARACTER_INFO` block.
  """
  @spec byte_size() :: 175
  def byte_size, do: @byte_size

  @doc """
  Serializes a fully-persisted `%Character{}` into the 175-byte
  `CHARACTER_INFO` block.
  """
  @spec serialize(Character.t()) :: binary()
  def serialize(%Character{} = character) do
    name = Packet.pack_string(character.name, 24)
    map_name = Packet.pack_string(character.last_map, 16)
    is_changed_char_name = if character.rename > 0, do: 0, else: 1
    chr_name_change_cnt = if character.rename > 0, do: 1, else: 0
    sex = if character.sex == "M", do: 1, else: 0
    weapon = if (character.option &&& @riding_mask) != 0, do: 0, else: character.weapon

    <<
      character.id::32-little,
      character.base_exp::64-little,
      character.zeny::32-little,
      character.job_exp::64-little,
      character.job_level::32-little,
      0::32-little,
      0::32-little,
      character.option::32-little,
      character.karma::32-little,
      character.manner::32-little,
      character.status_point::16-little,
      character.hp::64-little,
      character.max_hp::64-little,
      character.sp::64-little,
      character.max_sp::64-little,
      150::16-little,
      character.class::16-little,
      character.hair::16-little,
      0::16-little,
      weapon::16-little,
      character.base_level::16-little,
      character.skill_point::16-little,
      character.head_bottom::16-little,
      character.shield::16-little,
      character.head_top::16-little,
      character.head_mid::16-little,
      character.hair_color::16-little,
      character.clothes_color::16-little,
      name::binary-size(24),
      character.str::8,
      character.agi::8,
      character.vit::8,
      character.int::8,
      character.dex::8,
      character.luk::8,
      character.char_num::8,
      character.hair_color::8,
      is_changed_char_name::16-little,
      map_name::binary-size(16),
      0::32-little,
      character.robe::32-little,
      0::32-little,
      chr_name_change_cnt::32-little,
      sex::8
    >>
  end
end
