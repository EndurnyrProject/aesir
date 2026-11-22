defmodule Aesir.ZoneServer.Unit.Mob.Calculated do
  @moduledoc """
  A monster's raw base or selectively calculated battle-stat snapshot.

  Primaries and accuracy/soft-defense/rate fields retain signed 16-bit
  assignments. Weapon/MATK bounds and motion/speed values are unsigned 16-bit;
  resources are unsigned 32-bit and base ATK is signed 32-bit. Hard defenses
  use signed 16-bit values in renewal and signed 8-bit values in classic.
  Mode is a nonnegative signed 32-bit mask decoded by `MobMode`.
  """

  use TypedStruct

  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.Race
  alias Aesir.ZoneServer.Mmo.Size

  @typedoc "Complete immutable status data; current HP/SP and action deadlines are session state."
  typedstruct enforce: true do
    field :str, -32_768..32_767
    field :agi, -32_768..32_767
    field :vit, -32_768..32_767
    field :int, -32_768..32_767
    field :dex, -32_768..32_767
    field :luk, -32_768..32_767
    field :batk, -2_147_483_648..2_147_483_647
    field :watk_min, 0..65_535
    field :watk_max, 0..65_535
    field :watk, 0..65_535
    field :watk2, 0..65_535
    field :matk_min, 0..65_535
    field :matk_max, 0..65_535
    field :hit, -32_768..32_767
    field :flee, -32_768..32_767
    field :cri, -32_768..32_767
    field :flee2, -32_768..32_767
    field :def, -32_768..32_767
    field :def2, -32_768..32_767
    field :mdef, -32_768..32_767
    field :mdef2, -32_768..32_767
    field :def_ele, Element.t()
    field :ele_lv, non_neg_integer()
    field :attack_element, Element.t()
    field :speed, 0..65_535
    field :amotion, 0..65_535
    field :client_amotion, 0..65_535
    field :adelay, 0..65_535
    field :dmotion, 0..65_535
    field :aspd_rate, -32_768..32_767
    field :max_hp, 0..4_294_967_295
    field :max_sp, 0..4_294_967_295
    field :mode, 0..2_147_483_647
    field :class, MobMode.class()
    field :race, Race.t()
    field :size, Size.t()
  end
end
