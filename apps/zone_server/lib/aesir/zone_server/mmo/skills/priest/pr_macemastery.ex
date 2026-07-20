defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrMacemastery do
  @moduledoc """
  Mace Mastery (PR_MACEMASTERY). Grants flat weapon ATK and critical while
  wielding a mace or two-handed mace.

  rAthena Renewal: `+3` weapon ATK per level (`battle.cpp:2366-2370`) and
  `+10` critical per level (`status.cpp:4528-4532`), both gated on `W_MACE` or
  `W_2HMACE`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 65,
    name: :pr_macemastery,
    display_name: "Mace Mastery",
    max_level: 10,
    target_type: :passive

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @impl Passive
  def atk_bonus(level, %{weapon_type: weapon}) when weapon in [:mace, :two_handed_mace],
    do: 3 * level

  def atk_bonus(_level, _ctx), do: 0

  @impl Passive
  def critical_bonus(level, %{weapon_type: weapon}) when weapon in [:mace, :two_handed_mace],
    do: 10 * level

  def critical_bonus(_level, _ctx), do: 0
end
