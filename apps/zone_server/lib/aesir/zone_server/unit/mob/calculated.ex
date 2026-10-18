defmodule Aesir.ZoneServer.Unit.Mob.Calculated do
  @moduledoc """
  A monster's raw base or selectively calculated battle-stat snapshot.

  Primaries and accuracy/soft-defense/rate fields retain signed 16-bit
  assignments. Weapon/MATK bounds and motion/speed values are unsigned 16-bit;
  resources are unsigned 32-bit and base ATK is signed 32-bit. Hard defenses
  use signed 16-bit values in renewal and signed 8-bit values in classic.
  Mode is a nonnegative signed 32-bit mask decoded by `MobMode`.
  """

  alias Aesir.ZoneServer.Mmo.Element
  alias Aesir.ZoneServer.Mmo.MobManagement.MobMode
  alias Aesir.ZoneServer.Mmo.Race
  alias Aesir.ZoneServer.Mmo.Size

  @fields [
    :str,
    :agi,
    :vit,
    :int,
    :dex,
    :luk,
    :batk,
    :watk_min,
    :watk_max,
    :watk,
    :watk2,
    :matk_min,
    :matk_max,
    :hit,
    :flee,
    :cri,
    :flee2,
    :def,
    :def2,
    :mdef,
    :mdef2,
    :def_ele,
    :ele_lv,
    :attack_element,
    :speed,
    :amotion,
    :client_amotion,
    :adelay,
    :dmotion,
    :aspd_rate,
    :max_hp,
    :max_sp,
    :mode,
    :class,
    :race,
    :size
  ]
  @enforce_keys @fields
  defstruct @fields

  @typedoc "Complete immutable status data; current HP/SP and action deadlines are session state."
  @type t :: %__MODULE__{
          str: -32_768..32_767,
          agi: -32_768..32_767,
          vit: -32_768..32_767,
          int: -32_768..32_767,
          dex: -32_768..32_767,
          luk: -32_768..32_767,
          batk: -2_147_483_648..2_147_483_647,
          watk_min: 0..65_535,
          watk_max: 0..65_535,
          watk: 0..65_535,
          watk2: 0..65_535,
          matk_min: 0..65_535,
          matk_max: 0..65_535,
          hit: -32_768..32_767,
          flee: -32_768..32_767,
          cri: -32_768..32_767,
          flee2: -32_768..32_767,
          def: -32_768..32_767,
          def2: -32_768..32_767,
          mdef: -32_768..32_767,
          mdef2: -32_768..32_767,
          def_ele: Element.t(),
          ele_lv: non_neg_integer(),
          attack_element: Element.t(),
          speed: 0..65_535,
          amotion: 0..65_535,
          client_amotion: 0..65_535,
          adelay: 0..65_535,
          dmotion: 0..65_535,
          aspd_rate: -32_768..32_767,
          max_hp: 0..4_294_967_295,
          max_sp: 0..4_294_967_295,
          mode: 0..2_147_483_647,
          class: MobMode.class(),
          race: Race.t(),
          size: Size.t()
        }
end
