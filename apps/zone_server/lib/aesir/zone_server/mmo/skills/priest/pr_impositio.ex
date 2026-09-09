defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrImpositio do
  @moduledoc """
  Impositio Manus (PR_IMPOSITIO). Raises weapon attack by 5 per level (renewal also
  raises magic attack by the same amount).

  Renewal: a self-cast that also reaches every living same-map party member within
  18 cells, lasting 2 minutes, for 59 to 71 SP with a 1 s cast plus 0.5 s fixed, a
  1 s delay, and a 30 s cooldown. Pre-renewal: a single-target support cast at 9
  cells lasting 1 minute, for 13 to 25 SP with no cast and a 3 s delay. A higher
  level already active is replaced by the new cast in both modes.
  """
  use Aesir.ZoneServer.Mmo.Skill,
    id: 66,
    name: :pr_impositio,
    status: :sc_impositio,
    display_name: "Impositio Manus",
    max_level: 5,
    target_type: [renewal: :self, pre_renewal: :target_ally],
    damage_kind: :magic,
    range: 9,
    splash_radius: [renewal: 18, pre_renewal: 0],
    sp_cost: [renewal: [59, 62, 65, 68, 71], pre_renewal: [13, 16, 19, 22, 25]],
    cast_time: [renewal: List.duplicate(1_000, 5), pre_renewal: []],
    fixed_cast_time: [renewal: List.duplicate(500, 5), pre_renewal: []],
    after_cast_delay: [renewal: List.duplicate(1_000, 5), pre_renewal: List.duplicate(3_000, 5)],
    cooldown: [renewal: List.duplicate(30_000, 5), pre_renewal: []],
    duration: [renewal: List.duplicate(120_000, 5), pre_renewal: List.duplicate(60_000, 5)]

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

    with :ok <- StatusInterpreter.apply_status(:player, caster_id, :sc_impositio, params) do
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
             :sc_impositio,
             params(caster_id, level, definition)
           ) do
      {:ok, caster}
    end
  end

  defp params(caster_id, level, definition) do
    [
      val1: level,
      val2: 5 * level,
      caster_id: caster_id,
      duration: Enum.at(definition.duration, level - 1)
    ]
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
