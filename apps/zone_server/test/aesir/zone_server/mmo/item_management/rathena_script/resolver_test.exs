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
end
