defmodule Aesir.ZoneServer.Integration.HunterDetectingIntegrationTest do
  use Aesir.ZoneServer.IntegrationCase

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Option
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @map "prontera"
  @detecting_id 130
  @land_mine_id 116
  @blast_mine_id 122
  @falconry_id 127
  @trap_item 1065

  test "Detecting removes Hiding and Cloaking and reveals the hidden traps in its area" do
    detector = start_hunter(10_001, {152, 150}, falcon?: true, traps: 4)
    hidden = start_hunter(10_002, {154, 152})
    cloaked = start_hunter(10_003, {157, 150})
    diagonal = start_hunter(10_004, {157, 153})
    outside = start_hunter(10_005, {158, 150})

    assert eventually(fn ->
             Enum.all?(
               [detector, hidden, cloaked, diagonal, outside],
               &registered?(&1.character.id)
             )
           end)

    position_players([
      {detector.character.id, 152, 150},
      {hidden.character.id, 154, 152},
      {cloaked.character.id, 157, 150},
      {diagonal.character.id, 157, 153},
      {outside.character.id, 158, 150}
    ])

    :ok =
      StatusInterpreter.apply_status(:player, hidden.character.id, :sc_hiding, duration: 60_000)

    :ok =
      StatusInterpreter.apply_status(:player, cloaked.character.id, :sc_cloaking,
        duration: 60_000
      )

    :ok =
      StatusInterpreter.apply_status(:player, diagonal.character.id, :sc_hiding, duration: 60_000)

    :ok =
      StatusInterpreter.apply_status(:player, outside.character.id, :sc_hiding, duration: 60_000)

    place_trap(detector.pid, @land_mine_id, 153, 150)
    assert hidden_trap?(@land_mine_id, 153, 150)

    # Blast Mine is one of the two traps that place visible, so Detecting has
    # nothing to reveal on it.
    place_trap(detector.pid, @blast_mine_id, 155, 150)
    assert visible_trap?(@blast_mine_id, 155, 150)

    place_trap(detector.pid, @land_mine_id, 150, 151)
    assert hidden_trap?(@land_mine_id, 150, 151)

    wait_for_act_delay(detector.pid)
    initial_sp = current_sp(detector.pid)
    cast_ground(detector.pid, @detecting_id, 4, 154, 150)

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, hidden.character.id, :sc_hiding)
           end)

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, cloaked.character.id, :sc_cloaking)
           end)

    assert eventually(fn ->
             not StatusStorage.has_status?(:player, diagonal.character.id, :sc_hiding)
           end)

    assert StatusStorage.has_status?(:player, outside.character.id, :sc_hiding)
    assert eventually(fn -> visible_trap?(@land_mine_id, 153, 150) end)
    assert eventually(fn -> visible_trap?(@blast_mine_id, 155, 150) end)
    assert hidden_trap?(@land_mine_id, 150, 151)
    assert current_sp(detector.pid) == initial_sp - 8

    wait_for_act_delay(detector.pid)
    cast_ground(detector.pid, @detecting_id, 4, 154, 150)

    assert eventually(fn -> current_sp(detector.pid) == initial_sp - 16 end)
    assert StatusStorage.has_status?(:player, outside.character.id, :sc_hiding)
    assert visible_trap?(@land_mine_id, 153, 150)
    assert visible_trap?(@blast_mine_id, 155, 150)
    assert hidden_trap?(@land_mine_id, 150, 151)
  end

  test "a session cast without a Falcon leaves SP and concealment unchanged" do
    detector = start_hunter(10_101, {150, 150})
    hidden = start_hunter(10_102, {153, 150})

    assert eventually(fn -> Enum.all?([detector, hidden], &registered?(&1.character.id)) end)
    position_players([{detector.character.id, 150, 150}, {hidden.character.id, 153, 150}])

    :ok =
      StatusInterpreter.apply_status(:player, hidden.character.id, :sc_hiding, duration: 60_000)

    initial_sp = current_sp(detector.pid)

    cast_ground(detector.pid, @detecting_id, 1, 153, 150)

    assert current_sp(detector.pid) == initial_sp
    assert StatusStorage.has_status?(:player, hidden.character.id, :sc_hiding)
  end

  defp cast_ground(pid, skill_id, level, x, y) do
    simulate_incoming_message(pid, %GroundSkillCast{skill_id: skill_id, level: level, x: x, y: y})
  end

  # An armed after-cast delay rejects the next cast outright.
  defp wait_for_act_delay(pid) do
    assert eventually(fn ->
             %PlayerState{act_delay_until: until} = get_player_state(pid)
             until == nil or until <= System.monotonic_time(:millisecond)
           end)
  end

  # Trap casts carry a variable cast time and an after-cast delay, so a cast
  # issued while the previous one is still resolving is rejected outright.
  defp place_trap(pid, skill_id, x, y) do
    assert eventually(fn ->
             cast_ground(pid, skill_id, 1, x, y)
             Process.sleep(100)
             trap_at?(skill_id, x, y)
           end)
  end

  defp trap_at?(skill_id, x, y) do
    @map
    |> Storage.get_groups_at_cell(x, y)
    |> Enum.any?(&match?(%Group{skill_id: ^skill_id}, &1))
  end

  defp hidden_trap?(skill_id, x, y) do
    @map
    |> Storage.get_groups_at_cell(x, y)
    |> Enum.any?(&match?(%Group{skill_id: ^skill_id, visibility: :none}, &1))
  end

  defp visible_trap?(skill_id, x, y) do
    @map
    |> Storage.get_groups_at_cell(x, y)
    |> Enum.any?(&match?(%Group{skill_id: ^skill_id, visibility: :public}, &1))
  end

  defp start_hunter(id, position, opts \\ []) do
    character = insert_hunter(id, falcon?: Keyword.get(opts, :falcon?, false))

    if traps = opts[:traps] do
      assert {:ok, _item} =
               InventoryPersistence.insert_item(character.id, %{
                 nameid: @trap_item,
                 amount: traps
               })
    end

    session = start_player_session(character: character, map_name: @map, position: position)
    on_exit(fn -> end_player_session(session) end)
    session
  end

  defp insert_hunter(id, opts) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        username: "detect#{id}",
        userid: "detect#{id}",
        user_pass: "password",
        email: "detect#{id}@aesir.test"
      })
      |> Repo.insert()

    option = if Keyword.fetch!(opts, :falcon?), do: Option.id(:falcon), else: 0

    {:ok, character} =
      %Character{}
      |> Character.changeset(%{
        account_id: account.id,
        char_num: 0,
        name: "Detect#{id}",
        class: 11,
        base_level: 50,
        job_level: 50,
        str: 10,
        agi: 10,
        vit: 10,
        int: 10,
        dex: 10,
        luk: 10,
        max_hp: 500,
        hp: 500,
        max_sp: 100,
        sp: 100,
        option: option,
        learned_skills: learned_skills(),
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

  defp learned_skills do
    %{
      Integer.to_string(@land_mine_id) => 1,
      Integer.to_string(@blast_mine_id) => 1,
      Integer.to_string(@falconry_id) => 1,
      Integer.to_string(@detecting_id) => 4
    }
  end

  defp registered?(character_id) do
    match?({:ok, {_module, %PlayerState{}, _pid}}, UnitRegistry.get_unit(:player, character_id))
  end

  defp position_players(players) do
    Enum.each(players, fn {character_id, x, y} ->
      :ok = SpatialIndex.update_unit_position(:player, character_id, x, y, @map)
    end)
  end

  defp current_sp(pid) do
    %PlayerState{stats: %{current_state: %{sp: sp}}} = get_player_state(pid)
    sp
  end
end
