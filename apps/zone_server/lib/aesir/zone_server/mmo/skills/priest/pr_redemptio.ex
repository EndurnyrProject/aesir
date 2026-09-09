defmodule Aesir.ZoneServer.Mmo.Skills.Priest.PrRedemptio do
  @moduledoc """
  Redemptio (PR_REDEMPTIO). The Priest platinum skill that revives every nearby
  party corpse at half HP and leaves its caster at one HP. Unavailable on siege
  ground in both modes.

  Renewal: 800 SP, a 3.2 s cast plus 0.8 s fixed (DEX does not shorten it), and no
  further cost. Pre-renewal: a 4 s cast, the caster's whole SP (at least the listed
  400), and base experience charged 0.2% of the next level for every revive short of
  five (nothing when five or more are revived).
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
    cast_time: [renewal: [3_200], pre_renewal: [4_000]],
    fixed_cast_time: [renewal: [800], pre_renewal: []],
    ignore_dex: true,
    sp_cost: [renewal: [800], pre_renewal: [400]],
    quest_skill: true,
    quest_owner_job: :priest

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Leveling
  alias Aesir.ZoneServer.Mmo.Skill.Active
  alias Aesir.ZoneServer.Mmo.Skill.Cost
  alias Aesir.ZoneServer.Mmo.Skill.Definition
  alias Aesir.ZoneServer.Mmo.Woe.Rules
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @behaviour Active

  # NOTE: Remove the catalog-only boundary when Priest quest/grant acquisition exists.
  # NOTE: Add Battleground, negative PvP-score, and Hell Power gates when Aesir gains
  # each corresponding competitive-mode or status concept.
  # NOTE: Add restart-full, resurrection-EXP, and Redemptio-EXP options here when
  # Aesir gains a matching server-config surface or one of those rules becomes required.
  @impl Active
  @spec validate(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          :ok | {:error, atom()}
  def validate(%{party_id: 0}, :self, 1, _definition), do: {:error, :party_required}

  def validate(%{party_id: party_id, map_name: map_name}, :self, 1, _definition)
      when party_id > 0 do
    if Rules.ground?(map_name), do: {:error, :invalid_target}, else: :ok
  end

  @impl Active
  @spec cast(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) ::
          {:ok, PlayerState.t()} | {:error, atom()}
  def cast(%{party_id: 0}, :self, 1, _definition), do: {:error, :party_required}

  def cast(%{character_id: caster_id, party_id: party_id} = caster, :self, 1, definition) do
    with false <- Rules.ground?(caster.map_name),
         {:ok, party} <- PartyManager.get(party_id),
         [_corpse | _rest] = corpses <- eligible_corpses(party, caster, definition.splash_radius) do
      Enum.each(corpses, fn {target_pid, _target_state} ->
        PlayerSession.resurrect(target_pid, caster_id, 50)
      end)

      {:ok, caster |> set_hp_to_one() |> classic_exp_penalty(length(corpses))}
    else
      true -> {:error, :invalid_target}
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

  @classic_revive_limit 5

  @doc "Classic empties the caster's SP: the cost is all of it, never below the listed 400."
  @impl Active
  @spec dynamic_cost(PlayerState.t(), Active.target(), pos_integer(), Definition.t()) :: Cost.t()
  def dynamic_cost(%{stats: %{current_state: %{sp: sp}}}, _target, _level, definition) do
    listed = hd(definition.sp_cost)
    sp = if GameMode.mode() == :pre_renewal, do: max(listed, sp), else: listed
    %Cost{sp: sp}
  end

  # Classic charges base experience for every revive short of five: 1% of the next
  # level split five ways, so 0.2% per missing revive.
  defp classic_exp_penalty(caster, revived) when revived >= @classic_revive_limit, do: caster

  defp classic_exp_penalty(%{stats: %{progression: progression}} = caster, revived) do
    if GameMode.mode() == :pre_renewal do
      missing = @classic_revive_limit - revived
      loss = min(progression.base_exp, div(Leveling.next_base_exp(progression) * missing, 500))
      put_in(caster.stats.progression.base_exp, progression.base_exp - loss)
    else
      caster
    end
  end
end
