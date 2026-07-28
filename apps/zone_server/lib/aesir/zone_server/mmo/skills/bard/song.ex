defmodule Aesir.ZoneServer.Mmo.Skills.Bard.Song do
  @moduledoc """
  Applies finite Bard songs to a live party snapshot and remembers completed songs.
  """

  require Logger

  alias Aesir.ZoneServer.Geometry
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Party.Manager, as: PartyManager
  alias Aesir.ZoneServer.Party.State, as: PartyState
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @radius 15
  @duration 180_000
  @rememberable_skill_ids [317, 319, 320, 321, 322]

  @type eligibility :: (PlayerState.t() -> boolean())

  @doc "Applies a song independently to each eligible completion-time recipient."
  @spec snapshot(PlayerState.t(), integer(), pos_integer(), atom(), keyword(), keyword()) ::
          {:ok, PlayerState.t()}
  def snapshot(caster, skill_id, level, status_id, status_params, opts \\ []) do
    eligible? = Keyword.get(opts, :eligible?, fn _recipient -> true end)

    caster
    |> recipients()
    |> Enum.filter(eligible?)
    |> Enum.each(&apply_status(&1.character_id, caster.character_id, status_id, status_params))

    {:ok, remember(caster, skill_id, level)}
  end

  @doc "Stores the skill id and level of a completed Encore-eligible song."
  @spec remember(PlayerState.t(), integer(), pos_integer()) :: PlayerState.t()
  def remember(%PlayerState{} = caster, skill_id, level)
      when skill_id in @rememberable_skill_ids and is_integer(level) and level > 0 do
    %{caster | last_song: %{skill_id: skill_id, level: level}}
  end

  defp recipients(%PlayerState{} = caster) do
    caster
    |> party_recipients()
    |> then(fn party -> [caster | party] end)
    |> Enum.uniq_by(& &1.character_id)
    |> Enum.filter(&Unit.living?/1)
  end

  defp party_recipients(%PlayerState{party_id: party_id}) when party_id in [nil, 0], do: []

  defp party_recipients(%PlayerState{} = caster) do
    case PartyManager.get(caster.party_id) do
      {:ok, party} ->
        party
        |> PartyState.online_members()
        |> Enum.flat_map(&resolve_nearby_member(&1.char_id, caster))

      {:error, :not_found} ->
        []
    end
  end

  defp resolve_nearby_member(character_id, caster) do
    case UnitRegistry.get_unit(:player, character_id) do
      {:ok, {_module, %PlayerState{} = member, _pid}} ->
        if member.map_name == caster.map_name and
             Geometry.in_tile_range?(caster.x, caster.y, member.x, member.y, @radius) do
          [member]
        else
          []
        end

      {:error, :not_found} ->
        []
    end
  end

  defp apply_status(target_id, caster_id, status_id, status_params) do
    params =
      Keyword.merge(status_params,
        caster_id: caster_id,
        duration: @duration,
        owner_refresh: :notify
      )

    case StatusInterpreter.apply_status(:player, target_id, status_id, params) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "Bard song #{status_id} application to player #{target_id} failed: #{inspect(reason)}"
        )
    end
  end
end
