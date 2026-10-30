defmodule Aesir.ZoneServer.Mmo.Fame.Store do
  @moduledoc "Persists absolute fame totals and reads the current production top-ten rankings."

  alias Aesir.Repo
  alias Aesir.ZoneServer.Mmo.Fame
  alias Aesir.ZoneServer.Mmo.JobManagement.AvailableJobs
  alias Ecto.Adapters.SQL

  @typedoc "A ranked character, in descending ranking order."
  @type entry :: %{
          character_id: pos_integer(),
          name: String.t(),
          fame: non_neg_integer()
        }

  @doc "Writes the absolute total and refreshes equal-score ordering in one update."
  @spec persist(pos_integer(), non_neg_integer()) :: :ok | {:error, term()}
  def persist(character_id, total) do
    case SQL.query(
           Repo,
           "UPDATE characters SET fame = $1, fame_order = nextval('character_fame_order_seq') WHERE id = $2",
           [total, character_id]
         ) do
      {:ok, %{num_rows: 1}} -> :ok
      {:ok, %{num_rows: 0}} -> {:error, :character_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc "Reads up to ten positive scores, including offline characters and all eligible job versions."
  @spec ranking(Fame.category()) :: {:ok, [entry()]} | {:error, term()}
  def ranking(category) do
    ids =
      Enum.map(jobs(category), fn job ->
        {:ok, id} = AvailableJobs.job_name_to_id(job)
        id
      end)

    case SQL.query(
           Repo,
           "SELECT id, name, fame FROM characters WHERE fame > 0 AND class = ANY($1) ORDER BY fame DESC, fame_order DESC, id ASC LIMIT 10",
           [ids]
         ) do
      {:ok, %{rows: rows}} ->
        {:ok,
         Enum.map(rows, fn [id, name, fame] -> %{character_id: id, name: name, fame: fame} end)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp jobs(:blacksmith),
    do: [
      :blacksmith,
      :whitesmith,
      :baby_blacksmith,
      :mechanic,
      :mechanic_t,
      :baby_mechanic,
      :meister
    ]

  defp jobs(:alchemist),
    do: [:alchemist, :creator, :baby_alchemist, :genetic, :genetic_t, :baby_genetic, :biolo]
end
