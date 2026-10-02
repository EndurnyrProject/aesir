defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.GospelTest do
  use ExUnit.Case, async: false

  import Aesir.TestEtsSetup
  import Mimic

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.Gospel
  alias Aesir.ZoneServer.Mmo.StatusEffect.Effects.GospelSlow
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Registry
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 44_001

  setup :setup_ets_tables
  setup :set_mimic_private
  setup :verify_on_exit!

  setup do
    :ok = UnitRegistry.register_player(player(@caster_id), self())
    :ok
  end

  defp player(id) do
    PlayerState.new(%Character{
      id: id,
      account_id: id,
      name: "Paladin #{id}",
      last_map: "prontera",
      last_x: 100,
      last_y: 100,
      sex: "M",
      str: 1,
      agi: 1,
      vit: 1,
      int: 1,
      dex: 1,
      luk: 1,
      base_level: 90,
      job_level: 50,
      class: 4015
    })
  end

  describe "sc_gospel upkeep" do
    test "levels 1-5 charge 30 HP and 20 SP every tick; levels 6-10 charge 45 and 35" do
      test_pid = self()

      stub(PlayerSession, :try_consume_vitals, fn _pid, opts ->
        send(test_pid, {:charged, opts})
        :ok
      end)

      entry = %StatusEntry{type: :sc_gospel, val1: 5}
      assert {:ok, ^entry} = Gospel.on_tick({:player, @caster_id}, entry, %{})
      assert_received {:charged, hp: 30, sp: 20}

      entry = %StatusEntry{type: :sc_gospel, val1: 6}
      assert {:ok, ^entry} = Gospel.on_tick({:player, @caster_id}, entry, %{})
      assert_received {:charged, hp: 45, sp: 35}
    end

    test "ends the chant when the upkeep cannot be paid" do
      stub(PlayerSession, :try_consume_vitals, fn _pid, _opts -> {:error, :insufficient} end)

      assert :remove = Gospel.on_tick({:player, @caster_id}, %StatusEntry{val1: 1}, %{})
    end

    test "expiry requests asynchronous teardown of the field" do
      test_pid = self()

      stub(Unit, :destroy_async, fn group_id ->
        send(test_pid, {:destroyed, group_id})
        :ok
      end)

      assert :ok = Gospel.on_expire({:player, @caster_id}, %StatusEntry{val2: 77}, %{})
      assert_received {:destroyed, 77}
    end

    test "roots the caster and allows only Gospel itself" do
      :ok = StatusStorage.apply_status(:player, @caster_id, :sc_gospel, val1: 1, val2: 1)

      refute Interpreter.can_move?(:player, @caster_id)
      assert Interpreter.can_use_skill?(:player, @caster_id, 369)
      refute Interpreter.can_use_skill?(:player, @caster_id, 5)
    end
  end

  describe "sc_gospel_slow" do
    @tag game_mode: :renewal
    test "renewal slows movement by 75 and attack speed by 75 rate" do
      assert GospelSlow.modifiers(%StatusEntry{}, %{}) == %{movement_speed: 75, aspd_rate: -75}
    end

    @tag game_mode: :pre_renewal
    test "classic slows movement by 75 and attack speed by 25 rate" do
      assert GospelSlow.modifiers(%StatusEntry{}, %{}) == %{movement_speed: 75, aspd_rate: -25}
    end

    test "cannot land on a chanting caster" do
      :ok = StatusStorage.apply_status(:player, @caster_id, :sc_gospel, val1: 1, val2: 1)

      assert {:error, :prevented} =
               Interpreter.apply_status(:player, @caster_id, :sc_gospel_slow,
                 val1: 1,
                 duration: 20_000
               )
    end

    test "is a debuff sharing the Gospel icon" do
      assert %{properties: properties, icon: :gospel} = Registry.get_definition(:sc_gospel_slow)
      assert :debuff in properties
    end
  end
end
