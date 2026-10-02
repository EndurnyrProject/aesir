defmodule Aesir.ZoneServer.Mmo.Skills.Paladin.PaPressure do
  @moduledoc """
  Gloria Domini (PA_PRESSURE). A 9-cell ranged strike for 30 to 50 SP whose
  whole damage path differs between modes.

  Renewal: a Holy magic attack at `(500 + 150 * level)` percent of MATK scaled
  by the caster's base level over 100, shown as three hits, through the normal
  magic pipeline (MDEF, element, Devotion). 1 s cast plus 0.4 s fixed, 1 s
  after-cast delay.

  Pre-renewal: fixed Misc damage of `500 + 300 * level` that ignores the
  target's DEF, FLEE, element and cards, cannot be redirected by Devotion, and
  drains `15 + 5 * level` percent of a player target's maximum SP (mobs keep
  theirs). A hiding target is refused after the cast cost is paid. Cast and
  after-cast delay both run 2 to 4 s by level. Not modelled: the strike
  counting as a weapon hit for autospell procs, and its immunity to siege and
  battleground damage rates.

  Caster-generic: mob rows cast the same module, scaling by the mob's level.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 367,
    name: :pa_pressure,
    requires: [],
    display_name: "Gloria Domini",
    max_level: 5,
    target_type: :target_enemy,
    damage_type: :damage,
    damage_kind: [renewal: :magic, pre_renewal: :misc],
    hit_count: [renewal: 3, pre_renewal: 1],
    element: [renewal: :holy, pre_renewal: :neutral],
    range: List.duplicate(9, 5),
    sp_cost: [30, 35, 40, 45, 50],
    cast_time: [
      renewal: List.duplicate(1_000, 5),
      pre_renewal: [2_000, 2_500, 3_000, 3_500, 4_000]
    ],
    fixed_cast_time: [renewal: List.duplicate(400, 5), pre_renewal: List.duplicate(0, 5)],
    after_cast_delay: [
      renewal: List.duplicate(1_000, 5),
      pre_renewal: [2_000, 2_500, 3_000, 3_500, 4_000]
    ]

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(Active.caster(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, Active.caster()} | {:error, atom()}
  def cast(caster, {:unit, target_id}, level, definition) do
    result =
      case GameMode.mode() do
        :renewal -> magic_strike(caster, target_id, level, definition)
        :pre_renewal -> misc_strike(caster, target_id, level, definition)
      end

    case result do
      :ok -> {:ok, caster}
      {:ok, _ref} -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp magic_strike(caster, target_id, level, definition) do
    Combat.execute_magic_attack(caster, target_id,
      skill_id: definition.id,
      skill_level: level,
      skill_ratio: div((500 + 150 * level) * base_level(caster), 100),
      element: :holy,
      hit_count: 1,
      display_hit_count: 3,
      skip_range: true
    )
  end

  defp misc_strike(caster, target_id, level, definition) do
    with {:ok, target} <- Combat.resolve_combatant(target_id),
         :ok <- refuse_hidden(target),
         :ok <-
           Combat.execute_misc_attack(caster, target_id,
             skill_id: definition.id,
             skill_level: level,
             base_damage: 500 + 300 * level,
             ignore_element: true
           ) do
      drain_sp(target, 15 + 5 * level)
    end
  end

  defp refuse_hidden(%Combatant{unit_type: unit_type, unit_id: unit_id}) do
    if StatusStorage.has_status?(unit_type, unit_id, :sc_hiding),
      do: {:error, :target_hidden},
      else: :ok
  end

  defp drain_sp(%Combatant{unit_type: :player, unit_id: id, max_sp: max_sp}, percent)
       when is_integer(max_sp),
       do: Helpers.consume_sp({:player, id}, div(max_sp * percent, 100))

  defp drain_sp(_target, _percent), do: :ok

  defp base_level(%PlayerState{stats: %{progression: %{base_level: level}}}), do: level
  defp base_level(%MobState{mob_data: %{level: level}}), do: level
end
