defmodule Aesir.ZoneServer.Mmo.Skills.LordKnight.LkAurabladeTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Caster.Player, as: PlayerCaster
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.LordKnight.LkAurablade
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.Stats.Equipment
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup do
    Aesir.TestEtsSetup.setup_ets_tables(%{})
    :ok
  end

  test "a sword caster applies Aura Blade" do
    assert {:ok, definition} = Catalog.by_name(:lk_aurablade)

    player = player()
    assert {:error, :wrong_weapon} = PlayerCaster.check_weapon(player, definition)
    sword = put_in(player.stats.equipment, %Equipment{right_hand: 1101})
    assert :ok = PlayerCaster.check_weapon(sword, definition)
    :ok = UnitRegistry.register_player(sword, self())

    assert {:ok, ^sword} = LkAurablade.cast(sword, :self, 3, definition)
    assert %{val1: 3} = StatusStorage.get_status(:player, sword.character_id, :sc_aurablade)
  end

  test "both modes accept a listed bow but reject bare fists" do
    bow = put_in(player().stats.equipment, %Equipment{right_hand: 1701})

    for mode <- [:renewal, :pre_renewal] do
      definition = LkAurablade.definition(mode)
      assert :bow in definition.require_weapon
      assert :knuckle in definition.require_weapon
      refute :fist in definition.require_weapon
      assert :ok = PlayerCaster.check_weapon(bow, definition)
    end
  end

  defp player do
    PlayerState.new(%Character{
      id: 5_001,
      account_id: 5_002,
      name: "LK",
      last_map: "prontera",
      last_x: 50,
      last_y: 50,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 90,
      job_level: 50,
      class: 7
    })
  end
end
