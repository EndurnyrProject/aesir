defmodule Aesir.ZoneServer.Mmo.Mechanics do
  @moduledoc """
  Resolves formula families for the active game mode.
  """

  alias Aesir.Commons.GameMode

  alias Aesir.ZoneServer.Mmo.Mechanics.CastTime
  alias Aesir.ZoneServer.Mmo.Mechanics.Defense
  alias Aesir.ZoneServer.Mmo.Mechanics.Elements
  alias Aesir.ZoneServer.Mmo.Mechanics.HomunculusFormulas
  alias Aesir.ZoneServer.Mmo.Mechanics.MagicDamage
  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas
  alias Aesir.ZoneServer.Mmo.Mechanics.PhysicalAttack
  alias Aesir.ZoneServer.Mmo.Mechanics.PlayerFormulas
  alias Aesir.ZoneServer.Mmo.Mechanics.Sizes
  alias Aesir.ZoneServer.Mmo.Mechanics.StatCost

  @pt_key __MODULE__
  @families %{
    player_formulas: %{
      renewal: PlayerFormulas.Renewal,
      pre_renewal: PlayerFormulas.PreRenewal
    },
    mob_formulas: %{
      renewal: MobFormulas.Renewal,
      pre_renewal: MobFormulas.PreRenewal
    },
    homunculus_formulas: %{
      renewal: HomunculusFormulas.Renewal,
      pre_renewal: HomunculusFormulas.PreRenewal
    },
    physical_attack: %{
      renewal: PhysicalAttack.Renewal,
      pre_renewal: PhysicalAttack.PreRenewal
    },
    magic_damage: %{
      renewal: MagicDamage.Renewal,
      pre_renewal: MagicDamage.PreRenewal
    },
    cast_time: %{
      renewal: CastTime.Renewal,
      pre_renewal: CastTime.PreRenewal
    },
    stat_cost: %{
      renewal: StatCost.Renewal,
      pre_renewal: StatCost.PreRenewal
    },
    defense: %{
      renewal: Defense.Renewal,
      pre_renewal: Defense.PreRenewal
    },
    elements: %{
      renewal: Elements.Renewal,
      pre_renewal: Elements.PreRenewal
    },
    sizes: %{
      renewal: Sizes.Renewal,
      pre_renewal: Sizes.PreRenewal
    }
  }

  @doc "Resolves and caches every formula family for the active game mode."
  @spec resolve!() :: :ok
  def resolve! do
    ensure_implementations_loaded!()
    mode = GameMode.mode()

    implementations =
      Map.new(@families, fn {family, modes} ->
        {family, Map.fetch!(modes, mode)}
      end)

    :persistent_term.put(@pt_key, implementations)
    :ok
  end

  @doc "Returns the active player formula implementation."
  @spec player_formulas() :: module()
  def player_formulas, do: implementation(:player_formulas)

  @doc "Returns the active mob formula implementation."
  @spec mob_formulas() :: module()
  def mob_formulas, do: implementation(:mob_formulas)

  @doc "Returns the active Homunculus stat formula implementation."
  @spec homunculus_formulas() :: module()
  def homunculus_formulas, do: implementation(:homunculus_formulas)

  @doc "Returns the active player physical-attack implementation."
  @spec physical_attack() :: module()
  def physical_attack, do: implementation(:physical_attack)

  @doc "Returns the active ordinary magic-damage implementation."
  @spec magic_damage() :: module()
  def magic_damage, do: implementation(:magic_damage)

  @doc "Returns the active cast-time implementation."
  @spec cast_time() :: module()
  def cast_time, do: implementation(:cast_time)

  @doc "Returns the active stat-cost implementation."
  @spec stat_cost() :: module()
  def stat_cost, do: implementation(:stat_cost)

  @doc "Returns the active defense implementation."
  @spec defense() :: module()
  def defense, do: implementation(:defense)

  @doc "Returns the active element implementation."
  @spec elements() :: module()
  def elements, do: implementation(:elements)

  @doc "Returns the active size implementation."
  @spec sizes() :: module()
  def sizes, do: implementation(:sizes)

  defp implementation(family) do
    case :persistent_term.get(@pt_key, nil) do
      nil -> @families |> Map.fetch!(family) |> Map.fetch!(GameMode.mode())
      implementations -> Map.fetch!(implementations, family)
    end
  end

  defp ensure_implementations_loaded! do
    for {_family, modes} <- @families, {_mode, module} <- modes do
      unless Code.ensure_loaded?(module) do
        raise "Mechanics implementation module #{inspect(module)} could not be loaded"
      end
    end
  end
end
