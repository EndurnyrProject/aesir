defmodule Aesir.ZoneServer.Content.Npc.Functions.FGetarmortype do
  @moduledoc """
  Names the equipment type of an item from its equip locations.

  ## Behavior

  Right-hand equipment is reported through `F_GetWeaponType`. Accessories share one name across
  the left, right and combined slots, and anything else falls back to `Unknown Equip`.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Content.Npc.Functions.FGetweapontype
  alias Aesir.ZoneServer.Script.Ctx

  @iteminfo_locations 5

  # rAthena `enum equip_pos` bitmasks, including the two combined accessory masks.
  @hand_right 0x000002

  @location_names %{
    0x000001 => "Lower Headgear",
    0x000004 => "Garment",
    0x000008 => "Accessory",
    0x000080 => "Accessory",
    0x000088 => "Accessory",
    0x000010 => "Armor",
    0x000020 => "Shield",
    0x000040 => "Shoes",
    0x000100 => "Upper Headgear",
    0x000200 => "Middle Headgear",
    0x000400 => "Costume Upper Headgear",
    0x000800 => "Costume Midle Headgear",
    0x001000 => "Costume Lower Headgear",
    0x002000 => "Costume Garment",
    0x008000 => "Ammo",
    0x010000 => "Shadow Armor",
    0x020000 => "Shadow Weapon",
    0x040000 => "Shadow Shield",
    0x080000 => "Shadow Shoes",
    0x100000 => "Shadow Accessory",
    0x200000 => "Shadow Accessory",
    0x300000 => "Shadow Accessory"
  }

  @doc "Callable rAthena global function `F_GetArmorType(item_id)`; returns the equipment class."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, args) do
    item = Enum.at(args, 0, 0)

    case getiteminfo(ctx, item, @iteminfo_locations) do
      @hand_right -> FGetweapontype.call(ctx, [item])
      locations -> {ctx, Map.get(@location_names, locations, "Unknown Equip")}
    end
  end
end
