defmodule Aesir.ZoneServer.Guild.Activity do
  @moduledoc """
  One entry of a guild's activity log, and the log's persistence.

  The rows live in `guild_activity_log` (`Aesir.Commons.Models.GuildActivityLog`)
  and go away with the guild. A `Aesir.ZoneServer.Guild.State` carries the
  newest 30 entries, newest first, so building a `GuildInfo` never reads the
  database: `log/3` writes a row and returns the entry to prepend, `recent/1`
  loads the list when an entry is rebuilt.

  `kind` says which of `subject`, `actor`, `detail`, `skill_id` and `level` an
  entry fills (see `GuildActivityKind` in the Protobuf schema).
  """

  import Ecto.Query

  alias Aesir.Commons.Models.GuildActivityLog
  alias Aesir.Repo

  @recent_limit 30

  @enforce_keys [:kind, :at]
  defstruct kind: nil, subject: "", actor: "", detail: "", skill_id: 0, level: 0, at: nil

  @type kind ::
          :created
          | :joined
          | :left
          | :expelled
          | :position_changed
          | :skill_learned
          | :level_up
          | :alliance_formed
          | :alliance_broken
          | :antagonist_declared
          | :antagonist_removed
          | :castle_taken
          | :castle_lost

  @typedoc "`at` is the unix time, in seconds, the entry was recorded."
  @type t() :: %__MODULE__{
          kind: kind(),
          subject: String.t(),
          actor: String.t(),
          detail: String.t(),
          skill_id: non_neg_integer(),
          level: non_neg_integer(),
          at: non_neg_integer()
        }

  @doc """
  Writes one activity row for `guild_id` and returns its entry. `attrs` holds
  the fields `kind` fills.
  """
  @spec log(pos_integer(), kind(), map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def log(guild_id, kind, attrs \\ %{}) do
    attrs = Map.merge(attrs, %{guild_id: guild_id, kind: Atom.to_string(kind)})

    with {:ok, row} <- Repo.insert(GuildActivityLog.changeset(%GuildActivityLog{}, attrs)) do
      {:ok, from_model(row)}
    end
  end

  @doc "The newest #{@recent_limit} entries of `guild_id`, newest first."
  @spec recent(pos_integer()) :: [t()]
  def recent(guild_id) do
    GuildActivityLog
    |> where([a], a.guild_id == ^guild_id)
    |> order_by([a], desc: a.id)
    |> limit(@recent_limit)
    |> Repo.all()
    |> Enum.map(&from_model/1)
  end

  @doc "Puts `entry` in front of `entries`, keeping the newest #{@recent_limit}."
  @spec prepend([t()], t()) :: [t()]
  def prepend(entries, %__MODULE__{} = entry), do: Enum.take([entry | entries], @recent_limit)

  defp from_model(%GuildActivityLog{} = row) do
    %__MODULE__{
      kind: String.to_existing_atom(row.kind),
      subject: row.subject,
      actor: row.actor,
      detail: row.detail,
      skill_id: row.skill_id,
      level: row.level,
      at: DateTime.to_unix(row.inserted_at)
    }
  end
end
