defmodule Aesir.ZoneServer.Mmo.Skills.Acolyte.AlAngelus do
  @moduledoc """
  Angelus (AL_ANGELUS). Applies SC_ANGELUS to the caster; when the caster is
  in a party, also splashes it (best-effort, caster's own result is what the
  cast returns) to online party members on the same map within
  `splash_radius` cells.

  rAthena: val1 = skill level, val2 = 5 * level (VIT DEF% bonus),
  duration = 30s per level (30s → 300s), identical for every recipient.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 33,
    name: :al_angelus,
    status: :sc_angelus,
    display_name: "Angelus",
    max_level: 10,
    target_type: :self,
    splash_radius: 18,
    sp_cost: [23, 26, 29, 32, 35, 38, 41, 44, 47, 50],
    cast_time: List.duplicate(350, 10),
    fixed_cast_time: List.duplicate(150, 10),
    after_cast_delay: List.duplicate(500, 10),
    cooldown: List.duplicate(30_000, 10)

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
    params = [val1: level, val2: 5 * level, caster_id: caster_id, duration: 30_000 * level]

    case StatusInterpreter.apply_status(:player, caster_id, :sc_angelus, params) do
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
    |> Enum.each(&StatusInterpreter.apply_status(:player, &1, :sc_angelus, params))
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
