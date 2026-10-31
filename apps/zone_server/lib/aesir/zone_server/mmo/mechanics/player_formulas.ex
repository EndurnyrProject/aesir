defmodule Aesir.ZoneServer.Mmo.Mechanics.PlayerFormulas do
  @moduledoc """
  Pure player-stat leaves over effective stats and inputs prepared by shared orchestration.

  Maximum HP and SP share their arithmetic in both modes: scale the job table
  by VIT/INT and the upper-job bonus, add flat bonuses and equipment VIT/INT,
  calculate equipment and item percentages from that same amount, then add
  the truncated ordinary status-rate contribution before the final truncation.
  """

  @type base_atk_inputs :: %{
          str: integer(),
          dex: integer(),
          luk: integer(),
          pow: integer(),
          base_level: non_neg_integer()
        }
  @type base_def_inputs :: %{vit: integer(), base_level: non_neg_integer()}
  @typedoc "Effective player attributes used to derive status DEF before per-hit modifiers."
  @type soft_def_inputs :: %{vit: integer(), agi: integer(), base_level: non_neg_integer()}
  @type base_matk_inputs :: %{
          int: integer(),
          dex: integer(),
          luk: integer(),
          spl: integer(),
          base_level: non_neg_integer()
        }
  @type soft_mdef_inputs :: %{
          int: integer(),
          dex: integer(),
          vit: integer(),
          base_level: non_neg_integer()
        }
  @type hit_inputs :: %{
          dex: integer(),
          luk: integer(),
          con: integer(),
          base_level: non_neg_integer(),
          flat_bonus: integer()
        }
  @type flee_inputs :: %{
          agi: integer(),
          luk: integer(),
          con: integer(),
          base_level: non_neg_integer(),
          flat_bonus: integer()
        }
  @type critical_inputs :: %{luk: integer(), base_level: non_neg_integer()}
  @type critical_basis :: %{strategy: :exact_tenths, base_rate: integer()}
  @type perfect_dodge_inputs :: %{luk: integer()}
  @type matk_band :: %{min: integer(), max: integer()}

  @type aspd_inputs :: %{
          agi: integer(),
          dex: integer(),
          weapon_delay: non_neg_integer(),
          left_weapon_delay: non_neg_integer() | nil,
          ranged?: boolean(),
          flat_bonus: integer(),
          rate_bonus: integer(),
          penalty_rate: integer(),
          max_aspd: 190 | 193
        }
  @type max_hp_inputs :: %{
          base_hp: non_neg_integer(),
          vit: integer(),
          equipment_vit: integer(),
          hp_factor: non_neg_integer(),
          hp_increase: non_neg_integer(),
          flat_bonus: integer(),
          equipment_rate: number(),
          modifier_rate: number(),
          transcendent?: boolean()
        }
  @type max_sp_inputs :: %{
          optional(:item_rate) => number(),
          base_sp: non_neg_integer(),
          int: integer(),
          equipment_int: integer(),
          sp_increase: non_neg_integer(),
          flat_bonus: integer(),
          equipment_rate: number(),
          modifier_rate: number(),
          transcendent?: boolean()
        }
  @type trait_inputs :: %{
          pow: integer(),
          sta: integer(),
          wis: integer(),
          spl: integer(),
          con: integer(),
          crt: integer()
        }
  @type trait_bonuses :: %{
          patk: integer(),
          smatk: integer(),
          res: integer(),
          mres: integer(),
          hplus: integer(),
          crate: integer()
        }
  @type trait_slots :: %{
          patk: non_neg_integer(),
          smatk: non_neg_integer(),
          res: non_neg_integer(),
          mres: non_neg_integer(),
          hplus: integer(),
          crate: non_neg_integer()
        }

  @doc "Calculates maximum HP from the job table and the ordered flat and rate bonuses."
  @spec max_hp(max_hp_inputs()) :: pos_integer()
  def max_hp(inputs) do
    value =
      base_pool(inputs.base_hp, inputs.vit, inputs.transcendent?) + inputs.flat_bonus +
        inputs.equipment_vit

    apply_max_rates(value, inputs, 0)
  end

  @doc "Calculates maximum SP, keeping the item percentage separate from status rates."
  @spec max_sp(max_sp_inputs()) :: pos_integer()
  def max_sp(inputs) do
    value =
      base_pool(inputs.base_sp, inputs.int, inputs.transcendent?) + inputs.flat_bonus +
        inputs.equipment_int

    apply_max_rates(value, inputs, Map.get(inputs, :item_rate, 0))
  end

  defp base_pool(base, stat, true), do: base_pool(base, stat, false) * 1.25
  defp base_pool(base, stat, false), do: base * (1.0 + max(stat, 0) * 0.01)

  defp apply_max_rates(value, inputs, item_rate) do
    adjusted =
      value + value * inputs.equipment_rate / 100 + value * max(item_rate, -100) / 100

    trunc(adjusted + trunc(adjusted * max(inputs.modifier_rate, -100) / 100))
    |> max(1)
    |> min(4_294_967_295)
  end

  @callback base_atk(base_atk_inputs(), ranged? :: boolean()) :: integer()
  @callback base_def(base_def_inputs()) :: integer()
  @doc "Derives player status DEF, independent of equipment hard DEF."
  @callback soft_def(soft_def_inputs()) :: non_neg_integer()
  @callback base_matk(base_matk_inputs()) :: matk_band()
  @callback soft_mdef(soft_mdef_inputs()) :: integer()
  @callback hit_rate_base() :: 0 | 80
  @callback hit(hit_inputs()) :: integer()
  @callback flee(flee_inputs()) :: integer()
  @callback critical(critical_inputs()) :: critical_basis()
  @callback perfect_dodge(perfect_dodge_inputs()) :: integer()
  @callback aspd(aspd_inputs()) :: integer()
  @callback max_hp(max_hp_inputs()) :: pos_integer()
  @callback max_sp(max_sp_inputs()) :: pos_integer()
  @callback trait_slots(trait_inputs(), trait_bonuses()) :: trait_slots()
end
