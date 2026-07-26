defmodule Aesir.ZoneServer.Integration.PriestRedemptioTest do
  @moduledoc """
  End-to-end Redemptio coverage through the real party registry, retained
  corpse state, and target-session resurrection command.
  """
  use Aesir.ZoneServer.IntegrationCase

  @moduletag :capture_log

  alias Aesir.Commons.ClusterTestHelper
  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Interpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Unit.Player.PlayerSession

  setup do
    on_exit(&ClusterTestHelper.clear_all/0)
    :ok
  end

  test "revives a retained nearby party corpse at 50 percent and returns the caster at one HP" do
    caster_character =
      character_fixture("RedemptioCaster", %{
        class: 8,
        learned_skills: %{"1014" => 1},
        last_map: "prontera",
        last_x: 150,
        last_y: 150,
        hp: 1_000,
        max_hp: 1_000,
        sp: 1_000,
        max_sp: 1_000
      })

    target_character =
      character_fixture("RedemptioTarget", %{
        last_map: "prontera",
        last_x: 151,
        last_y: 150
      })

    assert {:ok, party} = PartyManager.create("Redemptio", caster_character)
    assert {:ok, _party} = PartyManager.add_member(party.party_id, target_character)

    caster_character = Repo.get!(Character, caster_character.id)
    target_character = Repo.get!(Character, target_character.id)

    caster =
      start_player_session(
        character: caster_character,
        map_name: "prontera",
        position: {150, 150}
      )

    target =
      start_player_session(
        character: target_character,
        map_name: "prontera",
        position: {151, 150}
      )

    PlayerSession.apply_damage(target.pid, 1_000_000, caster.character.id)
    assert_eventually(fn -> get_player_state(target.pid).action_state == :dead end)

    caster_state = get_player_state(caster.pid)

    assert {:ok, updated_caster} = Interpreter.complete_cast(caster_state, 1014, 1, :self)

    assert updated_caster.stats.current_state.hp == 1
    assert updated_caster.stats.current_state.sp == 200

    assert_eventually(fn ->
      revived = get_player_state(target.pid)

      revived.action_state == :idle and
        revived.stats.current_state.hp == div(revived.stats.derived_stats.max_hp * 50, 100)
    end)
  end

  defp assert_eventually(fun, attempts \\ 50)
  defp assert_eventually(fun, 0), do: assert(fun.())

  defp assert_eventually(fun, attempts) do
    if fun.() do
      :ok
    else
      Process.sleep(10)
      assert_eventually(fun, attempts - 1)
    end
  end

  defp character_fixture(name, attrs) do
    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: String.downcase(name),
        user_pass: "password",
        sex: "M",
        email: "#{String.downcase(name)}@example.com"
      })
      |> Repo.insert()

    {:ok, character} =
      %{char_num: 0, class: 0, base_level: 99}
      |> Map.merge(attrs)
      |> Map.merge(%{account_id: account.id, name: name})
      |> Character.new()
      |> Repo.insert()

    character
  end
end
