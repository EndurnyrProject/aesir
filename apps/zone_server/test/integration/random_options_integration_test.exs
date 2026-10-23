defmodule Aesir.ZoneServer.Integration.RandomOptionsIntegrationTest do
  @moduledoc """
  Random options end to end: an item group grant rolls its entry's random
  option group onto the granted equipment, and an equipped item's option
  script changes its wearer's stats.
  """

  use Aesir.ZoneServer.IntegrationCase

  @moduletag game_mode: :renewal
  @moduletag integration_pre_re: false

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.EquipItem
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.ItemManagement.RandomOptions
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Unit.Inventory.Persistence
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  # Booster Amplifier: equipment whose item-group entry rolls group 112.
  @amplifier 19_241
  @amplifier_group 112
  @sword 1101
  @right_hand 2
  # VAR_STRAMOUNT: `bonus bStr,getrandomoptinfo(ROA_VALUE);`
  @str_option 3

  test "an item group grant rolls its random option group onto the equipment" do
    session = start_session(insert_character())
    {:ok, group} = RandomOptions.group(@amplifier_group)
    allowed = for slot <- group.slots, entry <- slot, into: MapSet.new(), do: entry.option_id

    grant = %{
      item_id: @amplifier,
      amount: 1,
      identify?: true,
      refine: 0,
      grade: 0,
      refine_min: 0,
      refine_max: 0,
      grade_min: 0,
      grade_max: 0,
      bound: nil,
      unique_id?: false,
      duration_min: 0,
      named?: false,
      announced?: false,
      stacked?: true,
      random_option_group: @amplifier_group,
      drawn: nil
    }

    assert {:ok, game_state} =
             PlayerSession.script_apply(session.pid, {:give_group_items, [grant]})

    [item] = for {_index, item} <- game_state.inventory, item.nameid == @amplifier, do: item
    assert length(item.random_options) == length(group.slots)
    assert Enum.all?(item.random_options, &MapSet.member?(allowed, &1.id))
    assert [%{random_options: options}] = Persistence.load_inventory(game_state.character_id)
    assert options == item.random_options
  end

  test "an equipped item's option script raises its wearer's stat" do
    character = insert_character()

    {:ok, sword} =
      Persistence.insert_item(character.id, %{
        nameid: @sword,
        amount: 1,
        identify: 1,
        random_options: [%{id: @str_option, value: 7, param: 0}]
      })

    session = start_session(character)
    before = PlayerSession.get_state(session.pid).game_state.stats.modifiers.equipment

    index =
      session.pid
      |> PlayerSession.get_state()
      |> then(& &1.game_state.inventory)
      |> Enum.find_value(fn {index, item} -> if item.id == sword.id, do: index end)

    simulate_incoming_message(session.pid, %EquipItem{
      index: PlayerState.client_index(index),
      position: @right_hand
    })

    assert_eventually(fn ->
      equipment = PlayerSession.get_state(session.pid).game_state.stats.modifiers.equipment
      Map.get(equipment, :str, 0) == Map.get(before, :str, 0) + 7
    end)
  end

  defp insert_character do
    unique = System.unique_integer([:positive]) |> Integer.to_string(36)
    userid = "ropt#{unique}"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: "M",
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, job_id} = AvailableJobs.job_name_to_id(:swordman)

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Optioned#{unique}",
        class: job_id,
        sex: "M",
        base_level: 99,
        job_level: 1,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        save_map: "prontera",
        save_x: 150,
        save_y: 150
      })
      |> Repo.insert()

    character
  end

  defp start_session(character) do
    session = start_player_session(character: character, map_name: "prontera")
    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end
end
