defmodule Aesir.ZoneServer.Mmo.StatusEffect.AdrenalineApplicationTest do
  use ExUnit.Case, async: true

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skills.Blacksmith.BsAdrenaline
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Script.Ctx
  alias Aesir.ZoneServer.Script.Dsl
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup {Aesir.TestEtsSetup, :setup_ets_tables}

  test "direct script starts retain self identity, recipient strength and Hilt Binding duration" do
    for {id, hilt_binding, duration} <- [{1, 0, 150_000}, {2, 1, 165_000}] do
      player = player(id, 1301, hilt_binding)
      :ok = UnitRegistry.register_player(player, self())

      ctx = %Ctx{
        char_id: id,
        account_id: id,
        connection_pid: self(),
        game_state: player,
        source: {:item, 12220}
      }

      assert Dsl.sc_start(ctx, :sc_adrenaline, 150_000, 5).status == :ok
      entry = StatusStorage.get_status(:player, id, :sc_adrenaline)
      assert entry.source_id == id
      assert entry.val2 == 0
      assert entry.val3 == 200
      assert entry.expires_at - entry.started_at == duration
    end
  end

  test "Quagmire and Decrease AGI refuse new Adrenaline applications" do
    for {id, blocker} <- [{3, :sc_quagmire}, {4, :sc_decreaseagi}] do
      :ok = UnitRegistry.register_player(player(id, 1301, 0), self())
      :ok = StatusStorage.apply_status(:player, id, blocker, duration: 30_000)

      assert {:error, :prevented} =
               Interpreter.apply_status(:player, id, :sc_adrenaline,
                 caster_id: id,
                 val1: 5,
                 duration: 150_000
               )

      refute StatusStorage.has_status?(:player, id, :sc_adrenaline)
    end
  end

  test "direct status starts refuse invalid weapons" do
    for {id, weapon} <- [{5, 1201}, {6, nil}] do
      :ok = UnitRegistry.register_player(player(id, weapon, 0), self())

      assert {:error, :wrong_weapon} =
               Interpreter.apply_status(:player, id, :sc_adrenaline,
                 caster_id: id,
                 val1: 5,
                 duration: 150_000
               )

      refute StatusStorage.has_status?(:player, id, :sc_adrenaline)
    end
  end

  test "ordinary skill casts apply Hilt Binding exactly once and retain own-cast strength" do
    caster = player(7, 1301, 1)
    :ok = UnitRegistry.register_player(caster, self())
    {:ok, definition} = Catalog.by_id(111)

    assert {:ok, ^caster} = BsAdrenaline.cast(caster, :self, 5, definition)
    entry = StatusStorage.get_status(:player, 7, :sc_adrenaline)
    assert entry.expires_at - entry.started_at == 165_000
    assert entry.val2 == 1
    assert entry.val3 == 300

    assert {:error, :overlap_refused} =
             Interpreter.apply_status(:player, 7, :sc_adrenaline,
               caster_id: 7,
               val1: 5,
               val2: 0,
               duration: 150_000
             )

    assert StatusStorage.get_status(:player, 7, :sc_adrenaline) == entry
  end

  defp player(id, weapon, hilt_binding) do
    player =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Adrenaline#{id}",
        sex: "M",
        class: 10,
        base_level: 99,
        job_level: 50,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        hp: 500,
        sp: 500,
        last_map: "prontera",
        learned_skills: %{"105" => hilt_binding}
      })

    put_in(player.stats.equipment.right_hand, weapon)
  end
end
