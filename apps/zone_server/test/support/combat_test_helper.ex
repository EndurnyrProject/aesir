defmodule Aesir.ZoneServer.CombatTestHelper do
  @moduledoc """
  Helper functions for creating test combatants and combat scenarios.

  This module provides utilities for creating combatant structs for testing
  without requiring database connections or complex session setups.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant

  @doc """
  Creates a basic player combatant for testing.
  """
  @spec create_player_combatant(keyword()) :: Combatant.t()
  def create_player_combatant(opts \\ []) do
    defaults = [
      unit_id: 1001,
      base_level: 10,
      job_level: 1,
      str: 5,
      agi: 5,
      vit: 5,
      int: 5,
      dex: 5,
      luk: 5,
      position: {100, 100},
      map_name: "test_map",
      element: :neutral,
      race: :human,
      size: :medium,
      weapon_type: :fist,
      weapon_element: :neutral,
      weapon_size: :all
    ]

    opts = Keyword.merge(defaults, opts)

    # Calculate derived stats from base stats and level
    base_atk = calculate_base_atk(opts[:str], opts[:dex], opts[:base_level])
    base_def = calculate_base_def(opts[:vit], opts[:base_level])
    hit = calculate_hit(opts[:dex], opts[:base_level])
    flee = calculate_flee(opts[:agi], opts[:base_level])
    perfect_dodge = calculate_perfect_dodge(opts[:luk])

    %Combatant{
      unit_id: opts[:unit_id],
      unit_type: :player,
      gid: opts[:gid] || opts[:unit_id],
      base_stats: %{
        str: opts[:str],
        agi: opts[:agi],
        vit: opts[:vit],
        int: opts[:int],
        dex: opts[:dex],
        luk: opts[:luk]
      },
      combat_stats: %{
        atk: base_atk,
        def: base_def,
        hit: hit,
        flee: flee,
        perfect_dodge: perfect_dodge
      },
      progression: %{
        base_level: opts[:base_level],
        job_level: opts[:job_level]
      },
      element: opts[:element],
      race: opts[:race],
      size: opts[:size],
      weapon: %{
        type: opts[:weapon_type],
        element: opts[:weapon_element],
        size: opts[:weapon_size]
      },
      attack_range: opts[:attack_range] || 1,
      position: opts[:position],
      map_name: opts[:map_name]
    }
  end

  @doc """
  Creates a basic mob combatant for testing.
  """
  @spec create_mob_combatant(keyword()) :: Combatant.t()
  def create_mob_combatant(opts \\ []) do
    defaults = [
      unit_id: 2001,
      base_level: 5,
      str: 10,
      agi: 8,
      vit: 12,
      int: 3,
      dex: 7,
      luk: 5,
      position: {105, 105},
      map_name: "test_map",
      element: :earth,
      race: :brute,
      size: :medium,
      atk: 50,
      def: 10
    ]

    opts = Keyword.merge(defaults, opts)

    # Mobs use different stat calculations
    hit = calculate_mob_hit(opts[:dex], opts[:base_level])
    flee = calculate_mob_flee(opts[:agi], opts[:base_level])
    perfect_dodge = calculate_perfect_dodge(opts[:luk])

    %Combatant{
      unit_id: opts[:unit_id],
      unit_type: :mob,
      gid: opts[:gid] || opts[:unit_id],
      base_stats: %{
        str: opts[:str],
        agi: opts[:agi],
        vit: opts[:vit],
        int: opts[:int],
        dex: opts[:dex],
        luk: opts[:luk]
      },
      combat_stats: %{
        atk: opts[:atk],
        def: opts[:def],
        hit: hit,
        flee: flee,
        perfect_dodge: perfect_dodge
      },
      progression: %{
        base_level: opts[:base_level],
        job_level: 1
      },
      element: opts[:element],
      race: opts[:race],
      size: opts[:size],
      weapon: %{
        type: :claw,
        element: :neutral,
        size: :all
      },
      attack_range: opts[:attack_range] || 1,
      position: opts[:position],
      map_name: opts[:map_name]
    }
  end

  @doc """
  Creates a high-level player combatant for testing advanced scenarios.
  """
  @spec create_high_level_player(keyword()) :: Combatant.t()
  def create_high_level_player(opts \\ []) do
    defaults = [
      unit_id: 1002,
      base_level: 50,
      job_level: 25,
      str: 50,
      agi: 30,
      vit: 40,
      int: 25,
      dex: 35,
      luk: 20,
      weapon_type: :sword
    ]

    create_player_combatant(Keyword.merge(defaults, opts))
  end

  @doc """
  Creates a boss mob combatant for testing difficult scenarios.
  """
  @spec create_boss_mob(keyword()) :: Combatant.t()
  def create_boss_mob(opts \\ []) do
    defaults = [
      unit_id: 2999,
      base_level: 30,
      str: 80,
      agi: 25,
      vit: 100,
      int: 40,
      dex: 50,
      luk: 10,
      element: :dark,
      race: :demon,
      size: :large,
      atk: 200,
      def: 50
    ]

    create_mob_combatant(Keyword.merge(defaults, opts))
  end

  # Private calculation functions following Ragnarok formulas

  defp calculate_base_atk(str, dex, base_level) do
    # Simplified base ATK calculation
    trunc(str * base_level / 4) + dex
  end

  defp calculate_base_def(vit, base_level) do
    # Simplified base DEF calculation
    trunc(vit * base_level / 2)
  end

  defp calculate_hit(dex, base_level) do
    # Simplified HIT calculation
    base_level + dex
  end

  defp calculate_flee(agi, base_level) do
    # Simplified FLEE calculation
    base_level + agi
  end

  defp calculate_perfect_dodge(luk) do
    # Perfect dodge is based on LUK
    trunc(luk / 10) + 1
  end

  defp calculate_mob_hit(dex, base_level) do
    # Mobs have different hit formula
    base_level + dex + 5
  end

  defp calculate_mob_flee(agi, base_level) do
    # Mobs have different flee formula
    base_level + agi + 3
  end

  @doc """
  Creates a combat scenario with an attacker and defender.

  ## Parameters
  - attacker_opts: Options for the attacker combatant
  - defender_opts: Options for the defender combatant

  ## Returns
  {attacker_combatant, defender_combatant}
  """
  @spec create_combat_scenario(keyword(), keyword()) :: {Combatant.t(), Combatant.t()}
  def create_combat_scenario(attacker_opts \\ [], defender_opts \\ []) do
    attacker = create_player_combatant(attacker_opts)
    defender = create_mob_combatant(defender_opts)
    {attacker, defender}
  end

  @doc """
  Creates a PvP scenario with two players.
  """
  @spec create_pvp_scenario(keyword(), keyword()) :: {Combatant.t(), Combatant.t()}
  def create_pvp_scenario(player1_opts \\ [], player2_opts \\ []) do
    player1_defaults = [unit_id: 1001, position: {100, 100}]
    player2_defaults = [unit_id: 1002, position: {105, 105}]

    player1 = create_player_combatant(Keyword.merge(player1_defaults, player1_opts))
    player2 = create_player_combatant(Keyword.merge(player2_defaults, player2_opts))

    {player1, player2}
  end

  @doc """
  Creates a ranged combat scenario with appropriate positioning.
  """
  @spec create_ranged_scenario(keyword()) :: {Combatant.t(), Combatant.t()}
  def create_ranged_scenario(opts \\ []) do
    attacker_opts = [
      weapon_type: :bow,
      position: {100, 100}
    ]

    defender_opts = [
      # 10 cells away for ranged testing
      position: {110, 110}
    ]

    attacker = create_player_combatant(Keyword.merge(attacker_opts, opts))
    defender = create_mob_combatant(defender_opts)

    {attacker, defender}
  end
end
