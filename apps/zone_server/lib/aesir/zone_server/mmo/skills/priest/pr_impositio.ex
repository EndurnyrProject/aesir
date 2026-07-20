defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrImpositio do
  @moduledoc """
  Impositio Manus (PR_IMPOSITIO).

  Renewal references:
  - `db/re/skill_db.yml:2331-2379` — ID, levels, party radius, timings, cost, and duration.
  - `src/map/skills/acolyte/impositiomanus.cpp:11-27` — self/no-party and same-map party propagation.
  - `src/map/status.cpp:10731-10734,11623-11625` — replacement and `5 * level` WATK/MATK.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 66,
    name: :pr_impositio,
    status: :sc_impositio,
    display_name: "Impositio Manus",
    max_level: 5,
    target_type: :self,
    splash_radius: 18,
    sp_cost: [59, 62, 65, 68, 71],
    cast_time: List.duplicate(1_000, 5),
    fixed_cast_time: List.duplicate(500, 5),
    after_cast_delay: List.duplicate(1_000, 5),
    cooldown: List.duplicate(30_000, 5),
    duration: List.duplicate(120_000, 5)

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.TargetState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{character_id: caster_id} = caster, :self, level, definition) do
    params = [val1: level, val2: 5 * level, caster_id: caster_id, duration: 120_000]

    case StatusInterpreter.apply_status(:player, caster_id, :sc_impositio, params) do
      :ok ->
        splash_to_party(caster_id, caster, definition.splash_radius, params)
        {:ok, caster}

      {:error, _reason} = error ->
        error
    end
  end

  defp splash_to_party(caster_id, caster, splash_radius, params) do
    caster_id
    |> nearby_party_member_ids(caster, splash_radius)
    |> Enum.each(&StatusInterpreter.apply_status(:player, &1, :sc_impositio, params))
  end

  defp nearby_party_member_ids(caster_id, caster, splash_radius) do
    case Map.get(caster, :party_id, 0) do
      0 -> []
      party_id -> party_members_in_range(party_id, caster_id, caster, splash_radius)
    end
  end

  defp party_members_in_range(party_id, caster_id, caster, splash_radius) do
    case PartyManager.get(party_id) do
      {:ok, party_state} ->
        party_state
        |> PartyState.online_members()
        |> Enum.reject(&(&1.char_id == caster_id))
        |> Enum.filter(&nearby?(&1.char_id, caster, splash_radius))
        |> Enum.map(& &1.char_id)

      {:error, _reason} ->
        []
    end
  end

  defp nearby?(char_id, caster, splash_radius) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, player_state, _pid}} ->
        player_state.map_name == caster.map_name and
          TargetState.living?(player_state) and
          Geometry.in_tile_range?(
            caster.x,
            caster.y,
            player_state.x,
            player_state.y,
            splash_radius
          )

      {:error, :not_found} ->
        false
    end
  end
end
