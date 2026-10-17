defmodule Aesir.ZoneServer.Mmo.Mechanics.MobFormulas.PreRenewal do
  @moduledoc """
  Classic mob formulas use unshifted HIT/FLEE and VIT-based soft defenses.

  A monster rolls its `Attack` to `Attack2`, both raised by status weapon ATK,
  and has no status ATK. Its MATK is INT-based, plus flat status MATK, then
  Mystical Amplification. A guardian's Guard Up is its only status ATK.
  """

  @behaviour Aesir.ZoneServer.Mmo.Mechanics.MobFormulas

  alias Aesir.ZoneServer.Mmo.Mechanics.MobFormulas
  alias Aesir.ZoneServer.Mmo.Mechanics.StatusAttack
  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  @impl true
  def calculate_hit(%MobDefinition{} = mob_data) do
    mob_data.level + mob_data.stats.dex
  end

  @impl true
  def calculate_flee(%MobDefinition{} = mob_data) do
    mob_data.level + mob_data.stats.agi
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
  def calculate_soft_defense(%MobDefinition{} = mob_data), do: mob_data.stats.vit

  @impl true
  def attack_bounds(%MobDefinition{atk: atk, atk2: atk2}, modifiers) do
    watk = Map.get(modifiers, :watk, 0)
    {atk + watk, atk2 + watk}
  end

  # A classic monster has no status ATK; Guard Up gives a guardian some, and
  # only then do status ATK modifiers apply (`status_calc_bl_main` runs
  # `status_calc_batk` only for a non-zero base).
  @impl true
  def status_attack(%MobDefinition{}, _str, 0, _modifiers), do: 0

  def status_attack(%MobDefinition{}, _str, guard_up, modifiers),
    do: StatusAttack.modify(guard_up, modifiers)

  @impl true
  def magic_attack_bounds(%MobDefinition{}, int, modifiers) do
    {int + div(int, 7) * div(int, 7), int + div(int, 5) * div(int, 5)}
    |> MobFormulas.add_flat(modifiers)
    |> MobFormulas.amplify(modifiers)
    |> MobFormulas.floor_zero()
  end

  @impl true
  def calculate_magic_defense(%MobDefinition{} = mob_data) do
    mob_data.mdef
  end

  @impl true
  def calculate_soft_mdef(%MobDefinition{} = mob_data) do
    mob_data.stats.int + div(mob_data.stats.vit, 2)
  end
end
