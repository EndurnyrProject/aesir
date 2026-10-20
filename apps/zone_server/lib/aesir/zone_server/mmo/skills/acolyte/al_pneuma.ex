defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlPneuma do
  @moduledoc """
  Pneuma (AL_PNEUMA). Ground-targeted protective field.

  Places a 3x3 skill-unit footprint at the target location. Occupants receive
  `sc_pneuma`, which blocks all long-ranged physical hits; melee and magic pass
  through unchanged. There is no hit or shield budget.

  Mirrors Safety Wall structurally; the differences are the blocked damage
  direction (ranged vs. melee), the 3x3 footprint (Safety Wall is single-cell),
  and the absence of a shared hit/shield budget.

  The footprint is a fixed 3x3 square around the target cell. It comes from the
  skill unit's own layout, not from a splash area — the skill declares no splash
  radius, matching a source row that has none.

  The field has no periodic tick. It grants the status when it is placed and as
  units step in, and removes it when they step off or the field ends, as
  `Aesir.ZoneServer.Mmo.Skills.Shared.CellStatus` describes. The status lasts
  the field's whole ten seconds from the moment it is granted.

  Renewal: single level, ten SP, no cast time, range nine, ten-second field.

  Pre-renewal: identical in every declared value and in behaviour. Pneuma has no
  mode-specific branch: the same 3x3 footprint, the same duration, and the same
  blanket block on long-ranged physical damage.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 25,
    name: :al_pneuma,
    no_reiteration: true,
    unit_layout: 1,
    ranged_single_unit: true,
    requires: [],
    display_name: "Pneuma",
    max_level: 1,
    target_type: :ground,
    damage_type: :no_damage,
    damage_kind: :magic,
    range: 9,
    hit_interval: 1_000,
    unit_duration: [10_000],
    sp_cost: [10]

  alias Aesir.ZoneServer.Mmo.Skill.Ground
  alias Aesir.ZoneServer.Mmo.Skill.Unit
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Layout
  alias Aesir.ZoneServer.Mmo.Skills.Shared.CellStatus
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter

  @behaviour Ground

  @footprint_radius 1

  @doc "Places the field and grants `sc_pneuma` to the units already standing in it."
  @spec cast_with_origin(
          struct(),
          {:ground, integer(), integer()},
          pos_integer(),
          struct(),
          atom()
        ) ::
          {:ok, struct()} | {:error, term()}
  def cast_with_origin(caster, {:ground, x, y}, level, _definition, origin) do
    case Unit.place(caster, :al_pneuma, level, {x, y}, origin: origin) do
      {:ok, group} ->
        CellStatus.grant_occupants(group, definition(), :sc_pneuma, grant_params(group))
        {:ok, caster}

      {:error, reason} ->
        if Unit.paid_refusal?(reason), do: {:ok, caster}, else: {:error, reason}
    end
  end

  @impl Ground
  @spec on_place(Group.t()) :: {:ok, Ground.placement()}
  def on_place(%Group{center: center, level: level}) do
    definition = definition()

    {:ok,
     %{
       cells: Layout.square(center, @footprint_radius),
       state: %{},
       interval: definition.hit_interval,
       duration: Enum.at(definition.unit_duration, level - 1)
     }}
  end

  @impl Ground
  def schedule(%Group{} = group, _rng), do: {:ok, %{group | next_tick_at: nil}}

  @impl Ground
  @spec on_interval(Group.t(), integer()) :: {:ok, Group.t()}
  def on_interval(%Group{} = group, _now), do: {:ok, group}

  @impl Ground
  def on_touch(%Group{} = group, mover) do
    CellStatus.grant(group, definition(), :sc_pneuma, grant_params(group), mover)
    {:ok, group}
  end

  @impl Ground
  @spec on_out(Group.t(), {atom(), integer()}) :: {:ok, Group.t()}
  def on_out(%Group{} = group, {unit_type, unit_id}) do
    StatusInterpreter.remove_status(unit_type, unit_id, :sc_pneuma)
    {:ok, group}
  end

  # The status lasts the field's whole lifetime from the moment it is granted.
  defp grant_params(%Group{level: level, group_id: group_id}),
    do: [val1: level, val2: group_id, duration: Enum.at(definition().unit_duration, level - 1)]
end
