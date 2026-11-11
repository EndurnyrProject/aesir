defmodule Aesir.ZoneServer.Mmo.Mechanics.StatusWindow do
  @moduledoc """
  Contract for the two-part combat values of the player status window.

  The client shows ATK, MATK, DEF and MDEF as a left and a right value, and each
  mode splits a player's battle status differently (rAthena `pc_leftside_*` and
  `pc_rightside_*` in `pc.hpp`, sent by `clif_updatestatus`). Implementations map
  battle components that shared orchestration has already computed onto the status
  parameters the window reads; they perform no lookups.
  """

  @typedoc """
  A player's battle-status components.

  `status_atk` is status ATK after its status changes, without the classic
  passives; `hilt_binding_atk` is the passive classic adds to it. `bonus_atk` is
  the flat ATK of equipment scripts and item statuses. Each hand gives its weapon
  ATK, refine ATK and weapon level, all zero for an empty hand. `status_watk` is
  the status weapon ATK and `level4_watk` the part only a level 4 weapon takes.

  The DEF and MDEF pairs are the battle values with every equipment and status
  modifier. `status_matk` is the status MATK formula alone, `weapon_matk` the
  weapons' MATK with refine and `flat_matk` the flat equipment and status MATK;
  `matk_min` and `matk_max` are the final band and `matk_amp_rate` the Mystical
  Amplification percentage currently inside it.
  """
  @type components :: %{
          status_atk: integer(),
          hilt_binding_atk: integer(),
          bonus_atk: integer(),
          right_atk: non_neg_integer(),
          right_refine_atk: non_neg_integer(),
          right_level: non_neg_integer(),
          left_atk: non_neg_integer(),
          left_refine_atk: non_neg_integer(),
          left_level: non_neg_integer(),
          status_watk: integer(),
          level4_watk: integer(),
          hard_def: integer(),
          soft_def: integer(),
          hard_mdef: integer(),
          soft_mdef: integer(),
          vit: integer(),
          status_matk: integer(),
          weapon_matk: integer(),
          flat_matk: integer(),
          matk_min: integer(),
          matk_max: integer(),
          matk_amp_rate: integer()
        }

  @typedoc "The status parameters of the window, keyed like `Aesir.Commons.StatusParams`."
  @type values :: %{
          atk1: integer(),
          atk2: integer(),
          matk1: integer(),
          matk2: integer(),
          def1: integer(),
          def2: integer(),
          mdef1: integer(),
          mdef2: integer()
        }

  @callback values(components()) :: values()

  @max_weapon_atk 65_535

  @doc "Bounds a hand's weapon ATK after its status weapon ATK, as the source's unsigned 16-bit cap."
  @spec cap_weapon_atk(integer()) :: non_neg_integer()
  def cap_weapon_atk(value), do: value |> max(0) |> min(@max_weapon_atk)
end
