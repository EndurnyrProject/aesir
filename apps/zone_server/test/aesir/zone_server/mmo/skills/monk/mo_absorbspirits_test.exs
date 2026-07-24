defmodule Aesir.ZoneServer.Mmo.Skills.Monk.MoAbsorbspiritsTest do
  use ExUnit.Case, async: false
  use Mimic

  import Aesir.TestEtsSetup

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.CharacterPersistence
  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.Skills.Monk.MoAbsorbspirits
  alias Aesir.ZoneServer.Unit.Broadcast
  alias Aesir.ZoneServer.Unit.Player.Handlers.SkillHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SessionState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.Player.Stats, as: PlayerStats
  alias Aesir.ZoneServer.Unit.Player.StatusSync
  alias Aesir.ZoneServer.Unit.UnitRegistry

  setup :verify_on_exit!
  setup :setup_ets_tables

  setup do
    Mimic.copy(TargetResolver)
    Mimic.copy(Targeting)
    Catalog.reload()
    :ok
  end

  test "catalog exposes the verified Renewal definition" do
    assert {:ok, definition} = Catalog.by_id(262)
    assert definition.name == :mo_absorbspirits
    assert definition.target_type == :target_any
    assert definition.range == 9
    assert definition.sp_cost == [5]
    assert definition.fixed_cast_time == [500]
  end

  test "self absorption clears every sphere and defers cost-before-reward settlement" do
    game_state = player_state(1, 100, %{262 => 1}) |> with_spheres(2)

    assert {:deferred, effect_state,
            %Interpreter.Deferred{
              effect: {:absorb_local, 14},
              cost: %Cost{sp: 5},
              skill_id: 262
            }} = Interpreter.cast(game_state, 262, 1, :self)

    assert SpiritSpheres.count(effect_state.spirit_spheres) == 0
    assert effect_state.stats.current_state.sp == 100
  end

  test "self absorption charges five SP before applying the capped reward through the session" do
    Mimic.copy(Broadcast)
    Mimic.copy(CharacterPersistence)
    Mimic.copy(PlayerStats)
    Mimic.copy(StatusSync)
    Mimic.copy(UnitRegistry)
    stub_commit()

    game_state = player_state(1, 100, %{262 => 1}) |> with_spheres(2)
    state = %SessionState{connection_pid: self(), game_state: game_state}

    assert {:noreply, casting} = SkillHandler.handle_use_skill(state, 262, 1, 1)
    token = casting.game_state.casting.token
    Process.cancel_timer(casting.game_state.casting.timer_ref)

    assert {:noreply, settled} = SkillHandler.handle_cast_complete(casting, token)
    assert settled.game_state.stats.current_state.sp == 100
    assert SpiritSpheres.count(settled.game_state.spirit_spheres) == 0
  end

  test "monster absorption returns twice the level on the verified twenty-percent roll" do
    target = %{mob_data: %{level: 12, modes: []}, is_dead: false}
    stub(TargetResolver, :resolve, fn 10 -> {:ok, self(), target, :mob} end)
    stub(TargetResolver, :ensure_targetable, fn ^target, :mob -> :ok end)
    :rand.seed(:exsss, {3, 2, 3})

    assert {:deferred, _state, {:absorb_local, 24}} =
             MoAbsorbspirits.cast(
               player_state(1, 20),
               {:unit, 10},
               1,
               MoAbsorbspirits.definition()
             )
  end

  test "monster absorption still settles its cost when the roll misses" do
    target = %{mob_data: %{level: 12, modes: []}, is_dead: false}
    stub(TargetResolver, :resolve, fn 10 -> {:ok, self(), target, :mob} end)
    :rand.seed(:exsss, {1, 2, 3})

    assert {:deferred, _state, {:absorb_local, 0}} =
             MoAbsorbspirits.cast(
               player_state(1, 20),
               {:unit, 10},
               1,
               MoAbsorbspirits.definition()
             )
  end

  test "status-immune monsters are rejected" do
    target = %{mob_data: %{level: 12, modes: [:status_immune]}, is_dead: false}
    stub(TargetResolver, :resolve, fn 10 -> {:ok, self(), target, :mob} end)
    stub(TargetResolver, :ensure_targetable, fn ^target, :mob -> :ok end)

    assert {:error, :invalid_target} =
             MoAbsorbspirits.validate(
               player_state(1, 20),
               {:unit, 10},
               1,
               MoAbsorbspirits.definition()
             )
  end

  test "coin-class players are rejected before the PvP check" do
    target =
      put_in(
        player_state(2, 20),
        [
          Access.key!(:stats),
          Access.key!(:progression),
          Access.key!(:job_id)
        ],
        24
      )

    stub(TargetResolver, :resolve, fn 2 -> {:ok, self(), target, :player} end)
    stub(TargetResolver, :ensure_targetable, fn ^target, :player -> :ok end)
    reject(&Targeting.validate_enemy/2)

    assert {:error, :invalid_target} =
             MoAbsorbspirits.validate(
               player_state(1, 20),
               {:unit, 2},
               1,
               MoAbsorbspirits.definition()
             )
  end

  defp player_state(id, sp, learned \\ %{}) do
    base =
      PlayerState.new(%Character{
        id: id,
        account_id: id,
        name: "Monk",
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
        base_level: 1,
        job_level: 1,
        class: 15
      })

    stats =
      base.stats
      |> put_in([Access.key!(:current_state), Access.key!(:sp)], sp)
      |> put_in([Access.key!(:derived_stats), Access.key!(:max_sp)], 100)
      |> put_in([Access.key!(:progression), Access.key!(:learned_skills)], learned)

    %{base | stats: stats}
  end

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
  end
end
