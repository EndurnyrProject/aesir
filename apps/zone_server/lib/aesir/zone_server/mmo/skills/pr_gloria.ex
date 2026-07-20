defmodule Aesir.ZoneServer.Mmo.Skills.PrGloria do
  @moduledoc """
  Gloria (PR_GLORIA), the Renewal party-wide LUK buff.

  Renewal reference: `db/re/skill_db.yml:2647-2674`.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 75,
    name: :pr_gloria,
    status: :sc_gloria,
    display_name: "Gloria",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    splash_radius: 18,
    cast_time: List.duplicate(0, 5),
    fixed_cast_time: List.duplicate(0, 5),
    after_cast_delay: List.duplicate(2_000, 5),
    duration: [10_000, 15_000, 20_000, 25_000, 30_000],
    sp_cost: List.duplicate(20, 5)

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
    params = [
      val1: level,
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    ]

    case StatusInterpreter.apply_status(:player, caster_id, :sc_gloria, params) do
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
    |> Enum.each(&StatusInterpreter.apply_status(:player, &1, :sc_gloria, params))
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
