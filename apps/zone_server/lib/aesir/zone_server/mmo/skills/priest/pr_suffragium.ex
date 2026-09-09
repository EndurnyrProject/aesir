defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrSuffragium do
  @moduledoc """
  Suffragium (PR_SUFFRAGIUM). Shortens the variable cast time of the next casts.

  Renewal: a self-cast that also reaches every living same-map party member within
  18 cells, cutting variable cast by 10, 15, or 20% for a full minute (the buff is
  not consumed by casting), with a 1 s cast plus 0.5 s fixed, a 1 s delay, and a
  30 s cooldown. Pre-renewal: a single-target support cast at 9 cells cutting cast
  time by 15% per level for 30, 20, or 10 s, consumed by the receiver's next skill
  cast, with no cast time and a 2 s delay. Both modes cost 8 SP.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 67,
    name: :pr_suffragium,
    status: :sc_suffragium,
    display_name: "Suffragium",
    max_level: 3,
    target_type: [renewal: :self, pre_renewal: :target_ally],
    damage_kind: :magic,
    range: 9,
    splash_radius: [renewal: 18, pre_renewal: 0],
    sp_cost: List.duplicate(8, 3),
    cast_time: [renewal: List.duplicate(1_000, 3), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(500, 3), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 3), pre_renewal: List.duplicate(2_000, 3)],
    cooldown: [renewal: List.duplicate(30_000, 3), pre_renewal: []],
    duration: [renewal: List.duplicate(60_000, 3), pre_renewal: [30_000, 20_000, 10_000]]

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
    params = params(caster_id, level, definition)

    with :ok <- StatusInterpreter.apply_status(:player, caster_id, :sc_suffragium, params) do
      if definition.target_type == :self,
        do: splash_to_party(caster_id, caster, definition.splash_radius, params)

      {:ok, caster}
    end
  end

  def cast(%{character_id: caster_id} = caster, {:unit, target_id}, level, definition) do
    with :ok <-
           StatusInterpreter.apply_status(
             :player,
             target_id,
             :sc_suffragium,
             params(caster_id, level, definition)
           ) do
      {:ok, caster}
    end
  end

  defp params(caster_id, level, definition) do
    [val1: level, caster_id: caster_id, duration: Enum.at(definition.duration, level - 1)]
  end

  defp splash_to_party(caster_id, caster, splash_radius, params) do
    caster_id
    |> nearby_party_member_ids(caster, splash_radius)
    |> Enum.each(&StatusInterpreter.apply_status(:player, &1, :sc_suffragium, params))
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
