defmodule Aesir.ZoneServer.HwProfessorFixture do
  @moduledoc """
  Shared session fixtures for the High Wizard and Professor integration tests:
  database-backed casters (so catalysts load from inventory), stationary mob
  targets, enemy traps, and cast helpers.
  """
  import ExUnit.Callbacks, only: [on_exit: 1]
  import Aesir.ZoneServer.PacketHelpers, only: [simulate_incoming_message: 2]
  import Aesir.ZoneServer.SessionHelpers

  alias Aesir.Commons.Models.Account
  alias Aesir.Commons.Models.Character
  alias Aesir.Net.GroundSkillCast
  alias Aesir.Net.SkillCast
  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Manager
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState
  alias Aesir.ZoneServer.Unit.Inventory.Persistence, as: InventoryPersistence

  @map "prontera"

  @doc "The map every fixture unit lives on."
  @spec map() :: String.t()
  def map, do: @map

  @doc """
  Inserts a caster character of `class` with `skills` learned and starts its
  session holding `items` (`{item_id, amount}` pairs). `overrides` merge into
  the character attributes.
  """
  @spec start_caster(pos_integer(), map(), [{pos_integer(), pos_integer()}], map()) :: map()
  def start_caster(class, skills, items \\ [], overrides \\ %{}) do
    character = insert_character(class, skills, overrides)

    for {item_id, amount} <- items do
      {:ok, _item} =
        InventoryPersistence.insert_item(character.id, %{
          nameid: item_id,
          amount: amount,
          identify: 1
        })
    end

    session =
      start_player_session(
        character: character,
        map_name: @map,
        position: {character.last_x, character.last_y}
      )

    on_exit(fn -> if Process.alive?(session.pid), do: end_player_session(session) end)
    session
  end

  @doc "Inserts a caster character row without starting a session."
  @spec insert_character(pos_integer(), map(), map()) :: Character.t()
  def insert_character(class, skills, overrides \\ %{}) do
    unique = System.unique_integer([:positive])

    {:ok, account} =
      %Account{}
      |> Account.changeset(%{
        userid: "hwpf#{unique}",
        username: "hwpf#{unique}",
        user_pass: "password",
        email: "hwpf#{unique}@aesir.test"
      })
      |> Repo.insert()

    attrs =
      Map.merge(
        %{
          account_id: account.id,
          char_num: 0,
          name: "Caster#{unique}",
          sex: "M",
          class: class,
          base_level: 99,
          job_level: 70,
          str: 1,
          agi: 1,
          vit: 1,
          int: 99,
          dex: 99,
          luk: 1,
          hp: 5_000,
          max_hp: 5_000,
          sp: 400,
          max_sp: 2_000,
          learned_skills: skills,
          last_map: @map,
          last_x: 150,
          last_y: 150,
          save_map: @map,
          save_x: 150,
          save_y: 150
        },
        overrides
      )

    {:ok, character} = %Character{} |> Character.changeset(attrs) |> Repo.insert()
    character
  end

  @doc "Starts a stationary, defenceless mob target."
  @spec start_target({integer(), integer()}, keyword()) :: map()
  def start_target(position, opts \\ []) do
    mob =
      start_mob_session(
        opts ++ [map_name: @map, position: position, hp: 100_000, max_hp: 100_000, vit: 0, luk: 0]
      )

    on_exit(fn -> if Process.alive?(mob.pid), do: end_mob_session(mob) end)
    mob
  end

  @doc "Registers a mob-owned Land Mine on `position` and returns its group id."
  @spec register_trap({integer(), integer()}, pos_integer()) :: pos_integer()
  def register_trap(position, owner_id) do
    now = System.monotonic_time(:millisecond)
    group_id = System.unique_integer([:positive])

    :ok =
      Manager.register(%Group{
        group_id: group_id,
        skill_id: 116,
        skill_name: :ht_landmine,
        level: 1,
        caster_id: owner_id,
        caster_type: :mob,
        map_name: @map,
        center: position,
        cells: [position],
        interval: 1_000,
        next_tick_at: now + 60_000,
        expires_at: now + 60_000,
        state: %{base_damage: 500, trap: %TrapState{}}
      })

    group_id
  end

  @doc "Casts a unit-targeted skill from `session`, at itself when no target is given."
  @spec cast(map(), pos_integer(), pos_integer(), integer() | nil) :: :ok
  def cast(session, skill_id, level, target_id \\ nil) do
    simulate_incoming_message(session.pid, %SkillCast{
      skill_id: skill_id,
      level: level,
      target_id: target_id || session.character.id
    })
  end

  @doc "Casts a ground skill from `session` on `{x, y}`."
  @spec cast_ground(map(), pos_integer(), pos_integer(), {integer(), integer()}) :: :ok
  def cast_ground(session, skill_id, level, {x, y}) do
    simulate_incoming_message(session.pid, %GroundSkillCast{
      skill_id: skill_id,
      level: level,
      x: x,
      y: y
    })
  end
end
