defmodule Aesir.ZoneServer.Mmo.Mechanics.MobFormulas do
  @moduledoc """
  Pure mob-stat formula leaves over static mob definitions.
  """

  alias Aesir.ZoneServer.Mmo.MobManagement.MobDefinition

  @typedoc "Mob definition used by formula implementations."
  @type mob_data :: MobDefinition.t()

  @callback calculate_hit(mob_data()) :: integer()
  @callback calculate_flee(mob_data()) :: integer()
  @callback calculate_perfect_dodge(mob_data()) :: integer()
  @callback calculate_aspd(mob_data()) :: integer()
  @callback calculate_base_attack(mob_data()) :: integer()
  @callback calculate_defense(mob_data()) :: integer()
  @callback calculate_soft_defense(mob_data()) :: integer()
  @callback calculate_magic_attack(mob_data()) :: integer()
  @callback calculate_magic_defense(mob_data()) :: integer()
  @callback calculate_soft_mdef(mob_data()) :: integer()
end
