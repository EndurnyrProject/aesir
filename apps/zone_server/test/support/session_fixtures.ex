defmodule Aesir.ZoneServer.SessionFixtures do
  @moduledoc """
  Shared `Character`/`MobDefinition`/`MobSpawn` builders for the
  `Unit.Session.*` test suites (Vitals, Motion), which otherwise each
  hand-roll the same fixtures.
  """

  alias Aesir.Commons.Models.Character
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition
  alias Aesir.ZoneServer.Mmo.MobManagement.MobSpawn

  @doc """
  Builds a `Character` struct suitable for `PlayerState.new/1`.
  """
  @spec character(keyword()) :: Character.t()
  def character(opts \\ []) do
    defaults = [
      id: 1,
      account_id: 100,
      name: "Fixture",
      last_map: "prontera",
      last_x: 150,
      last_y: 150,
      class: 0,
      base_level: 50,
      job_level: 50,
      str: 10,
      agi: 10,
      vit: 10,
      int: 10,
      dex: 10,
      luk: 7
    ]

    struct!(Character, Keyword.merge(defaults, opts))
  end

  @doc """
  Builds a `MobDefinition` (default: Poring) suitable for `MobState.mob_data`.
  """
  @spec mob_definition(keyword()) :: MobDefinition.t()
  def mob_definition(opts \\ []) do
    defaults = [
      id: 1002,
      aegis_name: "PORING",
      name: "Poring",
      level: 1,
      hp: 100,
      stats: %{str: 1, agi: 1, vit: 1, int: 1, dex: 6, luk: 5},
      attack_range: 1,
      size: :medium,
      race: :plant,
      element: {:water, 1},
      walk_speed: 400,
      attack_delay: 1000,
      attack_motion: 500,
      client_attack_motion: 500,
      damage_motion: 400
    ]

    struct!(MobDefinition, Keyword.merge(defaults, opts))
  end

  @doc """
  Builds a `MobSpawn` suitable for `MobState.spawn_ref`.
  """
  @spec mob_spawn(keyword()) :: MobSpawn.t()
  def mob_spawn(opts \\ []) do
    defaults = [
      mob: 1002,
      amount: 1,
      respawn_time: 5_000,
      spawn_area: %MobSpawn.SpawnArea{x: 150, y: 150, xs: 0, ys: 0}
    ]

    struct!(MobSpawn, Keyword.merge(defaults, opts))
  end
end
