defmodule Aesir.ZoneServer.Mmo.Skill.PartyBuff do
  @moduledoc """
  Shares a self-cast status with eligible nearby party members.

  Status parameters, including duration, are supplied by the caster's skill and
  reused unchanged for every recipient.
  """

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.Skill.Learned
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @hilt_binding_id 105

  @doc """
  Returns the caster-derived party-buff duration.

  Hilt Binding extends the duration by 10%. Fractional milliseconds are truncated.
  """
  @spec duration_for_caster(PlayerState.t(), non_neg_integer()) :: non_neg_integer()
  def duration_for_caster(caster, duration) do
    if Learned.learned_level(caster.stats.progression.learned_skills, @hilt_binding_id) > 0 do
      div(duration * 110, 100)
    else
      duration
    end
  end

  @doc """
  Applies `status` to the caster and eligible online party members within `range`.
  """
  @spec apply(PlayerState.t(), atom(), keyword(), non_neg_integer(), (PlayerState.t() ->
                                                                        boolean())) ::
          :ok | {:error, atom()}
  def apply(caster, status, params, range, eligible? \\ fn _candidate -> true end) do
    with :ok <- StatusInterpreter.apply_status(:player, caster.character_id, status, params) do
      caster
      |> party_members()
      |> Enum.each(&apply_to_member(&1, caster, status, params, range, eligible?))
    end
  end

  defp apply_to_member(member, caster, status, params, range, eligible?) do
    if nearby_and_eligible?(member.char_id, caster, range, eligible?) do
      StatusInterpreter.apply_status(:player, member.char_id, status, params)
    end
  end

  defp party_members(%{party_id: 0}), do: []

  defp party_members(%{party_id: party_id, character_id: caster_id}) do
    case PartyManager.get(party_id) do
      {:ok, party} ->
        party
        |> PartyState.online_members()
        |> Enum.reject(&(&1.char_id == caster_id))

      {:error, _reason} ->
        []
    end
  end

  defp nearby_and_eligible?(char_id, caster, range, eligible?) do
    case UnitRegistry.get_unit(:player, char_id) do
      {:ok, {_module, %PlayerState{} = candidate, _pid}} ->
        candidate.map_name == caster.map_name and
          Unit.living?(candidate) and
          Geometry.in_tile_range?(caster.x, caster.y, candidate.x, candidate.y, range) and
          eligible?.(candidate)

      {:error, :not_found} ->
        false
    end
  end
end
