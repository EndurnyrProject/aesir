defmodule Aesir.ZoneServer.Integration.AssassinCrossSkillsIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ProductionResult
  alias Aesir.Net.SkillCast
  alias Aesir.Net.SkillCastFailed
  alias Aesir.Net.SkillDamage
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.ScriptVitals
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @assassin_cross 4_013
  @soul_destroyer 379
  @meteor_assault 406
  @create_deadly_poison 407
  @poison_bottle 678
  @poison_materials [937, 952, 939, 7033, 972, 657, 713]

  setup do
    Mimic.copy(HitCalculations)
    stub(HitCalculations, :calculate_hit_result, fn _attacker, _target -> :hit end)

    on_exit(fn ->
      for key <- [:forge_rng, :meteor_assault_rng, :soul_destroyer_rng],
          do: Application.delete_env(:zone_server, key)
    end)

    :ok
  end

  describe "Create Deadly Poison" do
    test "a successful brew adds a Poison Bottle" do
      Application.put_env(:zone_server, :forge_rng, fn 10_000 -> 1 end)
      assassin = start({150, 150}, %{@create_deadly_poison => 1}, items: @poison_materials)

      cast(assassin, @create_deadly_poison, 1, assassin.character.id)

      assert_receive {:packet_sent, %ProductionResult{success: true, item_id: @poison_bottle},
                      _channel},
                     1_000

      inventory = get_player_state(assassin.pid).inventory
      assert Inventory.held_amount(inventory, @poison_bottle) == 1
      assert Enum.all?(@poison_materials, &(Inventory.held_amount(inventory, &1) == 0))
    end

    test "a failed brew costs a quarter of max HP and reports the stuff insufficient" do
      Application.put_env(:zone_server, :forge_rng, fn 10_000 -> 10_000 end)
      assassin = start({150, 152}, %{@create_deadly_poison => 1}, items: @poison_materials)
      state = get_player_state(assassin.pid)
      loss = ScriptVitals.percent_of(state.stats.derived_stats.max_hp, 25)
      hp_before = state.stats.current_state.hp

      cast(assassin, @create_deadly_poison, 1, assassin.character.id)

      assert_receive {:packet_sent, %ProductionResult{success: false, item_id: @poison_bottle},
                      _channel},
                     1_000

      assert_receive {:packet_sent,
                      %SkillCastFailed{
                        skill_id: @create_deadly_poison,
                        reason: :SKILL_CAST_FAILURE_REASON_STUFF_INSUFFICIENT
                      }, _channel},
                     1_000

      assert hp(assassin.pid) == hp_before - loss
    end
  end

  describe "Meteor Assault" do
    test "strikes every adjacent monster and rides each with the drawn status" do
      Application.put_env(:zone_server, :meteor_assault_rng, fn 3 -> 2 end)
      Mimic.copy(Resistance)
      stub(Resistance, :roll_rate, fn _rate -> true end)

      assassin = start({140, 150}, %{@meteor_assault => 10})
      Mimic.allow(HitCalculations, self(), assassin.pid)
      Mimic.allow(Resistance, self(), assassin.pid)

      mobs =
        for x <- [141, 139] do
          start_mob_session(
            unit_id: 9_100_000 + x,
            map_name: @map,
            position: {x, 150},
            max_hp: 1_000_000,
            vit: 0,
            luk: 0
          )
        end

      cast(assassin, @meteor_assault, 10, assassin.character.id)

      for mob <- mobs do
        assert_eventually(fn -> get_mob_state(mob.pid).hp < 1_000_000 end)
        assert_eventually(fn -> StatusStorage.has_status?(:mob, mob.unit_id, :sc_stun) end)
      end
    end
  end

  describe "Soul Destroyer" do
    @tag game_mode: :pre_renewal, integration_re: false
    test "classic deals the weapon and INT parts as one hit and spends Lex Aeterna once" do
      Application.put_env(:zone_server, :soul_destroyer_rng, fn 500 -> 1 end)
      assassin = start({150, 150}, %{@soul_destroyer => 1})
      Mimic.allow(HitCalculations, self(), assassin.pid)

      mob =
        start_mob_session(
          unit_id: 9_100_152,
          map_name: @map,
          position: {152, 150},
          max_hp: 1_000_000,
          vit: 0,
          luk: 0
        )

      :ok = StatusInterpreter.apply_status(:mob, mob.unit_id, :sc_aeterna, [])

      cast(assassin, @soul_destroyer, 1, mob.unit_id)

      assert_receive {:packet_sent, %SkillDamage{skill_id: @soul_destroyer, damage: damage},
                      _channel},
                     1_000

      refute_receive {:packet_sent, %SkillDamage{skill_id: @soul_destroyer}, _channel}, 200
      # The INT part alone, doubled, is at least 2 * (500 + 5 * 10).
      assert damage >= 1_100
      assert_eventually(fn -> get_mob_state(mob.pid).hp == 1_000_000 - damage end)
      refute StatusStorage.has_status?(:mob, mob.unit_id, :sc_aeterna)
    end
  end

  defp cast(session, skill_id, level, target_id) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id
    })

    case GenServer.call(session.pid, :get_state).game_state.casting do
      %{token: token} -> send(session.pid, {:skill, {:cast_complete, token}})
      _instant -> :ok
    end

    _sync = get_player_state(session.pid)
    :ok
  end

  defp start({x, y}, skills, opts \\ []) do
    character = insert_character(skills)

    for nameid <- Keyword.get(opts, :items, []) do
      {:ok, _item} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: nameid,
          amount: 1,
          identify: 1,
          equip: 0
        })
    end

    session = start_player_session(character: character, map_name: @map, position: {x, y})

    raw =
      :sys.replace_state(session.pid, fn raw ->
        %{raw | game_state: %{raw.game_state | x: x, y: y, map_name: @map}}
      end)

    :ok = UnitRegistry.update_unit_state(:player, character.id, raw.game_state)
    :ok = SpatialIndex.update_unit_position(:player, character.id, x, y, @map)
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp insert_character(skills) do
    uniq = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "asc#{uniq}",
        userid: "asc#{uniq}",
        user_pass: "password",
        email: "asc#{uniq}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Asc#{uniq}",
        class: @assassin_cross,
        base_level: 99,
        job_level: 50,
        str: 80,
        agi: 1,
        vit: 0,
        int: 10,
        dex: 99,
        luk: 0,
        max_hp: 20_000,
        hp: 20_000,
        max_sp: 2_000,
        sp: 2_000,
        learned_skills: Map.new(skills, fn {id, level} -> {Integer.to_string(id), level} end),
        last_map: @map,
        last_x: 150,
        last_y: 150,
        save_map: @map,
        save_x: 150,
        save_y: 150
      })
      |> Repo.insert()

    character
  end

  defp hp(pid), do: get_player_state(pid).stats.current_state.hp
end
