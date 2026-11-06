defmodule Aesir.ZoneServer.Content.Npc.Functions.FGetweapontype do
  @moduledoc """
  Names the weapon type of an item.

  ## Behavior

  Reads the item's view id and maps it to the weapon class the reference names, falling back to
  `Unknown Weapon` for anything else.

  ## Credits

  - Original from rAthena, authors and Contributors
    - L0ne_W0lf

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  import Aesir.ZoneServer.Script.Dsl

  alias Aesir.ZoneServer.Script.Ctx

  @iteminfo_view 11

  @weapon_types %{
    1 => "Dagger",
    2 => "One-handed Sword",
    3 => "Two-handed Sword",
    4 => "One-handed Spear",
    5 => "Two-handed Spear",
    6 => "One-handed Axe",
    7 => "Two-handed Axe",
    8 => "Mace",
    10 => "Staff",
    11 => "Bow",
    12 => "Knuckle",
    13 => "Instrument",
    14 => "Whip",
    15 => "Book",
    16 => "Katar",
    17 => "Revolver",
    18 => "Rifle",
    19 => "Gatling gun",
    20 => "Shotgun",
    21 => "Grenade Launcher",
    22 => "Shuriken"
  }

  @doc "Callable rAthena global function `F_GetWeaponType(weapon_id)`; returns the weapon class."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, args) do
    view = getiteminfo(ctx, Enum.at(args, 0, 0), @iteminfo_view)
    {ctx, Map.get(@weapon_types, view, "Unknown Weapon")}
  end
end
