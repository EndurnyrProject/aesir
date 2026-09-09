defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzHeavendrive do
  @moduledoc """
  Heaven's Drive (WZ_HEAVENDRIVE). Ground-targeted 5x5 Earth magic splash.

  A level `n` cast immediately dispatches `n` independent 125% MATK hits through
  the shared magic splash pipeline. The cast interpreter validates ground range,
  map bounds, and walkability before calling this module; no persistent skill
  unit is created.


  Renewal: 125% MATK per hit with a fixed cast part, a 0.5 s delay, and a 1 s cooldown. Pre-renewal: 100% MATK per hit, a 1 s per level variable cast, a 1 s delay, and no cooldown.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 91,
    name: :wz_heavendrive,
    requires: [],
    display_name: "Heaven's Drive",
    max_level: 5,
    target_type: :ground,
    damage_type: :damage,
    damage_kind: :magic,
    range: 9,
    element: :earth,
    splash_radius: 2,
    cast_time: [
      renewal: [1_100, 1_300, 1_500, 1_700, 1_900],
      pre_renewal: [1000, 2000, 3000, 4000, 5000]
    ],
    fixed_cast_time: [renewal: List.duplicate(800, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(1000, 5)],
    cooldown: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    sp_cost: [28, 32, 36, 40, 44]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @doc "Renewal deals 125% MATK per hit; classic 100%."
  @spec skill_ratio() :: pos_integer()
  def skill_ratio, do: if(GameMode.mode() == :renewal, do: 125, else: 100)

  @impl Active
  def cast(caster, {:ground, x, y}, level, definition) do
    opts = [
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: skill_ratio(),
      element: definition.element,
      split: false,
      hit_count: level
    ]

    caster
    |> Combat.execute_magic_splash({x, y}, definition.splash_radius, opts)
    |> Enum.each(&remove_root_twist/1)

    {:ok, caster}
  end

  @spec remove_root_twist({:mob | :player, integer()}) :: :ok
  defp remove_root_twist({unit_type, target_id}) do
    StatusInterpreter.remove_status(unit_type, target_id, :sc_sv_roottwist)
  end
end
