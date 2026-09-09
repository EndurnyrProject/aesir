defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlIncagi do
  @moduledoc """
  Increase AGI (AL_INCAGI). Grants an ally the SC_INCREASEAGI buff: AGI up by
  `2 + level`, attack speed up by the skill level, and a flat movement haste.
  The buff lasts a minute at level 1 and grows by twenty seconds per level.

  The skill costs the caster HP as well as SP: a flat fifteen HP at every level
  in both modes.

  Renewal: an eight-tenths-of-a-second variable cast plus a fixed two-tenths of
  a second, and a four-tenths-of-a-second after-cast delay.

  Pre-renewal: a flat one-second cast with no fixed component (pre-renewal has no
  fixed-cast concept at all) and a full second of after-cast delay. Buff
  magnitudes and durations are the same in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 29,
    name: :al_incagi,
    requires: [],
    status: :sc_increaseagi,
    display_name: "Increase AGI",
    max_level: 10,
    target_type: :target_ally,
    damage_kind: :magic,
    range: 9,
    sp_cost: [18, 21, 24, 27, 30, 33, 36, 39, 42, 45],
    hp_cost: List.duplicate(15, 10),
    cast_time: [renewal: List.duplicate(800, 10), pre_renewal: List.duplicate(1_000, 10)],
    fixed_cast_time: [renewal: List.duplicate(200, 10), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(400, 10), pre_renewal: List.duplicate(1_000, 10)],
    duration: [
      60_000,
      80_000,
      100_000,
      120_000,
      140_000,
      160_000,
      180_000,
      200_000,
      220_000,
      240_000
    ]

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Active

  @impl Active
  def validate(%{character_id: caster_id}, {:unit, {:homunculus, gid}}, _level, _definition) do
    with {:ok, caster_combatant} <- TargetResolver.resolve_combatant(:player, caster_id),
         {:ok, target_combatant} <- TargetResolver.resolve_combatant(:homunculus, gid),
         true <- Targeting.direct_support?(caster_combatant, target_combatant) do
      :ok
    else
      _ -> {:error, :invalid_target}
    end
  end

  def validate(_caster, {:unit, {:homunculus, _gid}}, _level, _definition),
    do: {:error, :invalid_target}

  def validate(_caster, _target, _level, _definition), do: :ok

  @impl Active
  def cast(caster, target, level, definition) do
    caster_id = Active.caster_unit_id(caster)
    {unit_type, target_id} = target_ref(caster, target)
    duration = Enum.at(definition.duration, level - 1)

    params = [val1: level, val2: 2 + level, caster_id: caster_id, duration: duration]

    # NOTE: Aesir has no SC_CHANGEUNDEAD player misc-attack path. When it exists, add
    # Increase AGI's transformed-player removal/attack branch and remove this note.
    case StatusInterpreter.apply_status(unit_type, target_id, :sc_increaseagi, params) do
      :ok -> {:ok, caster}
      {:error, _reason} = error -> error
    end
  end

  defp target_ref(caster, target), do: Active.target_unit_ref(caster, target)
end
