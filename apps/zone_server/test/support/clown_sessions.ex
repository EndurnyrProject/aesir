defmodule Aesir.ZoneServer.TestSupport.ClownSessions do
  @moduledoc """
  Persisted Clown, Gypsy and Novice characters with real sessions for the
  Clown/Gypsy integration tests, on a blank walkable copy of their map.
  """

  import ExUnit.Callbacks, only: [on_exit: 1]

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.EtsTable
  alias Aesir.ZoneServer.Map.MapData
  alias Aesir.ZoneServer.PacketHelpers
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.SessionHelpers
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @classes %{clown: 4020, gypsy: 4021, novice: 0}
  @violin 1901
  @whip 1960
  @arrow 1750
  @right_hand 2
  @arrow_slot 0x008000

  @doc "Replaces `map`'s cache entry with an open 400x400 map for this test's world."
  @spec blank_map(String.t()) :: true
  def blank_map(map),
    do: :ets.insert(EtsTable.table_for(:map_cache), {map, MapData.new(map, 400, 400)})

  @doc """
  Inserts a character with `skills` (`%{skill_id => level}`) on `map` at `{x, y}`.

  Clowns get a violin and 20 arrows, Gypsies a whip. `overrides` merge into
  the character attributes.
  """
  @spec character(atom(), String.t(), {integer(), integer()}, map(), map()) :: Character.t()
  def character(job, map, {x, y}, skills, overrides \\ %{}) do
    unique = System.unique_integer([:positive])
    userid = "clown#{unique}"
    sex = if job == :gypsy, do: "F", else: "M"

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: userid,
        user_pass: "password",
        sex: sex,
        email: "#{userid}@aesir.test"
      })
      |> Repo.insert()

    {:ok, character} =
      %{
        account_id: account.id,
        char_num: 0,
        name: "#{job}#{unique}",
        class: Map.fetch!(@classes, job),
        sex: sex,
        base_level: 99,
        job_level: 50,
        str: 20,
        agi: 20,
        vit: 0,
        int: 20,
        dex: 50,
        luk: 0,
        hp: 10_000,
        max_hp: 10_000,
        sp: 1000,
        max_sp: 1000,
        learned_skills: Map.new(skills, fn {id, level} -> {Integer.to_string(id), level} end),
        last_map: map,
        last_x: x,
        last_y: y,
        save_map: map,
        save_x: x,
        save_y: y
      }
      |> Map.merge(overrides)
      |> Character.new()
      |> Repo.insert()

    equip(job, character.id)
    character
  end

  @doc "Puts the characters in one party led by the first."
  @spec party([Character.t()]) :: :ok
  def party([leader | members]) do
    {:ok, party} = PartyManager.create("Clown#{leader.id}", leader)

    Enum.each(members, fn member -> {:ok, _} = PartyManager.add_member(party.party_id, member) end)
  end

  @doc "Starts the character's session at its saved position and ends it on exit."
  @spec start_session(Character.t()) :: map()
  def start_session(character) do
    session =
      SessionHelpers.start_player_session(
        character: Repo.get!(Character, character.id),
        map_name: character.last_map,
        position: {character.last_x, character.last_y}
      )

    on_exit(fn ->
      if Process.alive?(session.pid), do: SessionHelpers.end_player_session(session)
    end)

    session
  end

  @doc "Sends a unit-targeted skill cast through the session; self-targeted when no target."
  @spec cast(map(), pos_integer(), pos_integer(), pos_integer() | nil) :: :ok
  def cast(session, skill_id, level, target_id \\ nil) do
    PacketHelpers.simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id || session.character.id
    })
  end

  defp equip(:clown, id) do
    insert(id, %{nameid: @violin, amount: 1, equip: @right_hand})
    insert(id, %{nameid: @arrow, amount: 20, equip: @arrow_slot})
  end

  defp equip(:gypsy, id), do: insert(id, %{nameid: @whip, amount: 1, equip: @right_hand})
  defp equip(_job, _id), do: :ok

  defp insert(id, attrs) do
    {:ok, _item} = InventoryPersistence.insert_item(id, Map.put(attrs, :identify, 1))
    :ok
  end
end
