defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Ruwach do
  @moduledoc """
  Ruwach (SC_RUWACH).

  A 10-second self aura backing AL_RUWACH. It re-centers on the caster every
  500ms tick (rAthena's native 20ms is coarsened to 500ms here): each pulse
  reveals concealed units (`:sc_hiding`/`:sc_cloaking`) within radius 2 of the
  caster's current cell and deals a single holy magic splash hit to offensive
  targets in the same radius. The first pulse fires on apply. The caster is
  never revealed or hit. If the caster's position cannot be resolved (logged
  out/dead) the pulse is a safe no-op and the status expires normally.

  rAthena (`skill_db` id 24): `SplashArea: 2`, `Element: Holy`, `Duration1: 10000`,
  status option `Ruwach`; the holy hit's skill ratio is `base (100) + 45`
  (`src/map/skills/acolyte/ruwach.cpp`).
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_ruwach,
    properties: [:buff],
    duration: 10_000,
    tick_interval: 500,
    no_save: true,
    option: :ruwach

  alias Aesir.ZoneServer.Mmo.Combat
  alias Aesir.ZoneServer.Mmo.StatusEffect.Helpers
  alias Aesir.ZoneServer.Unit.SpatialIndex

  @skill_id 24
  @skill_level 1
  @radius 2
  @skill_ratio 145
  @hidden_statuses [:sc_hiding, :sc_cloaking]

  @impl true
  def on_apply({unit_type, _unit_id}, instance, %{target_id: caster_id}) do
    pulse(unit_type, caster_id)
    {:ok, instance}
  end

  @impl true
  def on_tick({unit_type, _unit_id}, instance, %{target_id: caster_id}) do
    pulse(unit_type, caster_id)
    {:ok, instance}
  end

  @spec pulse(atom(), integer()) :: :ok
  defp pulse(unit_type, caster_id) do
    case SpatialIndex.get_unit_position(unit_type, caster_id) do
      {:ok, {x, y, map_name}} ->
        reveal_concealed(map_name, x, y, {unit_type, caster_id})
        splash_enemies(map_name, x, y, caster_id)

      {:error, :not_found} ->
        :ok
    end
  end

  @spec reveal_concealed(String.t(), integer(), integer(), {atom(), integer()}) :: :ok
  defp reveal_concealed(map_name, x, y, caster) do
    map_name
    |> SpatialIndex.get_all_units_in_range(x, y, @radius)
    |> Enum.reject(&(&1 == caster))
    |> Enum.each(&Helpers.remove_statuses(&1, @hidden_statuses))
  end

  @spec splash_enemies(String.t(), integer(), integer(), integer()) :: :ok
  defp splash_enemies(map_name, x, y, caster_id) do
    case Combat.resolve_combatant(caster_id) do
      {:ok, caster} ->
        map_name
        |> Combat.splash_targets({x, y}, @radius, caster_id)
        |> Enum.each(fn {unit_type, target_id} ->
          Combat.apply_skill_unit_damage(
            caster,
            unit_type,
            target_id,
            @skill_id,
            @skill_level,
            :holy,
            @skill_ratio
          )
        end)

      {:error, _reason} ->
        :ok
    end
  end
end
