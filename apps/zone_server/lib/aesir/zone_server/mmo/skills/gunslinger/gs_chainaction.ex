defmodule Aesir.ZoneServer.Mmo.Skills.Gunslinger.GsChainaction do
  @moduledoc """
  Chain Action (GS_CHAINACTION): revolver normal attacks have a 5% per level
  chance to strike twice. The proc can be critical in renewal, but not in
  pre-renewal, following each mode's skill DB Critical damage flag.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 511,
    name: :gs_chainaction,
    display_name: "Chain Action",
    max_level: 10,
    target_type: :passive,
    damage_type: :damage,
    range: -9,
    element: :weapon,
    hit_count: 2,
    critical: [renewal: true, pre_renewal: false]

  alias Aesir.ZoneServer.Mmo.Skill.Passive

  @behaviour Passive

  @doc "Returns the revolver-only chance to repeat a normal attack."
  @spec attack_proc(pos_integer(), Passive.ctx()) :: map()
  @impl Passive
  def attack_proc(level, %{weapon_type: :revolver}) do
    proc = %{multi_hit: 2, chance: 5 * level}
    if definition().critical, do: Map.put(proc, :critical, true), else: proc
  end

  def attack_proc(_level, _ctx), do: %{}
end
