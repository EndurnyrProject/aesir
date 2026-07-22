defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrRedemptio do
  @moduledoc """
  Redemptio (`PR_REDEMPTIO`), the Priest platinum skill that revives nearby
  party corpses at the cost of leaving its caster at one HP.

  Renewal references:
  - `db/re/skill_db.yml:18437-18456`
  - `src/map/skills/acolyte/redemptio.cpp:18-99`
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 1014,
    name: :pr_redemptio,
    display_name: "Redemptio",
    max_level: 1,
    target_type: :self,
    damage_type: :no_damage,
    damage_kind: :magic,
    element: :holy,
    splash_radius: 14,
    cast_time: [3_200],
    fixed_cast_time: [800],
    ignore_dex: true,
    sp_cost: [800]

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  # NOTE: Remove the catalog-only boundary when Priest quest/grant acquisition exists.
  # NOTE: Add WoE/GvG, Battleground, negative PvP-score, and Hell Power gates when
  # Aesir gains each corresponding competitive-mode or status concept.
  # NOTE: Add restart-full, resurrection-EXP, and Redemptio-EXP options here when
  # Aesir gains a matching server-config surface or one of those rules becomes required.
  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%{party_id: 0}, :self, 1, _definition), do: {:error, :party_required}
  def validate(%{party_id: party_id}, :self, 1, _definition) when party_id > 0, do: :ok

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{party_id: 0}, :self, 1, _definition), do: {:error, :party_required}

  def cast(%{character_id: caster_id, party_id: party_id} = caster, :self, 1, definition) do
    with {:ok, party} <- PartyManager.get(party_id),
         [_corpse | _rest] = corpses <- eligible_corpses(party, caster, definition.splash_radius) do
      Enum.each(corpses, fn {target_pid, _target_state} ->
        PlayerSession.resurrect(target_pid, caster_id, 50)
      end)

      {:ok, set_hp_to_one(caster)}
    else
      [] -> {:error, :no_targets}
      {:error, _reason} -> {:error, :party_required}
    end
  end

  defp eligible_corpses(party, caster, splash_radius) do
    party
    |> PartyState.online_members()
    |> Enum.reject(&(&1.char_id == caster.character_id))
    |> Enum.flat_map(&resolve_nearby_corpse(&1.char_id, caster, splash_radius))
  end

  defp resolve_nearby_corpse(char_id, caster, splash_radius) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {PlayerState, target_state, target_pid}} ->
        if nearby_corpse?(target_state, caster, splash_radius),
          do: [{target_pid, target_state}],
          else: []

      {:error, :not_found} ->
        []
    end
  end

  defp nearby_corpse?(target_state, caster, splash_radius) do
    target_state.map_name == caster.map_name and
      Unit.corpse?(target_state) and
      Geometry.in_tile_range?(
        caster.x,
        caster.y,
        target_state.x,
        target_state.y,
        splash_radius
      )
  end

  defp set_hp_to_one(caster) do
    stats = caster.stats
    current_state = stats.current_state
    %{caster | stats: %{stats | current_state: %{current_state | hp: 1}}}
  end
end
