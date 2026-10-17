defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Regeneration do
  @moduledoc """
  Regeneration (SC_REGENERATION). Guild area buff boosting natural recovery
  rates by level (`val1`): HP +200/+200/+300 percent and SP +100/+200/+300
  percent, mirroring the reference val2/val3 rate additions. A `val4` instead
  blocks the natural regeneration it flags (1 HP, 2 SP), as the end of Berserk
  starts it. A logout ends one holding a `val4` or no expiry before saving,
  and saves the others.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_regeneration,
    properties: [:buff],
    no_dispel: true,
    no_clear_buff: false,
    no_save_infinite: true,
    calc_flags: [:regen]

  import Bitwise

  @regen_hp 0x01
  @regen_sp 0x02

  @impl true
  def modifiers(%{val4: block}, _context) when is_integer(block) and block != 0 do
    %{}
    |> then(&if(band(block, @regen_hp) != 0, do: Map.put(&1, :hp_regen, -100), else: &1))
    |> then(&if(band(block, @regen_sp) != 0, do: Map.put(&1, :sp_regen, -100), else: &1))
  end

  def modifiers(instance, _context) do
    level = max(instance.val1, 1)
    hp_multiplier = if level == 1, do: 2, else: level
    %{hp_regen: hp_multiplier * 100, sp_regen: level * 100}
  end
end
