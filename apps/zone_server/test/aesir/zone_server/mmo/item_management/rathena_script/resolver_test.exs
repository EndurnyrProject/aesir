defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.ResolverTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemGroups
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.CatalogNotLoadedError
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver

  setup :set_mimic_private
  setup :verify_on_exit!

  describe "resolve_status/1" do
    test "maps SC_BLESSING to the effect-module atom" do
      assert {:ok, :sc_blessing} = Resolver.resolve_status("SC_BLESSING")
    end

    test "maps the SC_INCAGI alias to :sc_increaseagi" do
      assert {:ok, :sc_increaseagi} = Resolver.resolve_status("SC_INCAGI")
    end

    test "unknown status is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "SC_NOPE"}} = Resolver.resolve_status("SC_NOPE")
    end
  end

  describe "resolve_element/1" do
    test "maps Ele_Fire to :fire" do
      assert {:ok, :fire} = Resolver.resolve_element("Ele_Fire")
    end

    test "maps Ele_Dark to :shadow mirroring the importer table" do
      assert {:ok, :shadow} = Resolver.resolve_element("Ele_Dark")
    end

    test "unknown element is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "Ele_Nope"}} = Resolver.resolve_element("Ele_Nope")
    end
  end

  describe "resolve_skill/1" do
    test "resolves a skill constant to its catalog id" do
      assert {:ok, 34} = Resolver.resolve_skill("AL_BLESSING")
    end

    test "resolves a numeric skill id" do
      assert {:ok, 34} = Resolver.resolve_skill(34)
    end

    test "unknown skill is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "NOT_A_SKILL"}} = Resolver.resolve_skill("NOT_A_SKILL")
    end
  end

  describe "source catalogs" do
    test "resolve items and groups without consulting runtime catalogs" do
      reject(&Items.loaded?/0)
      reject(&Items.by_id/1)
      reject(&Items.by_aegis/1)
      reject(&ItemGroups.loaded?/0)
      reject(&ItemGroups.fetch/1)

      Resolver.with_source_catalogs(source_catalogs(501, "Red_Potion", "ORE"), fn ->
        assert {:ok, 501} = Resolver.resolve_item(501)
        assert {:ok, 501} = Resolver.resolve_item("Red_Potion")
        assert {:ok, :ore} = Resolver.resolve_item_group("IG_Ore")
        assert {:error, {:unknown_symbol, "Nope_Item"}} = Resolver.resolve_item("Nope_Item")
        assert {:error, {:unknown_symbol, "IG_Nope"}} = Resolver.resolve_item_group("IG_Nope")
      end)
    end

    test "nested contexts restore the outer context after success and failure" do
      outer = source_catalogs(501, "Red_Potion", "ORE")
      inner = source_catalogs(502, "Orange_Potion", "BLUEBOX")

      Resolver.with_source_catalogs(outer, fn ->
        Resolver.with_source_catalogs(inner, fn ->
          assert {:ok, 502} = Resolver.resolve_item("Orange_Potion")
          assert {:error, {:unknown_symbol, "Red_Potion"}} = Resolver.resolve_item("Red_Potion")
        end)

        assert_raise RuntimeError, "boom", fn ->
          Resolver.with_source_catalogs(inner, fn -> raise "boom" end)
        end

        assert {:ok, 501} = Resolver.resolve_item("Red_Potion")
        assert {:ok, :ore} = Resolver.resolve_item_group("IG_Ore")
      end)
    end

    test "context is process-local" do
      stub(Items, :loaded?, fn -> false end)
      catalogs = source_catalogs(501, "Red_Potion", "ORE")

      Resolver.with_source_catalogs(catalogs, fn ->
        task =
          Task.async(fn ->
            receive do
              :resolve ->
                try do
                  Resolver.resolve_item("Red_Potion")
                rescue
                  CatalogNotLoadedError -> :catalog_not_loaded
                end
            end
          end)

        Mimic.allow(Items, self(), task.pid)
        send(task.pid, :resolve)
        assert Task.await(task) == :catalog_not_loaded
        assert {:ok, 501} = Resolver.resolve_item("Red_Potion")
      end)
    end
  end

  describe "runtime item fallback" do
    setup do
      potion = %ItemDefinition{
        id: 501,
        aegis_name: "Red_Potion",
        name: "Red Potion",
        type: :healing
      }

      stub(Items, :loaded?, fn -> true end)

      stub(Items, :by_id, fn
        501 -> {:ok, potion}
        _id -> :error
      end)

      stub(Items, :by_aegis, fn
        "Red_Potion" -> {:ok, potion}
        _aegis -> :error
      end)

      :ok
    end

    test "resolves loaded items" do
      assert {:ok, 501} = Resolver.resolve_item("Red_Potion")
      assert {:ok, 501} = Resolver.resolve_item(501)
      assert {:error, {:unknown_symbol, "Nope_Item"}} = Resolver.resolve_item("Nope_Item")
    end
  end

  describe "runtime item-group fallback" do
    setup do
      stub(ItemGroups, :loaded?, fn -> true end)

      stub(ItemGroups, :fetch, fn
        key when key in [:ore, :enchant_stone_box17] -> {:ok, :group}
        _key -> :error
      end)

      :ok
    end

    test "strips IG_ and downcases a loaded group token" do
      assert {:ok, :ore} = Resolver.resolve_item_group("IG_Ore")

      assert {:ok, :enchant_stone_box17} =
               Resolver.resolve_item_group("IG_Enchant_Stone_Box17")
    end

    test "a non-group symbol is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "Ore"}} = Resolver.resolve_item_group("Ore")
    end
  end

  describe "cold runtime catalogs" do
    test "item resolution raises the dedicated error" do
      stub(Items, :loaded?, fn -> false end)
      reject(&Items.by_aegis/1)

      assert_raise CatalogNotLoadedError, ~r/item catalog is not loaded/, fn ->
        Resolver.resolve_item("Red_Potion")
      end
    end

    test "item-group resolution raises the dedicated error" do
      stub(ItemGroups, :loaded?, fn -> false end)
      reject(&ItemGroups.fetch/1)

      assert_raise CatalogNotLoadedError, ~r/item-group catalog is not loaded/, fn ->
        Resolver.resolve_item_group("IG_Ore")
      end
    end
  end

  describe "resolve_class/1" do
    test "maps Job_Swordman to :swordman" do
      assert {:ok, :swordman} = Resolver.resolve_class("Job_Swordman")
    end

    test "maps the legacy CamelCase alias Job_SuperNovice to :super_novice" do
      assert {:ok, :super_novice} = Resolver.resolve_class("Job_SuperNovice")
    end

    test "derives an advanced job constant not in the curated map" do
      assert {:ok, :lord_knight} = Resolver.resolve_class("Job_Lord_Knight")
      assert {:ok, :whitesmith} = Resolver.resolve_class("Job_Whitesmith")
    end

    test "the derived fallback is case-insensitive" do
      assert {:ok, :lord_knight} = Resolver.resolve_class("JOB_LORD_KNIGHT")
    end

    test "unknown class is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "Job_Nope"}} = Resolver.resolve_class("Job_Nope")
    end
  end

  describe "resolve_race/1" do
    test "maps RC_Brute to :brute" do
      assert {:ok, :brute} = Resolver.resolve_race("RC_Brute")
    end

    test "maps RC_All to :all" do
      assert {:ok, :all} = Resolver.resolve_race("RC_All")
    end

    test "maps RC_Boss to the class-axis sentinel" do
      assert {:ok, {:class, :boss}} = Resolver.resolve_race("RC_Boss")
    end

    test "unknown race is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "RC_Nope"}} = Resolver.resolve_race("RC_Nope")
    end
  end

  describe "resolve_size/1" do
    test "maps Size_Large to :large" do
      assert {:ok, :large} = Resolver.resolve_size("Size_Large")
    end

    test "unknown size is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "Size_Nope"}} = Resolver.resolve_size("Size_Nope")
    end
  end

  describe "resolve_mob_class/1" do
    test "maps Class_Boss to :boss" do
      assert {:ok, :boss} = Resolver.resolve_mob_class("Class_Boss")
    end

    test "maps Class_All to :all" do
      assert {:ok, :all} = Resolver.resolve_mob_class("Class_All")
    end

    test "Class_Guardian is deliberately unresolved" do
      assert {:error, {:unknown_symbol, "Class_Guardian"}} =
               Resolver.resolve_mob_class("Class_Guardian")
    end
  end

  describe "resolve_eff/1" do
    test "maps Eff_Stun to :sc_stun" do
      assert {:ok, :sc_stun} = Resolver.resolve_eff("Eff_Stun")
    end

    test "unknown eff is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "Eff_Nope"}} = Resolver.resolve_eff("Eff_Nope")
    end
  end

  describe "resolve_bound/1" do
    test "resolves account and char bound constants" do
      assert {:ok, 1} = Resolver.resolve_bound("Bound_Account")
      assert {:ok, 4} = Resolver.resolve_bound("Bound_Char")
    end

    test "does not resolve guild or party bound constants" do
      assert {:error, {:unknown_symbol, "Bound_Guild"}} = Resolver.resolve_bound("Bound_Guild")
      assert {:error, {:unknown_symbol, "Bound_Party"}} = Resolver.resolve_bound("Bound_Party")
    end
  end

  describe "resolve_stat_param/1" do
    test "maps a base stat constant to its stat atom" do
      assert {:ok, :str} = Resolver.resolve_stat_param("bStr")
      assert {:ok, :luk} = Resolver.resolve_stat_param("bLuk")
    end

    test "maps a trait stat constant to its stat atom" do
      assert {:ok, :pow} = Resolver.resolve_stat_param("bPow")
      assert {:ok, :crt} = Resolver.resolve_stat_param("bCrt")
    end

    test "lookup is case-insensitive" do
      assert {:ok, :int} = Resolver.resolve_stat_param("BINT")
    end

    test "a non-stat parameter is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "bMaxHP"}} = Resolver.resolve_stat_param("bMaxHP")
    end
  end

  describe "resolve_effect/1" do
    test "maps an EF_ constant to its effect atom" do
      assert {:ok, :heal2} = Resolver.resolve_effect("EF_HEAL2")
    end

    test "an EF_ name absent from the effect table is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "EF_NOPE"}} = Resolver.resolve_effect("EF_NOPE")
    end

    test "a non EF_ symbol is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "SC_BLESSING"}} = Resolver.resolve_effect("SC_BLESSING")
    end
  end

  defp source_catalogs(id, aegis, group) do
    Resolver.source_catalogs(
      [%{"Id" => id, "AegisName" => aegis}],
      [%{"Group" => group}]
    )
  end
end
