defmodule Aesir.ZoneServer.Mmo.Woe.KnockbackGroundTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.ZoneServer.CombatTestHelper
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.Knockback
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Homunculus.Handlers.MovementHandler, as: HomunculusMovementHandler
  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Mob.Handlers.MovementHandler, as: MobMovementHandler
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.Handlers.MovementHandler, as: PlayerMovementHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :set_mimic_private
  setup :setup_ets_tables

  setup do
    :ok = MapFlags.reload()
  end

  test "off-hours castle ground and active GvG reject requests and commits for every owner" do
    for {map_name, active?} <- [{"aldeg_cas01", false}, {"prontera", true}] do
      if active?, do: :ok = MapFlags.set_runtime(map_name, :gvg, true)

      {player_id, player} = register_player(map_name, 150, 150)
      {mob_id, mob} = register_mob(map_name, 160, 150)
      {homunculus_id, homunculus} = register_homunculus(map_name, 170, 150)

      assert {:ok, {150, 150}} = Knockback.knockback(:player, player_id, 149, 150, 3)
      assert {:ok, {160, 150}} = Knockback.knockback(:mob, mob_id, 159, 150, 3)
      assert {:ok, {170, 150}} = Knockback.knockback(:homunculus, homunculus_id, 169, 150, 3)

      assert {:noreply, ^player} =
               PlayerMovementHandler.handle_knockback(150, 150, map_name, 153, 150, player)

      assert {:noreply, ^mob} =
               MobMovementHandler.handle_knockback(160, 150, map_name, 163, 150, mob)

      assert ^homunculus =
               HomunculusMovementHandler.knockback(
                 homunculus,
                 homunculus_id,
                 170,
                 150,
                 map_name,
                 173,
                 150
               )

      refute_received {:"$gen_cast", _request}

      {movable_x, movable_y} = if active?, do: {22, 202}, else: {1, 263}
      destination_x = movable_x + 1
      {movable_id, _movable} = register_mob(map_name, movable_x, movable_y)

      assert {:ok, {^destination_x, ^movable_y}} =
               Knockback.pull_to(:mob, movable_id, destination_x, movable_y)

      assert_received {:"$gen_cast",
                       {:movement,
                        {:displace, ^movable_x, ^movable_y, ^map_name, moved_x, ^movable_y}}}

      assert moved_x == destination_x

      assert {:ok, {^destination_x, ^movable_y}} =
               Knockback.relocate(:mob, movable_id, destination_x, movable_y)

      assert_received {:"$gen_cast",
                       {:movement,
                        {:relocate, ^movable_x, ^movable_y, ^map_name, moved_x, ^movable_y}}}

      assert moved_x == destination_x
    end
  end

  test "ordinary knockback uses its narrow tag while pull and relocation keep their tags" do
    {id, _state} = register_mob("prontera", 150, 150)

    assert {:ok, {152, 150}} = Knockback.knockback(:mob, id, 149, 150, 2)

    assert_received {:"$gen_cast", {:movement, {:knockback, 150, 150, "prontera", 152, 150}}}

    assert {:ok, {148, 150}} = Knockback.pull_to(:mob, id, 148, 150)
    assert_received {:"$gen_cast", {:movement, {:displace, 150, 150, "prontera", 148, 150}}}

    assert {:ok, {151, 150}} = Knockback.relocate(:mob, id, 151, 150)
    assert_received {:"$gen_cast", {:movement, {:relocate, 150, 150, "prontera", 151, 150}}}
  end

  test "queued ordinary requests are rejected when current maps become restricted" do
    {player_id, player} = register_player("prontera", 150, 150)
    {mob_id, mob} = register_mob("prontera", 160, 150)
    {homunculus_id, homunculus} = register_homunculus("prontera", 170, 150)

    assert {:ok, {152, 150}} = Knockback.knockback(:player, player_id, 149, 150, 2)
    assert {:ok, {162, 150}} = Knockback.knockback(:mob, mob_id, 159, 150, 2)
    assert {:ok, {172, 150}} = Knockback.knockback(:homunculus, homunculus_id, 169, 150, 2)

    assert_received {:"$gen_cast", {:movement, {:knockback, 150, 150, "prontera", 152, 150}}}

    assert_received {:"$gen_cast", {:movement, {:knockback, 160, 150, "prontera", 162, 150}}}

    assert_received {:"$gen_cast",
                     {:homunculus, {:knockback, ^homunculus_id, 170, 150, "prontera", 172, 150}}}

    :ok = MapFlags.set_runtime("prontera", :gvg, true)

    assert {:noreply, ^player} =
             PlayerMovementHandler.handle_knockback(150, 150, "prontera", 152, 150, player)

    assert {:noreply, ^mob} =
             MobMovementHandler.handle_knockback(160, 150, "prontera", 162, 150, mob)

    assert ^homunculus =
             HomunculusMovementHandler.knockback(
               homunculus,
               homunculus_id,
               170,
               150,
               "prontera",
               172,
               150
             )
  end

  test "ordinary-map handlers commit numeric destinations for every owner" do
    {_player_id, player} = register_player("prontera", 150, 150)
    {_mob_id, mob} = register_mob("prontera", 160, 150)
    {homunculus_id, homunculus} = register_homunculus("prontera", 170, 150)

    assert {:noreply, moved_player} =
             PlayerMovementHandler.handle_knockback(150, 150, "prontera", 152, 150, player)

    assert moved_player.game_state.x == 152

    assert {:noreply, moved_mob} =
             MobMovementHandler.handle_knockback(160, 150, "prontera", 162, 150, mob)

    assert moved_mob.x == 162

    moved_homunculus =
      HomunculusMovementHandler.knockback(
        homunculus,
        homunculus_id,
        170,
        150,
        "prontera",
        172,
        150
      )

    assert moved_homunculus.homunculus.x == 172
  end

  test "equipment-only skill distance is rejected by the central castle-ground gate" do
    {target_id, target_state} = register_mob("aldeg_cas01", 151, 150)

    attacker =
      CombatTestHelper.create_player_combatant(position: {150, 150})
      |> Map.put(:equip_modifiers, %{{:add_skill_blow, 18} => 2})

    target = MobState.to_combatant(target_state)
    result = %{hit?: true, target_survives?: true, coma?: false}

    assert target.unit_id == target_id
    assert {:ok, {151, 150}} = Knockback.skill(attacker, target, 18, result)
    refute_received {:"$gen_cast", _request}
  end

  defp register_player(map_name, x, y) do
    id = :erlang.unique_integer([:positive])

    state =
      PlayerStateFixture.build(%{
        character_id: id,
        account_id: id,
        process_pid: self(),
        map_name: map_name,
        x: x,
        y: y,
        walk_path: [],
        stats: %{}
      })

    :ok = UnitRegistry.register_unit(:player, id, PlayerState, state, self())
    :ok = SpatialIndex.add_unit(:player, id, x, y, map_name)
    {id, %SessionState{game_state: state, connection_pid: self()}}
  end

  defp register_mob(map_name, x, y) do
    id = :erlang.unique_integer([:positive])
    state = mob_state(id, map_name, x, y)
    :ok = UnitRegistry.register_unit(:mob, id, MobState, state, self())
    :ok = SpatialIndex.add_unit(:mob, id, x, y, map_name)
    {id, state}
  end

  defp register_homunculus(map_name, x, y) do
    {_owner_id, owner} = register_player(map_name, x - 1, y)
    id = :erlang.unique_integer([:positive])

    homunculus = %HomunculusState{
      id: id,
      owner_character_id: owner.game_state.character_id,
      owner_session_pid: self(),
      class_id: 6001,
      name: "Lif",
      lifecycle: :active,
      hp: 100,
      max_hp: 100,
      world_gid: id,
      map_name: map_name,
      x: x,
      y: y
    }

    :ok = UnitRegistry.register_unit(:homunculus, id, HomunculusState, homunculus, self())
    :ok = SpatialIndex.add_unit(:homunculus, id, x, y, map_name)
    {id, %{owner | homunculus: homunculus}}
  end

  defp mob_state(id, map_name, x, y) do
    %MobState{
      instance_id: id,
      mob_id: 1002,
      mob_data: %MobDefinition{
        id: 1002,
        aegis_name: "PORING",
        name: "Poring",
        level: 1,
        hp: 100,
        stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 1, luk: 1},
        attack_range: 1,
        size: :medium,
        race: :plant,
        element: {:water, 1},
        walk_speed: 400,
        attack_delay: 1_000,
        attack_motion: 500,
        client_attack_motion: 500,
        damage_motion: 400,
        modes: []
      },
      spawn_ref: %{},
      x: x,
      y: y,
      map_name: map_name,
      hp: 100,
      max_hp: 100,
      sp: 50,
      max_sp: 50,
      spawned_at: 0
    }
  end
end
