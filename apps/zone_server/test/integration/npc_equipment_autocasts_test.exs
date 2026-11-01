defmodule Aesir.ZoneServer.Integration.NpcEquipmentAutocastsTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.ActionRequest
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat.HitCalculations
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.ItemManagement.RathenaScript.Transpiler
  alias Aesir.ZoneServer.Mmo.MobSkill.Executor
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence

  @moduletag :capture_log
  @map "prontera"
  @attack_item 991_201
  @counter_item 991_202
  @skill_item 991_203

  setup do
    Mimic.copy(ItemManagement)
    Mimic.copy(HitCalculations)
    Mimic.copy(Resistance)
    stub(HitCalculations, :calculate_hit_result, fn _, _ -> :hit end)
    stub(Resistance, :roll_rate, fn _ -> true end)

    items =
      Map.new(
        [
          {@attack_item, "bonus3 bAutoSpell,\"NPC_CRITICALWOUND\",2,1000;"},
          {@counter_item, "bonus3 bAutoSpellWhenHit,\"NPC_WIDESILENCE\",2,1000;"},
          {@skill_item, "bonus4 bAutoSpellOnSkill,\"SM_BASH\",\"NPC_WIDEBLEEDING\",1,1000;"}
        ],
        fn {id, script} ->
          {:ok, program} = Transpiler.transpile_equip(script)

          {id,
           %ItemDefinition{
             id: id,
             aegis_name: "NPC_PROC_#{id}",
             name: "NPC Proc #{id}",
             type: :armor,
             locations: [:armor],
             on_equip: program
           }}
        end
      )

    stub(ItemManagement, :get_item_by_id, fn id ->
      case Map.fetch(items, id) do
        {:ok, item} -> {:ok, item}
        :error -> call_original(ItemManagement, :get_item_by_id, [id])
      end
    end)

    :ok = MapFlags.set_runtime(@map, :pvp, true)
    on_exit(fn -> MapFlags.clear_runtime(@map, :pvp) end)
    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "a normal attack triggers Critical Wounds in the wearer's real session" do
    attacker = player("WoundAtk", @attack_item, {150, 150})
    target = player("WoundDef", nil, {151, 150})

    simulate_incoming_message(attacker.pid, %ActionRequest{
      target_id: target.character.id,
      action: 0
    })

    assert_eventually(fn ->
      match?(
        %{val1: 2, val2: 40, source_id: id} when id == attacker.character.id,
        StatusStorage.get_status(:player, target.character.id, :sc_criticalwound)
      )
    end)
  end

  test "a when-hit wide proc centers on its wearer and reaches nearby PvP enemies" do
    attacker = player("WideAtk", nil, {150, 150})
    wearer = player("WideDef", @counter_item, {151, 150})
    observer = player("WideAlly", nil, {152, 150})

    simulate_incoming_message(attacker.pid, %ActionRequest{
      target_id: wearer.character.id,
      action: 0
    })

    assert_eventually(fn ->
      StatusStorage.has_status?(:player, attacker.character.id, :sc_silence)
    end)

    assert_eventually(fn ->
      StatusStorage.has_status?(:player, observer.character.id, :sc_silence)
    end)

    refute StatusStorage.has_status?(:player, wearer.character.id, :sc_silence)
    assert Process.alive?(wearer.pid)
    assert Process.alive?(observer.pid)
  end

  test "an on-skill wide proc retains its implicit self target rather than the triggering enemy" do
    attacker = player("SkillAtk", @skill_item, {150, 150})
    target = player("SkillDef", nil, {151, 150})
    edge = player("SkillEdge", nil, {148, 150})
    outside = player("SkillFar", nil, {153, 150})

    simulate_incoming_message(attacker.pid, %SkillCast{
      skill_id: 5,
      level: 1,
      target_id: target.character.id
    })

    assert_eventually(fn ->
      match?(
        %{source_id: id, source_type: :player} when id == attacker.character.id,
        StatusStorage.get_status(:player, target.character.id, :sc_bleeding)
      )
    end)

    assert_eventually(fn ->
      StatusStorage.has_status?(:player, edge.character.id, :sc_bleeding)
    end)

    refute StatusStorage.has_status?(:player, outside.character.id, :sc_bleeding)
  end

  test "mob rows dispatch the same weapon and wide skills with monster source identity" do
    target = player("MobTarget", nil, {152, 150})
    mob = start_mob_session(position: {150, 150}, level: 99, atk: 1, atk2: 1, vit: 0, luk: 0)
    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    MobSession.set_target(mob.pid, {:player, target.character.id})

    assert :ok =
             Executor.execute(get_mob_state(mob.pid), %{
               skill: "NPC_CRITICALWOUND",
               skill_id: 673,
               level: 1,
               target: :target
             })

    assert_eventually(fn ->
      match?(
        %{source_id: id, source_type: :mob} when id == mob.unit_id,
        StatusStorage.get_status(:player, target.character.id, :sc_criticalwound)
      )
    end)

    assert :ok =
             Executor.execute(get_mob_state(mob.pid), %{
               skill: "NPC_WIDESILENCE",
               skill_id: 663,
               level: 1,
               target: :self
             })

    assert %{source_id: id, source_type: :mob} =
             StatusStorage.get_status(:player, target.character.id, :sc_silence)

    assert id == mob.unit_id
  end

  defp player(prefix, item_id, position) do
    character = character(prefix)

    if item_id do
      {:ok, _} =
        Persistence.insert_item(character.id, %{
          nameid: item_id,
          amount: 1,
          identify: 1,
          equip: 16
        })
    end

    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp character(prefix) do
    unique = System.unique_integer([:positive]) |> Integer.to_string(36)
    userid = "npcproc#{unique}"

    account =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert!()

    %Character{}
    |> Character.changeset(%{
      account_id: account.id,
      char_num: 0,
      name: "#{prefix}#{unique}",
      class: 1,
      base_level: 99,
      job_level: 50,
      hp: 100_000,
      max_hp: 100_000,
      sp: 10_000,
      max_sp: 10_000,
      str: 1,
      agi: 1,
      vit: 0,
      int: 0,
      dex: 99,
      luk: 0,
      learned_skills: %{5 => 1},
      last_map: @map,
      last_x: 150,
      last_y: 150,
      save_map: @map,
      save_x: 150,
      save_y: 150
    })
    |> Repo.insert!()
  end
end
