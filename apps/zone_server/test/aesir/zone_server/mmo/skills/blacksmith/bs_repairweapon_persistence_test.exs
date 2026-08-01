defmodule Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsRepairweaponPersistenceTest do
  use Aesir.DataCase, async: true

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.InventoryItem
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsRepairweapon
  alias Aesir.ZoneServer.Unit.Player.Handlers.InventoryStaging
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  test "repairs the caster's own row before consuming the material" do
    character = insert_character()
    broken = insert_item(character.id, 1101, 1)
    material = insert_item(character.id, 1_002, 0)

    caster = %PlayerState{
      character_id: character.id,
      process_pid: self(),
      target_id: character.id,
      inventory: %{3 => broken, 9 => material},
      pending_inventory_persist: [],
      map_name: "repair_test",
      x: 10,
      y: 10
    }

    assert {:ok, repaired} =
             BsRepairweapon.on_menu_reply(caster, %{id: 3, extras: []}, 1)

    assert repaired.inventory[3].attribute == 0
    refute Map.has_key?(repaired.inventory, 9)
    assert Repo.get!(InventoryItem, broken.id).attribute == 0

    assert repaired.pending_inventory_notify == [{:added, 3, repaired.inventory[3]}]

    InventoryStaging.drain(self(), repaired)
    refute Repo.get(InventoryItem, material.id)

    assert_receive {:send, :gameplay,
                    {:item_added, %Aesir.Net.ItemAdded{nameid: 1101, attribute: 0}}}
  end

  defp insert_character do
    uniq = System.unique_integer([:positive])

    account =
      %Account{}
      |> Account.changeset(%{
        username: "repair#{uniq}",
        userid: "repair#{uniq}",
        user_pass: "password",
        email: "repair#{uniq}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "Repair#{uniq}",
      class: 10,
      base_level: 20,
      job_level: 20
    })
    |> Repo.insert!()
  end

  defp insert_item(character_id, item_id, attribute) do
    %InventoryItem{}
    |> InventoryItem.changeset(%{
      char_id: character_id,
      nameid: item_id,
      amount: 1,
      attribute: attribute,
      equip: 0
    })
    |> Repo.insert!()
  end
end
