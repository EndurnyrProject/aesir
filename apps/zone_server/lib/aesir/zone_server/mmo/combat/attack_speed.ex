defmodule Aesir.ZoneServer.Mmo.Combat.AttackSpeed do
  @moduledoc """
  Calculates attack delays from ASPD values following authentic Ragnarok Online mechanics.

  This module converts ASPD (Attack Speed) values into actual attack delay times in milliseconds,
  which are used by the combat system to enforce proper attack rate limiting.

  Renewal formula:
  - ASPD is displayed as: 200 - (amotion / 10)
  - amotion (the attack animation delay) is: (200 - ASPD) * 10 milliseconds
  - The interval between player attacks is adelay, twice the amotion:
    (200 - ASPD) * 20
  - ASPD ranges from -200 (slowest, an 8000 ms delay) to 193 (fastest); 190
    ASPD is 5 attacks/s
  """

  import Bitwise, only: [band: 2]

  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Aesir.ZoneServer.Mmo.JobManagement.JobLineage
  alias Aesir.ZoneServer.Mmo.JobManagement.JobMapid

  @jobl_third 0x1000

  @doc """
  Calculates the attack delay (adelay) in milliseconds from an ASPD value.

  ## Parameters
    - aspd: The ASPD value (-200 to 193, where higher is faster)

  ## Returns
    - Attack delay in milliseconds

  ## Examples
      iex> AttackSpeed.calculate_delay(150)
      1000

      iex> AttackSpeed.calculate_delay(193)
      140

      iex> AttackSpeed.calculate_delay(100)
      2000
  """
  @spec calculate_delay(integer()) :: integer()
  def calculate_delay(aspd), do: (200 - (aspd |> min(193) |> max(-200))) * 20

  @doc """
  Calculates the attack delay from player stats.

  ## Parameters
    - stats: Player stats struct containing derived_stats.aspd

  ## Returns
    - Attack delay in milliseconds
  """
  @spec calculate_delay_from_stats(map()) :: integer()
  def calculate_delay_from_stats(%{derived_stats: %{aspd: aspd}}) do
    calculate_delay(aspd)
  end

  @doc "A player's attack motion (status amotion): half its attack delay."
  @spec amotion_from_stats(map()) :: integer()
  def amotion_from_stats(stats), do: div(calculate_delay_from_stats(stats), 2)

  @doc """
  The fastest ASPD a job reaches: 193 for third and fourth jobs, Kagerou,
  Oboro, Rebellion and the Summoner line, 190 for every other job. A mounted
  form counts as its own class. An unknown job is held at 190.
  """
  @spec max_aspd(integer() | nil) :: 190 | 193
  def max_aspd(nil), do: 190

  def max_aspd(job_id) do
    case AvailableJobs.job_id_to_name(job_id) do
      {:ok, name} -> name |> JobLineage.normalize() |> JobMapid.from_job() |> mapid_max_aspd()
      {:error, _unknown} -> 190
    end
  end

  defp mapid_max_aspd(mapid) when mapid < 0, do: 190

  defp mapid_max_aspd(mapid) do
    cond do
      band(mapid, @jobl_third) != 0 -> 193
      band(mapid, 0xFFF) in [JobMapid.from_job(:rebellion), JobMapid.from_job(:kagerou)] -> 193
      band(mapid, 0xFF) == JobMapid.from_job(:summoner) -> 193
      true -> 190
    end
  end

  @doc """
  How long an attack or a parry keeps a player from using skills, given its
  `attack_delay`: its attack motion plus the attack motion at the job's
  fastest ASPD, so at that ASPD the skill delay ends with the attack delay.
  """
  @spec act_delay(non_neg_integer(), integer() | nil) :: non_neg_integer()
  def act_delay(attack_delay, job_id), do: div(attack_delay, 2) + (200 - max_aspd(job_id)) * 10

  @doc """
  Checks if enough time has passed since the last attack.

  ## Parameters
    - last_attack_timestamp: Timestamp of the last attack in milliseconds
    - attack_delay: Required delay between attacks in milliseconds

  ## Returns
    - true if enough time has passed, false otherwise
  """
  @spec can_attack?(integer(), integer()) :: boolean()
  def can_attack?(last_attack_timestamp, attack_delay) do
    if last_attack_timestamp == 0 do
      true
    else
      current_time = System.monotonic_time(:millisecond)
      current_time >= last_attack_timestamp + attack_delay
    end
  end

  @doc """
  Gets the current monotonic timestamp in milliseconds.

  ## Returns
    - Current timestamp in milliseconds
  """
  @spec current_timestamp() :: integer()
  def current_timestamp do
    System.monotonic_time(:millisecond)
  end
end
