defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoKitranslationTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoKitranslation
  alias Aesir.ZoneServer.Party.Manager
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :setup_ets_tables
  setup :verify_on_exit!

  setup do
    Catalog.reload()
    :ok
  end

  test "catalog exposes the verified quest-skill definition" do
    assert {:ok, definition} = Catalog.by_id(1_015)
    assert definition.name == :mo_kitranslation
    assert definition.target_type == :target_ally
    assert definition.range == 9
    assert definition.sp_cost == [40]
    assert definition.sphere_cost == [1]
    assert definition.cast_time == [1_000]
    assert definition.fixed_cast_time == [1_000]
    assert definition.after_cast_delay == [1_000]
  end

  test "an eligible party target produces the post-commit transfer descriptor" do
    source = player_state(1, party_id: 10) |> with_sphere()
    target = player_state(2, party_id: 10)
    :ok = UnitRegistry.register_player(target, self())
    :ok = SpatialIndex.add_unit(:player, 2, 50, 50, "prontera")

    assert :ok =
             MoKitranslation.validate(source, {:unit, 2}, 1, MoKitranslation.definition())

    assert {:deferred, ^source,
            %Interpreter.Deferred{
              effect: {:transfer_sphere, 2},
              cost: %Cost{sp: 40, spheres: 1},
              skill_id: 1_015
            }} = Interpreter.cast(source, 1_015, 1, {:unit, 2})
  end

  test "the session commits Ki costs before sending its single delivery" do
    Mimic.copy(Broadcast)
    Mimic.copy(CharacterPersistence)
    Mimic.copy(Manager)
    Mimic.copy(PlayerStats)
    Mimic.copy(StatusSync)
    Mimic.copy(UnitRegistry)
    stub_commit()

    source = player_state(1, party_id: 10) |> with_sphere()
    target = player_state(2, party_id: 10)
    :ok = UnitRegistry.register_player(target, self())
    :ok = SpatialIndex.add_unit(:player, 2, 50, 50, "prontera")
    state = %SessionState{connection_pid: self(), game_state: source}

    assert {:noreply, casting} = SkillHandler.handle_use_skill(state, 1_015, 1, 2)
    token = casting.game_state.casting.token
    Process.cancel_timer(casting.game_state.casting.timer_ref)

    assert {:noreply, settled} = SkillHandler.handle_cast_complete(casting, token)
    assert settled.game_state.stats.current_state.sp == 60
    assert SpiritSpheres.count(settled.game_state.spirit_spheres) == 0

    assert_receive {:"$gen_cast", {:receive_spirit_sphere, %{source_id: 1, target_id: 2}}}
  end

  test "changed party, full targets, and coin-user jobs are rejected" do
    source = player_state(1, party_id: 10) |> with_sphere()

    targets = [
      player_state(2, party_id: 11),
      player_state(2, party_id: 10, job_id: 24),
      player_state(2, party_id: 10) |> with_spheres(5)
    ]

    for target <- targets do
      :ok = UnitRegistry.register_player(target, self())

      assert {:error, :invalid_target} =
               MoKitranslation.validate(source, {:unit, 2}, 1, MoKitranslation.definition())
    end
  end

  defp player_state(id, opts) do
    base =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Player #{id}",
        last_map: Keyword.get(opts, :map_name, "prontera"),
        last_x: 50,
        last_y: 50,
        sex: "M",
        str: 1,
        agi: 1,
        vit: 1,
        int: 1,
        dex: 1,
        luk: 1,
        base_level: 1,
        job_level: 1,
        class: Keyword.get(opts, :job_id, 15)
      })

    stats =
      base.stats
      |> put_in([Access.key!(:current_state), Access.key!(:sp)], 100)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_sp)], 100)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], %{1_015 => 1})

    %{base | stats: stats, party_id: Keyword.get(opts, :party_id, 0)}
  end

  defp with_sphere(state), do: with_spheres(state, 1)

  defp with_spheres(state, count) do
    spheres =
      Enum.reduce(1..count, state.spirit_spheres, fn _, spheres ->
        {spheres, _entry} = SpiritSpheres.summon(spheres, 60_000, 5)
        spheres
      end)

    %{state | spirit_spheres: spheres}
  end

  defp stub_commit do
    stub(Broadcast, :to_player, fn _id, _packet -> :ok end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet -> :ok end)
    stub(Broadcast, :to_in_range, fn _map, _x, _y, _range, _packet, _opts -> :ok end)
    stub(Broadcast, :to_visible_players, fn _state, _packet, _opts -> :ok end)
    stub(PlayerStats, :calculate_stats, fn stats, _id, _equipped -> stats end)
    stub(UnitRegistry, :update_unit_state, fn :player, 1, _state -> :ok end)
    stub(StatusSync, :send_stat_updates, fn _connection, _stats -> :ok end)
    stub(CharacterPersistence, :update_character, fn 1, _attrs, _opts -> {:ok, %{}} end)
    stub(Manager, :sync_member, fn 10, 1, _member -> {:ok, %{}} end)
  end
end
