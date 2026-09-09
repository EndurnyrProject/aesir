defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrMagnificat do
  @moduledoc """
  Magnificat (PR_MAGNIFICAT). Doubles natural SP regeneration for the caster and
  every living same-map party member nearby, for 30 s plus 15 s per level and 40 SP.

  Renewal reaches party members within 18 cells and casts in 3.2 s plus 0.8 s fixed;
  pre-renewal reaches the default 14-cell area and casts in 4 s.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 74,
    name: :pr_magnificat,
    status: :sc_magnificat,
    display_name: "Magnificat",
    max_level: 5,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    splash_radius: [renewal: 18, pre_renewal: 14],
    cast_time: [renewal: List.duplicate(3_200, 5), pre_renewal: List.duplicate(4_000, 5)],
    fixed_cast_time: [renewal: List.duplicate(800, 5), pre_renewal: []],
    after_cast_delay: List.duplicate(2_000, 5),
    duration: [30_000, 45_000, 60_000, 75_000, 90_000],
    sp_cost: List.duplicate(40, 5)

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
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

    case StatusInterpreter.apply_status(:player, caster_id, :sc_magnificat, params) do
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
    |> Enum.each(&StatusInterpreter.apply_status(:player, &1, :sc_magnificat, params))
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
          Unit.living?(player_state) and
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
