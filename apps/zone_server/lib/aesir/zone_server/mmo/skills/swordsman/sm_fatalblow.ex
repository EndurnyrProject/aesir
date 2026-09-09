defmodule Aesir.ZoneServer.Mmo.Skills.Swordsman.SmFatalblow do
  @moduledoc """
  Fatal Blow (SM_FATALBLOW). A quest-granted passive that adds a stun rider to
  Bash once Bash is cast above level 5.

  Renewal: on a landed Bash above level 5 the target is stunned for 4.5
  seconds, with a chance in hundredths of a percent of
  `(bash_level - 5) * caster_base_level * 10`, so both extra Bash levels and
  caster base level raise the stun rate.

  Pre-renewal: the same trigger condition and the same chance formula; only the
  stun lasts longer, a full 5 seconds.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 145,
    name: :sm_fatalblow,
    display_name: "Fatal Blow",
    max_level: 1,
    target_type: :passive,
    quest_skill: true,
    quest_owner_job: :swordman

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def skill_rider(:sm_bash, bash_level, _passive_level, %{base_level: base_level})
      when bash_level > 5 do
    chance = (bash_level - 5) * base_level * 10
    {:apply_status, :sc_stun, chance: chance, duration: stun_duration()}
  end

  def skill_rider(_target_skill, _target_skill_level, _passive_level, _ctx), do: :none

  defp stun_duration do
    case GameMode.mode() do
      :renewal -> 4_500
      :pre_renewal -> 5_000
    end
  end
end
