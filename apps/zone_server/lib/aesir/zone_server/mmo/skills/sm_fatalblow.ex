defmodule Aesir.ZoneServer.Mmo.Skills.SmFatalblow do
  @moduledoc """
  Fatal Blow (SM_FATALBLOW). Adds a stun rider to Bash (SM_BASH) once Bash is
  used at a level above 5.

  rAthena (`SkillBash::applyAdditionalEffects`): when `skill_lv > 5`, applies
  SC_STUN with chance `(skill_lv - 5) * base_level * 10` (in 1/100% units) for
  `skill_get_time2(SM_BASH, skill_lv)` ms (SM_BASH `Duration2`).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 145,
    name: :sm_fatalblow,
    display_name: "Fatal Blow",
    max_level: 1,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @stun_duration 4_500

  @behaviour Passive

  @impl Passive
  def skill_rider(:sm_bash, bash_level, _passive_level, %{base_level: base_level})
      when bash_level > 5 do
    chance = (bash_level - 5) * base_level * 10
    {:apply_status, :sc_stun, chance: chance, duration: @stun_duration}
  end

  def skill_rider(_target_skill, _target_skill_level, _passive_level, _ctx), do: :none
end
