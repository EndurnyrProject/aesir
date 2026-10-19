defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzEstimationTest do
  use ExUnit.Case, async: true

  import Mimic

  alias Aesir.Commons.GameMode
  alias Aesir.Net.EstimationResult
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.EstimationView
  alias Aesir.ZoneServer.Mmo.Skills.Wizard.WzEstimation
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.Member
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @caster_id 100
  @target_id 200

  setup :verify_on_exit!

  defp mode_value(renewal, pre_renewal) do
    %{renewal: renewal, pre_renewal: pre_renewal}[GameMode.mode()]
  end

  describe "EstimationView.result/2" do
    test "builds the exact live monster payload" do
      result = EstimationView.result(@target_id, target())

      assert %EstimationResult{
               target_id: @target_id,
               class_id: 1097,
               level: 42,
               size: 2,
               hp: 1_234,
               def: 88,
               race: 8,
               mdef: 44,
               element: 3,
               server_tick: server_tick
             } = result

      modifiers =
        Map.take(result, [
          :water_modifier,
          :earth_modifier,
          :fire_modifier,
          :wind_modifier,
          :poison_modifier,
          :holy_modifier,
          :shadow_modifier,
          :ghost_modifier,
          :undead_modifier
        ])

      assert modifiers ==
               mode_value(
                 %{
                   water_modifier: 150,
                   earth_modifier: 90,
                   fire_modifier: 25,
                   wind_modifier: 100,
                   poison_modifier: 150,
                   holy_modifier: 100,
                   shadow_modifier: 100,
                   ghost_modifier: 100,
                   undead_modifier: 90
                 },
                 %{
                   water_modifier: 150,
                   earth_modifier: 50,
                   fire_modifier: 25,
                   wind_modifier: 100,
                   poison_modifier: 125,
                   holy_modifier: 100,
                   shadow_modifier: 100,
                   ghost_modifier: 100,
                   undead_modifier: 100
                 }
               )

      assert is_integer(server_tick)
    end
  end

  describe "cast/4" do
    test "delivers the result to the caster session alone without a party" do
      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id -> {:ok, {MobState, target(), self()}}
        :player, @caster_id -> {:ok, {PlayerState, caster(), self()}}
      end)

      assert {:ok, %PlayerState{character_id: @caster_id}} =
               WzEstimation.cast(caster(), {:unit, @target_id}, 1, WzEstimation.definition())

      assert_received {:"$gen_cast", {:send_packet, %EstimationResult{target_id: @target_id}}}
      refute_received {:"$gen_cast", {:send_packet, _other}}
    end

    test "delivers the result to every same-map party member" do
      caster = %{caster() | party_id: 7, map_name: "prontera"}

      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id ->
          {:ok, {MobState, target(), self()}}

        :player, 100 ->
          {:ok, {PlayerState, caster, self()}}

        :player, 201 ->
          {:ok, {PlayerState, %{caster | character_id: 201}, self()}}

        :player, 202 ->
          {:ok, {PlayerState, %{caster | character_id: 202, map_name: "geffen"}, self()}}
      end)

      stub(PartyManager, :get, fn 7 ->
        {:ok,
         %PartyState{
           party_id: 7,
           name: "Party",
           leader_char_id: 100,
           exp_share: true,
           item_pickup_share: true,
           members: %{
             100 => member(100),
             201 => member(201),
             202 => member(202),
             203 => %{member(203) | online: false}
           }
         }}
      end)

      assert {:ok, %PlayerState{character_id: 100}} =
               WzEstimation.cast(caster, {:unit, @target_id}, 1, WzEstimation.definition())

      # The caster and the same-map online member; not the member on another map
      # nor the offline one.
      assert_received {:"$gen_cast", {:send_packet, %EstimationResult{target_id: @target_id}}}
      assert_received {:"$gen_cast", {:send_packet, %EstimationResult{target_id: @target_id}}}
      refute_received {:"$gen_cast", {:send_packet, _other}}
    end

    # The reference charges the completed cast and then reports the failure, so
    # a non-monster target passes validation and fails in the behavior.
    test "a player target validates, then fails the completed cast" do
      stub(UnitRegistry, :unit_id_exists?, fn @target_id -> true end)

      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id -> {:error, :not_found}
        :player, @caster_id -> {:ok, {PlayerState, caster(), self()}}
      end)

      assert :ok =
               WzEstimation.validate(caster(), {:unit, @target_id}, 1, WzEstimation.definition())

      assert {:failed, %PlayerState{character_id: @caster_id}, :invalid_target} =
               WzEstimation.cast(caster(), {:unit, @target_id}, 1, WzEstimation.definition())
    end

    test "a vanished target is refused before anything is spent" do
      stub(UnitRegistry, :unit_id_exists?, fn _target_id -> false end)

      assert {:error, :invalid_target} =
               WzEstimation.validate(caster(), {:unit, @target_id}, 1, WzEstimation.definition())
    end

    test "fails loudly when the target disappears before cast completion" do
      stub(UnitRegistry, :unit_id_exists?, fn _target_id -> false end)

      stub(UnitRegistry, :get_unit, fn
        :mob, @target_id -> {:error, :not_found}
        :player, @caster_id -> {:ok, {PlayerState, caster(), self()}}
      end)

      assert {:error, :target_not_found} =
               WzEstimation.cast(caster(), {:unit, @target_id}, 1, WzEstimation.definition())
    end
  end

  defp caster do
    %PlayerState{character_id: @caster_id}
  end

  defp member(char_id) do
    %Member{char_id: char_id, name: "Member", base_level: 1, online: true}
  end

  defp target do
    mob_data = %MobDefinition{
      id: 1097,
      aegis_name: "TEST_MOB",
      name: "Test Mob",
      level: 42,
      hp: 9_999,
      def: 88,
      mdef: 44,
      atk: 100,
      atk2: 100,
      matk: 0,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
      attack_range: 1,
      size: :large,
      race: :demon,
      element: {:fire, 1},
      walk_speed: 200,
      attack_delay: 1_000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400
    }

    %MobState{
      instance_id: @target_id,
      mob_id: mob_data.id,
      mob_data: mob_data,
      spawn_ref: %MobSpawn{
        mob: mob_data.id,
        amount: 1,
        respawn_time: 1_000,
        spawn_area: %MobSpawn.SpawnArea{x: 10, y: 10, xs: 0, ys: 0}
      },
      x: 10,
      y: 10,
      map_name: "prontera",
      hp: 1_234,
      sp: 0,
      spawned_at: 0
    }
    |> Aesir.TestMob.publish(max_hp: mob_data.hp, max_sp: 0)
  end
end
