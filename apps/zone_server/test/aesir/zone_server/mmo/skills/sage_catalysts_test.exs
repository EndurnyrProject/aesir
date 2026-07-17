defmodule Aesir.ZoneServer.Mmo.Skills.SageCatalystsTest do
  @moduledoc """
  Guard test for the Sage job tree (`specs/2026-07-17-sage-skills`, Task 28).

  The Sage skills that consume these catalysts land across later waves of the
  epic; this test exists ahead of them so a missing item id is caught now
  instead of silently sinking twelve tasks built on top of it.

  Endow catalysts (Scarlet_Pts/Indigo_Pts/Yellow_Wish_Pts/Lime_Green_Pts) and
  the gemstones are only known by aegis name in the architecture doc, so they
  are resolved via `Items.by_aegis/1`. The remaining catalysts were handed
  numeric ids directly and are resolved via `Items.by_id/1` instead, since
  their aegis names in the item db do not match the rAthena item names used
  in prose (id 990 is aegis `Boody_Red`, not `Red_Blood`; id 993 is aegis
  `Yellow_Live`, not `Green_Live`; id 7433 is aegis `Scroll`, not
  `Blank_Scroll`) — checking those by name would be checking the wrong thing.
  """
  use ExUnit.Case, async: true

  alias Aesir.ZoneServer.Mmo.ItemManagement.Items

  @by_aegis [
    {"Scarlet_Pts", "SA_FLAMELAUNCHER fire weapon endow (Task 4)"},
    {"Indigo_Pts", "SA_FROSTWEAPON water weapon endow (Task 4)"},
    {"Yellow_Wish_Pts", "SA_LIGHTNINGLOADER wind weapon endow (Task 4)"},
    {"Lime_Green_Pts", "SA_SEISMICWEAPON earth weapon endow (Task 4)"},
    {"Blue_Gemstone",
     "SA_VOLCANO/SA_DELUGE/SA_VIOLENTGALE (Task 9) and SA_LANDPROTECTOR (Task 12)"},
    {"Yellow_Gemstone", "SA_LANDPROTECTOR (Task 12) and SA_DISPELL (Task 23)"}
  ]

  @by_id [
    {7433, "SA_CREATECON shared recipe material, Blank_Scroll (Task 26)"},
    {990, "SA_CREATECON Elemental_Fire recipe material, Red_Blood (Task 26)"},
    {991, "SA_CREATECON Elemental_Water recipe material, Crystal_Blue (Task 26)"},
    {992, "SA_CREATECON Elemental_Wind recipe material, Wind_Of_Verdure (Task 26)"},
    {993, "SA_CREATECON Elemental_Earth recipe material, Green_Live (Task 26)"},
    {12114, "SA_ELEMENTFIRE and SA_CREATECON output, Elemental_Fire converter (Tasks 24, 26)"},
    {12115, "SA_ELEMENTWATER and SA_CREATECON output, Elemental_Water converter (Tasks 24, 26)"},
    {12116, "SA_ELEMENTGROUND and SA_CREATECON output, Elemental_Earth converter (Tasks 24, 26)"},
    {12117, "SA_ELEMENTWIND and SA_CREATECON output, Elemental_Wind converter (Tasks 24, 26)"}
  ]

  describe "catalysts resolved by aegis name" do
    for {aegis, needed_by} <- @by_aegis do
      test "#{aegis} exists, needed by #{needed_by}" do
        case Items.by_aegis(unquote(aegis)) do
          {:ok, _item} ->
            :ok

          :error ->
            flunk(
              "Catalyst item #{unquote(aegis)} is missing from the item db, " <>
                "needed by #{unquote(needed_by)}"
            )
        end
      end
    end
  end

  describe "catalysts resolved by id" do
    for {id, needed_by} <- @by_id do
      test "item #{id} exists, needed by #{needed_by}" do
        case Items.by_id(unquote(id)) do
          {:ok, _item} ->
            :ok

          :error ->
            flunk(
              "Catalyst item id #{unquote(id)} is missing from the item db, " <>
                "needed by #{unquote(needed_by)}"
            )
        end
      end
    end
  end
end
