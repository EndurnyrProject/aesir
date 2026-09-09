defmodule Aesir.ZoneServer.Mmo.Skills.Wizard.WzSightrasher do
  @moduledoc """
  Sightrasher (WZ_SIGHTRASHER). Consumes Sight into a caster-centered fire burst over
  a 15x15 area that pushes enemies five cells, for 35 to 53 SP.

  Renewal and pre-renewal agree on the burst: 100% plus 20% per level fire MATK.
  Renewal casts in 0.32 s plus 0.08 s fixed with a 2 s delay; pre-renewal in 0.5 s.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 81,
    name: :wz_sightrasher,
    requires: [:player_state],
    display_name: "Sightrasher",
    max_level: 10,
    target_type: :self,
    damage_type: :damage,
    damage_kind: :magic,
    element: :fire,
    range: 0,
    knockback: 5,
    hit_count: 1,
    splash_radius: 7,
    cast_time: [renewal: List.duplicate(320, 10), pre_renewal: List.duplicate(500, 10)],
    fixed_cast_time: [renewal: List.duplicate(80, 10), pre_renewal: []],
    after_cast_delay: List.duplicate(2_000, 10),
    duration: List.duplicate(500, 10),
    sp_cost: [35, 37, 39, 41, 43, 45, 47, 49, 51, 53]

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.Player.PlayerState

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, :sight_required}
  def cast(%{character_id: caster_id, x: x, y: y} = caster, :self, level, definition) do
    with :ok <- require_sight(caster_id) do
      StatusInterpreter.remove_status(:player, caster_id, :sc_sight)

      opts = [
        skill_id: definition.id,
        skill_level: level,
        skill_ratio: 100 + 20 * level,
        element: definition.element,
        split: false,
        base_distance: definition.knockback,
        origin: {x, y}
      ]

      _ = Combat.execute_magic_splash(caster, {x, y}, definition.splash_radius, opts)

      {:ok, caster}
    end
  end

  defp require_sight(caster_id) do
    if StatusStorage.has_status?(:player, caster_id, :sc_sight),
      do: :ok,
      else: {:error, :sight_required}
  end
end
