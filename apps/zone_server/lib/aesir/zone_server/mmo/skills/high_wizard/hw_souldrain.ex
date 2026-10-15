defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwSouldrain do
  @moduledoc """
  Soul Drain (HW_SOULDRAIN). High Wizard passive.

  Raises max SP by 2% per level. When the High Wizard kills a monster with a
  targeted spell (a single-target enemy or any-target skill), they regain
  `mob_level * (95 + 15 * level) / 100` SP. Ground and self spells, weapon
  blows and basic attacks grant nothing.

  Identical in renewal and pre-renewal.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 364,
    name: :hw_souldrain,
    display_name: "Soul Drain",
    max_level: 10,
    target_type: :passive,
    damage_kind: :magic

  alias Aesir.ZoneServer.Mmo.Skill.Catalog
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def max_sp_rate_bonus(level, _ctx), do: 2 * level

  @impl Passive
  def kill_sp_gain(level, %{kill_bf: :magic, skill_id: skill_id, mob_level: mob_level})
      when is_integer(skill_id) do
    case Catalog.by_id(skill_id) do
      {:ok, %{target_type: type}} when type not in [:ground, :self, :passive] ->
        div(mob_level * (95 + 15 * level), 100)

      _other ->
        0
    end
  end

  def kill_sp_gain(_level, _kill), do: 0
end
