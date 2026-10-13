defmodule Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.Renewal do
  @moduledoc """
  Renewal mob formulas use the combat HIT/FLEE baselines and level-scaled soft MDEF.

  A monster rolls 80% to 120% of its `Attack` (status weapon ATK is inert) and
  adds status ATK, `STR + level` plus status ATK modifiers. Its MATK is
  `INT + level` plus 70% to 130% of its database MATK, then Mystical
  Amplification, then flat status MATK.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.MobFormulas

  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  @impl true
  def emperium_damage_mode, do: :plant

  @impl true
  def calculate_hit(%MobDefinition{} = mob_data) do
    mob_data.level + mob_data.stats.dex + 150
  end

  @impl true
  def calculate_flee(%MobDefinition{} = mob_data) do
    mob_data.level + mob_data.stats.agi + 100
  end

  @impl true
  def calculate_perfect_dodge(%MobDefinition{}), do: 0

  @impl true
  def calculate_aspd(%MobDefinition{} = mob_data) do
    max(100, 200 - div(mob_data.attack_delay, 10))
  end

  @impl true
  def calculate_base_attack(%MobDefinition{} = mob_data) do
    mob_data.atk
  end

  @impl true
  def calculate_defense(%MobDefinition{} = mob_data) do
    mob_data.def
  end

  @impl true
  def calculate_soft_defense(%MobDefinition{} = mob_data) do
    div(mob_data.level + mob_data.stats.vit, 2)
  end

  @impl true
  def attack_bounds(%MobDefinition{atk: atk}, _modifiers),
    do: {div(atk * 80, 100), div(atk * 120, 100)}

  @impl true
  def status_attack(%MobDefinition{level: level}, str, guard_up, modifiers),
    do: str + level + guard_up + Map.get(modifiers, :batk, 0)

  @impl true
  def magic_attack_bounds(%MobDefinition{level: level, matk: matk}, int, modifiers) do
    {int + level + div(matk * 70, 100), int + level + div(matk * 130, 100)}
    |> MobFormulas.amplify(modifiers)
    |> MobFormulas.add_flat(modifiers)
    |> MobFormulas.floor_zero()
  end

  @impl true
  def calculate_magic_defense(%MobDefinition{} = mob_data) do
    mob_data.mdef
  end

  @impl true
  def calculate_soft_mdef(%MobDefinition{} = mob_data) do
    div(mob_data.stats.int + mob_data.level, 4)
  end
end
