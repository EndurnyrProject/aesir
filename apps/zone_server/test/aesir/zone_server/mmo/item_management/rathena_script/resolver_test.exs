defmodule Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.ResolverTest do
  use ExUnit.Case, async: false

  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.Items
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Resolver

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

  describe "resolve_item/1" do
    setup do
      potion = %ItemDefinition{
        id: 501,
        aegis_name: "Red_Potion",
        name: "Red Potion",
        type: :healing
      }

      index = %{
        all: [potion],
        by_id: %{501 => potion},
        by_aegis: %{"Red_Potion" => potion}
      }

      :persistent_term.put(Items, index)
      on_exit(fn -> :persistent_term.erase(Items) end)
      :ok
    end

    test "resolves an aegis name to its item id" do
      assert {:ok, 501} = Resolver.resolve_item("Red_Potion")
    end

    test "resolves a numeric item id" do
      assert {:ok, 501} = Resolver.resolve_item(501)
    end

    test "unknown item is an unknown_symbol error" do
      assert {:error, {:unknown_symbol, "Nope_Item"}} = Resolver.resolve_item("Nope_Item")
    end
  end

  describe "resolve_class/1" do
    test "maps Job_Swordman to :swordman" do
      assert {:ok, :swordman} = Resolver.resolve_class("Job_Swordman")
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
end
