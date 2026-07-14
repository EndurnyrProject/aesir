defmodule Aesir.ZoneServer.Mmo.Skills.WzSightrasher do
  @moduledoc """
  Sightrasher (WZ_SIGHTRASHER). Sight-gated, caster-centered Fire magic that
  damages enemies in a 15x15 area and knocks them back five cells.

  Renewal data comes from rAthena `db/re/skill_db.yml:3015-3062`: skill 81,
  radius 7, one Fire hit, five-cell knockback, 320ms variable plus 80ms fixed
  cast, 2,000ms aftercast delay, and 35-53 SP. The attack consumes Sight before
  dealing `100 + 20 * level` percent MATK (`skills/mage/sightrasher.cpp:12-28`).
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 81,
    name: :wz_sightrasher,
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
    cast_time: List.duplicate(320, 10),
    fixed_cast_time: List.duplicate(80, 10),
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
        split: false
      ]

      caster
      |> Combat.execute_magic_splash({x, y}, definition.splash_radius, opts)
      |> Enum.each(fn {unit_type, target_id} ->
        Combat.knockback(unit_type, target_id, x, y, definition.knockback)
      end)

      {:ok, caster}
    end
  end

  defp require_sight(caster_id) do
    if StatusStorage.has_status?(:player, caster_id, :sc_sight),
      do: :ok,
      else: {:error, :sight_required}
  end
end
