defmodule Aesir.ZoneServer.Mmo.Skills.HighWizard.HwNapalmvulcan do
  @moduledoc """
  Napalm Vulcan (HW_NAPALMVULCAN). Ghost magic that strikes the target and every
  enemy within one cell of it for one round per level, cursing each struck unit
  with a 5% per level chance.

  Renewal: each round deals `70 * level` percent MATK scaled by base level / 100
  to every target (base level / 100 only above level 99); the curse lasts 18 s. 30 to 70 SP, 0.8 s cast plus 0.2 s
  fixed, 0.5 s after-cast delay and a 1 s cooldown.

  Pre-renewal: each round deals 125% MATK split evenly among the targets; the
  curse lasts 30 s. 10 to 70 SP, 1 s cast, 1 s after-cast delay, no cooldown.

  Monsters cast it through `cast/4`, which is caster-generic.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 400,
    name: :hw_napalmvulcan,
    requires: [],
    display_name: "Napalm Vulcan",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: :magic,
    element: :ghost,
    range: 9,
    splash_radius: 1,
    sp_cost: [renewal: [30, 40, 50, 60, 70], pre_renewal: [10, 25, 40, 55, 70]],
    cast_time: [renewal: List.duplicate(800, 5), pre_renewal: List.duplicate(1_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(200, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(500, 5), pre_renewal: List.duplicate(1_000, 5)],
    cooldown: [renewal: List.duplicate(1_000, 5), pre_renewal: []]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.LevelModifier
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    with {:ok, %{position: center}} <- Combat.resolve_combatant(target_id) do
      combatant = caster.__struct__.to_combatant(caster)

      caster
      |> Combat.execute_magic_splash(center, definition.splash_radius,
        skill_id: definition.id,
        skill_level: level,
        hit_divisions: level,
        element: definition.element,
        skill_ratio: ratio(combatant, level),
        split: GameMode.mode() == :pre_renewal
      )
      |> Enum.uniq()
      |> Enum.each(&maybe_curse(&1, combatant, level))

      {:ok, caster}
    end
  end

  @doc "Per-round MATK percent: `70 * level` scaled by base level in renewal, 125 in classic."
  @spec ratio(map(), pos_integer()) :: pos_integer()
  def ratio(%{progression: %{base_level: base_level}}, level) do
    case GameMode.mode() do
      :renewal -> LevelModifier.skill_ratio(70 * level, base_level)
      :pre_renewal -> 125
    end
  end

  defp maybe_curse({type, id}, combatant, level) do
    if Resistance.roll_success(5 * level) do
      StatusInterpreter.apply_status(type, id, :sc_curse,
        duration: curse_ms(),
        caster_id: combatant.unit_id,
        source_type: combatant.unit_type
      )
    end
  end

  defp curse_ms do
    case GameMode.mode() do
      :renewal -> 18_000
      :pre_renewal -> 30_000
    end
  end
end
