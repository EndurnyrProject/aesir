defmodule Aesir.ZoneServer.Content.Npc.Functions.FGetpositionname do
  @moduledoc """
  Names an equipment slot by its index.

  ## Behavior

  The index is the `getequipid` slot ordinal, 0 (Accessory 1) through 20 (Shadow Accessory 1).
  Anything else reads `Unknown`.

  ## Credits

  - Original from rAthena, authors and Contributors
    - Capuche

  ## Adaptation

  - Transpiled by mix aesir.import.npcs from rAthena script other/Global_Functions.txt
  - LLM-assisted Elixir refactor
  """

  alias Aesir.ZoneServer.Script.Ctx

  @slot_names %{
    0 => "Accessory 1",
    1 => "Accessory 2",
    2 => "Shoes",
    3 => "Robe",
    4 => "Head 3",
    5 => "Head 2",
    6 => "Head",
    7 => "Body",
    8 => "Left hand",
    9 => "Right hand",
    10 => "Upper Costume Headgear",
    11 => "Middle Costume Headgear",
    12 => "Lower Costume Headgear",
    13 => "Costume Garment",
    14 => "Arrow/Ammunition",
    15 => "Shadow Armor",
    16 => "Shadow Weapon",
    17 => "Shadow Shield",
    18 => "Shadow Shoes",
    19 => "Shadow Accessory 2",
    20 => "Shadow Accessory 1"
  }

  @doc "Callable rAthena global function `F_getpositionname(slot)`; returns the slot name."
  @spec call(Ctx.t(), [term()]) :: {Ctx.t(), String.t()}
  def call(ctx, args) do
    {ctx, Map.get(@slot_names, Enum.at(args, 0, 999), "Unknown")}
  end
end
