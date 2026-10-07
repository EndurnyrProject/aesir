defmodule Aesir.ZoneServer.Integration.EquipmentHitProcParityTest do
  @moduledoc """
  Equipment autocasts armed on hits run in their wearer's own session: the
  attacker's for its own magic, misc and field hits, the recipient's after its
  HP changed. A recipient killed by the hit, or a hit a blocking status
  stopped, produces no proc on either side.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Repo
  alias Aesir.ZoneServer.Map.MapFlags
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.BattleFlags
  alias Aesir.ZoneServer.Mmo.ItemManagement
  alias Aesir.ZoneServer.Mmo.ItemManagement.ItemDefinition
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @map "prontera"
  @armor 16
  @attacker_item 990_101
  @defender_item 990_102
  @increase_agi 29
  @fire_bolt 19
  @storm_gust 89
  @blitz_beat 129

  setup do
    Mimic.copy(ItemManagement)

    items = %{
      @attacker_item => proc_item(@attacker_item, :attack),
      @defender_item => proc_item(@defender_item, :when_hit)
    }

    stub(ItemManagement, :get_item_by_id, fn item_id ->
      case Map.fetch(items, item_id) do
        {:ok, item} -> {:ok, item}
        :error -> call_original(ItemManagement, :get_item_by_id, [item_id])
      end
    end)

    :ok = MapFlags.set_runtime(@map, :pvp, true)
    on_exit(fn -> MapFlags.clear_runtime(@map, :pvp) end)
    :ok
  end

  setup {Aesir.MimicMode, :global}

  test "a magic hit runs the attacker's and the surviving recipient's procs in their own sessions" do
    {attacker, defender} = duel()

    assert {:ok, {:player, _id}} =
             Combat.execute_magic_attack(state(attacker), defender.character.id,
               skill_id: @fire_bolt,
               skill_level: 1
             )

    assert eventually(fn -> buffed?(attacker) and buffed?(defender) end)
  end

  test "a misc hit runs both sides' procs" do
    {attacker, defender} = duel()

    assert :ok =
             Combat.execute_misc_attack(state(attacker), defender.character.id,
               skill_id: @blitz_beat,
               skill_level: 1,
               base_damage: 10
             )

    assert eventually(fn -> buffed?(attacker) and buffed?(defender) end)
  end

  test "a field hit delivered outside the caster's session still procs on the caster" do
    {attacker, defender} = duel()
    caster = attacker.pid |> get_player_state() |> PlayerState.to_combatant()

    assert :ok =
             Combat.apply_skill_unit_damage(
               caster,
               :player,
               defender.character.id,
               @storm_gust,
               1,
               :water,
               100,
               hit_divisions: 1
             )

    assert eventually(fn -> buffed?(attacker) and buffed?(defender) end)
  end

  test "a recipient killed by the hit procs nothing, and neither does its attacker" do
    {attacker, defender} = duel(defender_hp: 1)

    Combat.execute_magic_attack(state(attacker), defender.character.id,
      skill_id: @fire_bolt,
      skill_level: 1
    )

    assert eventually(fn -> get_player_state(defender.pid).action_state == :dead end)
    settle(attacker)
    settle(defender)
    refute buffed?(attacker)
    refute buffed?(defender)
  end

  test "a hit stopped by a blocking status procs on neither side" do
    {attacker, defender} = duel()
    :ok = StatusStorage.apply_status(:player, defender.character.id, :sc_pneuma, duration: 30_000)
    hp = get_player_state(defender.pid).stats.current_state.hp

    assert :ok =
             Combat.execute_misc_attack(state(attacker), defender.character.id,
               skill_id: @blitz_beat,
               skill_level: 1,
               base_damage: 10
             )

    settle(attacker)
    settle(defender)
    assert get_player_state(defender.pid).stats.current_state.hp == hp
    refute buffed?(attacker)
    refute buffed?(defender)
  end

  defp duel(opts \\ []) do
    attacker = start_session(insert_character("ProcAtk", %{}), @attacker_item, {150, 150})

    defender =
      start_session(
        insert_character("ProcDef", %{hp: Keyword.get(opts, :defender_hp, 100_000)}),
        @defender_item,
        {151, 150}
      )

    {attacker, defender}
  end

  defp state(session), do: get_player_state(session.pid)

  defp buffed?(session),
    do: StatusStorage.has_status?(:player, session.character.id, :sc_increaseagi)

  # Two round trips: a proc a handler cast to its own session is queued behind
  # the first call, so the second one returns only after it ran.
  defp settle(session) do
    get_player_state(session.pid)
    get_player_state(session.pid)
  end

  # Every trigger arms Increase AGI on the wearer at a certain chance, on any
  # magic, misc or weapon hit of either origin and range.
  defp proc_item(id, trigger) do
    any_hit =
      Enum.reduce([:weapon, :magic, :misc], 0, &Bitwise.bor(BattleFlags.type_bit(&1), &2))
      |> Bitwise.bor(BattleFlags.range_bit(:short))
      |> Bitwise.bor(BattleFlags.range_bit(:long))
      |> Bitwise.bor(BattleFlags.origin_bit(false))
      |> Bitwise.bor(BattleFlags.origin_bit(true))

    %ItemDefinition{
      id: id,
      aegis_name: "HIT_PROC_ITEM_#{id}",
      name: "Hit Proc Item #{id}",
      type: :armor,
      locations: [:armor],
      on_equip: [
        {:auto_cast, %{trigger: trigger, skill_id: @increase_agi, flag: any_hit, force: 0}, 1,
         1_000}
      ]
    }
  end

  defp start_session(character, item_id, position) do
    {:ok, _row} =
      InventoryPersistence.insert_item(character.id, %{
        nameid: item_id,
        amount: 1,
        identify: 1,
        equip: @armor
      })

    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  defp insert_character(name, attrs) do
    unique = System.unique_integer([:positive]) |> Integer.to_string(36)
    userid = "hitproc#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %Character{}
      |> Character.changeset(
        Map.merge(
          %{
            account_id: account.id,
            char_num: 0,
            name: "#{name}#{unique}",
            class: 4,
            base_level: 99,
            job_level: 50,
            str: 50,
            agi: 1,
            vit: 10,
            int: 50,
            dex: 99,
            luk: 1,
            hp: 100_000,
            max_hp: 100_000,
            sp: 10_000,
            max_sp: 10_000,
            last_map: @map,
            last_x: 150,
            last_y: 150,
            save_map: @map,
            save_x: 150,
            save_y: 150,
            learned_skills: %{}
          },
          attrs
        )
      )
      |> Repo.insert()

    character
  end
end
