defmodule Aesir.ZoneServer.Factory do
  @moduledoc """
  ExMachina factories for zone-server runtime structs (values held in memory, never
  inserted). Persisted rows come from `Aesir.Factory`.

      import Aesir.ZoneServer.Factory

      officer = build(:guild_member, position_index: 5)
      guild = build(:guild_state, members: [officer])
      state = build(:coordinator_state, mobs_awake: true)

  Each factory fills only the enforced keys; everything else keeps its struct default,
  so a test states the fields it cares about.
  """

  use ExMachina

  alias Aesir.ZoneServer.Config
  alias Aesir.ZoneServer.Guild.Member
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Map.Coordinator
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn
  alias Aesir.ZoneServer.PlayerStateFixture
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @doc """
  A level 1 guild with no members and no master (`master_char_id: 0`); set the master
  when the test reads it. `members:` takes a list of `Member`s and keys them by
  `char_id`, the shape `State.members` holds.
  """
  @spec guild_state_factory(map()) :: State.t()
  def guild_state_factory(attrs) do
    {members, attrs} = Map.pop(attrs, :members, [])

    %State{
      guild_id: sequence(:guild_state_id, & &1, start_at: 1),
      name: sequence(:guild_state_name, &"Guild #{&1}"),
      master_char_id: 0,
      members: Map.new(members, &{&1.char_id, &1})
    }
    |> merge_attributes(attrs)
    |> evaluate_lazy_attributes()
  end

  @doc "An online level 1 member at the Newbie position (19)."
  @spec guild_member_factory() :: Member.t()
  def guild_member_factory do
    %Member{
      char_id: sequence(:guild_member_char_id, & &1, start_at: 1),
      name: sequence(:guild_member_name, &"Member #{&1}"),
      base_level: 1,
      online: true
    }
  end

  @doc """
  The state of a `"prontera"` coordinator before its first visit: no map data,
  no spawn lines, mobs neither spawned nor awake.
  """
  @spec coordinator_state_factory() :: Coordinator.t()
  def coordinator_state_factory do
    %Coordinator{map_name: "prontera"}
  end

  @doc """
  A plain monster line spawning one Poring (1002) at the fixed cell `{100, 100}`,
  respawning after 5 s with no variance.
  """
  @spec mob_spawn_factory() :: MobSpawn.t()
  def mob_spawn_factory do
    %MobSpawn{
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 100, y: 100}
    }
  end

  @doc """
  An idle, standing, living player on `"prontera"` at `{150, 150}`, with the
  configured view range and empty visibility sets, the shape `PlayerState.new/1`
  gives a player on a map. `stats:` takes a partial map: `PlayerStateFixture`
  fills the rest (100 HP, 100 SP, all base stats 1).
  """
  @spec player_state_factory(map()) :: PlayerState.t()
  def player_state_factory(attrs) do
    %{
      character_id: sequence(:player_state_character_id, & &1, start_at: 1),
      map_name: "prontera",
      x: 150,
      y: 150,
      view_range: Config.view_range(),
      stats: %{},
      visible_players: MapSet.new(),
      visible_mobs: MapSet.new(),
      visible_warps: MapSet.new(),
      visible_npcs: MapSet.new(),
      visible_shops: MapSet.new(),
      visible_items: MapSet.new(),
      visible_skill_units: MapSet.new()
    }
    |> Map.merge(attrs)
    |> PlayerStateFixture.build()
  end
end
