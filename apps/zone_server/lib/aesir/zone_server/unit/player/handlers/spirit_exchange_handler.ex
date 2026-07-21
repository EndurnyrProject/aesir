defmodule Aesir.ZoneServer.Unit.Player.Handlers.SpiritExchangeHandler do
  @moduledoc """
  Best-effort cross-player spirit-sphere delivery and absorption.

  The owning player session revalidates each request against the current unit
  registry before changing its local state. Missing or stale sessions simply
  make the action fizzle.
  """

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.Skill.Targeting
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Player.Handlers.SpiritSphereHandler
  alias Aesir.ZoneServer.Unit.Player.PlayerState
  alias Aesir.ZoneServer.Unit.Player.SpiritSpheres
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @sphere_duration 600_000
  @sphere_cap 5
  @coin_jobs [:gunslinger, :rebellion, :baby_gunslinger, :baby_rebellion]

  @type session_state :: %{
          required(:game_state) => PlayerState.t(),
          required(:connection_pid) => pid()
        }

  @type request :: %{
          required(:source_id) => non_neg_integer(),
          required(:source_pid) => pid(),
          required(:target_id) => non_neg_integer()
        }

  @doc "Sends one sphere-delivery request to the target's current session."
  @spec transfer(%{required(:game_state) => PlayerState.t()}, non_neg_integer()) :: :ok
  def transfer(%{game_state: source}, target_id) do
    dispatch(target_id, {:receive_spirit_sphere, request(source, target_id)})
  end

  @doc "Accepts a sphere from a still-current party member when the target has room."
  @spec receive_sphere(session_state(), request()) :: {:noreply, session_state()}
  def receive_sphere(%{game_state: target} = state, request) do
    with {:ok, source} <- current_source(request),
         true <- request.target_id == target.character_id,
         true <- source.map_name == target.map_name,
         true <- same_party?(source, target),
         true <- Unit.living?(target),
         false <- coin_job?(target),
         {:ok, state} <- SpiritSphereHandler.receive_sphere(state, @sphere_duration, @sphere_cap) do
      {:noreply, state}
    else
      _ -> {:noreply, state}
    end
  end

  @doc "Sends one absorb request to the target's current session."
  @spec request_absorb(
          %{required(:game_state) => PlayerState.t()},
          non_neg_integer(),
          reference()
        ) :: :ok
  def request_absorb(%{game_state: source}, target_id, token) do
    dispatch(
      target_id,
      {:absorb_spirit_spheres, Map.put(request(source, target_id), :token, token)}
    )
  end

  @doc "Clears an eligible player target's spheres and replies once with their count."
  @spec absorb_spheres(session_state(), request() | %{required(:token) => reference()}) ::
          {:noreply, session_state()}
  def absorb_spheres(%{game_state: target} = state, %{token: token} = request) do
    with {:ok, source} <- current_source(request),
         true <- request.target_id == target.character_id,
         true <- source.map_name == target.map_name,
         :ok <- Targeting.validate_enemy(source, target) do
      count = SpiritSpheres.count(target.spirit_spheres)
      state = SpiritSphereHandler.clear(state)

      GenServer.cast(
        request.source_pid,
        {:spirit_absorb_result, token, target.character_id, count}
      )

      {:noreply, state}
    else
      _ -> {:noreply, state}
    end
  end

  defp dispatch(target_id, message) do
    case UnitRegistry.get_unit(:player, target_id) do
      {:ok, {_module, _target, pid}} when is_pid(pid) -> GenServer.cast(pid, message)
      _ -> :ok
    end

    :ok
  end

  defp request(source, target_id) do
    %{source_id: source.character_id, source_pid: self(), target_id: target_id}
  end

  defp current_source(%{source_id: source_id, source_pid: source_pid}) do
    case UnitRegistry.get_unit(:player, source_id) do
      {:ok, {_module, source, ^source_pid}} when is_pid(source_pid) ->
        if Process.alive?(source_pid), do: {:ok, source}, else: {:error, :stale_source}

      _ ->
        {:error, :stale_source}
    end
  end

  defp same_party?(%{party_id: party_id}, %{party_id: party_id}) when party_id != 0, do: true
  defp same_party?(_source, _target), do: false

  defp coin_job?(%{stats: %{progression: %{job_id: job_id}}}) do
    match?({:ok, job} when job in @coin_jobs, AvailableJobs.job_id_to_name(job_id))
  end
end
