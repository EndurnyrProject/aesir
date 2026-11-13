defmodule Aesir.ZoneServer.Guild.Relations do
  @moduledoc """
  Guild-to-guild alliance and antagonist relations.

  Every write locks the two `guilds` rows `FOR UPDATE` inside one
  `Repo.transaction/1` so concurrent requests touching the same pair of
  guilds serialize and cannot overshoot the ally/antagonist limits. A
  directed row records `guild_id -> other_guild_id`; an alliance is
  symmetric (two rows), an antagonist declaration is unilateral (one row).
  Each write also logs the change, in the same transaction, on every guild
  whose own relation list it changes (`Aesir.ZoneServer.Guild.Activity`).

  `allied?/2` and `friendly?/2` are the hot-path hostility reads: they never
  touch the database, reading instead from the Horde-replicated guild entry
  via `Aesir.ZoneServer.Guild.Manager.get/1`.
  """

  import Ecto.Query

  alias Aesir.Commons.Models.Character
  alias Aesir.Commons.Models.Guild, as: GuildModel
  alias Aesir.Commons.Models.GuildRelation
  alias Aesir.Repo
  alias Aesir.ZoneServer.Guild.Activity
  alias Aesir.ZoneServer.Guild.Manager
  alias Aesir.ZoneServer.Guild.Relation
  alias Aesir.ZoneServer.Guild.State
  alias Aesir.ZoneServer.Mmo.Woe.Server, as: WoeServer

  @ally_limit 3
  @antagonist_limit 3

  @doc """
  Read-only, unlocked check for whether `a` may send `b` an alliance request.

  Checked in order: `:same_guild` when `a == b`, `:siege_active`,
  `:already_allied` when an ally row exists in either direction,
  `:ally_limit` when `a` or `b` already has #{@ally_limit} allies, and
  `:not_found` when either guild row is missing.
  """
  @spec request_check(pos_integer(), pos_integer()) ::
          :ok | {:error, :same_guild | :siege_active | :already_allied | :ally_limit | :not_found}
  def request_check(a, b) do
    cond do
      a == b -> {:error, :same_guild}
      siege_active?() -> {:error, :siege_active}
      already_allied?(a, b) -> {:error, :already_allied}
      ally_limit_reached?(a, b) -> {:error, :ally_limit}
      not (guild_exists?(a) and guild_exists?(b)) -> {:error, :not_found}
      true -> :ok
    end
  end

  @doc """
  Forms a symmetric alliance between `a` and `b`.

  Re-runs the `request_check/2` refusals inside the row-locked transaction,
  then deletes any antagonist rows between the two guilds in both directions
  and inserts the ally pair. Refreshes both guilds' live entries on success.
  """
  @spec ally(pos_integer(), pos_integer()) ::
          :ok | {:error, :same_guild | :siege_active | :already_allied | :ally_limit | :not_found}
  def ally(a, b) do
    write([a, b], fn guilds ->
      with :ok <- refuse(a == b, :same_guild),
           :ok <- refuse(siege_active?(), :siege_active),
           :ok <- refuse(already_allied?(a, b), :already_allied),
           :ok <- refuse(ally_limit_reached?(a, b), :ally_limit) do
        remove_antagonist_row(guilds, a, b)
        remove_antagonist_row(guilds, b, a)
        insert_relation(a, b, "ally", guilds[b].name)
        insert_relation(b, a, "ally", guilds[a].name)
        log_pair(guilds, a, b, :alliance_formed)
        :ok
      end
    end)
  end

  @doc """
  Breaks an existing alliance between `a` and `b`, deleting both ally rows.
  """
  @spec break(pos_integer(), pos_integer()) ::
          :ok | {:error, :siege_active | :not_related | :not_found}
  def break(a, b) do
    write([a, b], fn guilds ->
      with :ok <- refuse(siege_active?(), :siege_active),
           :ok <- refuse(relation_kind(a, b) != "ally", :not_related) do
        break_alliance(guilds, a, b)
      end
    end)
  end

  @doc """
  Declares `b` an antagonist of `a` (unilateral: only the `a -> b` row is
  written). An existing `a -> b` alliance is converted (deleted in both
  directions) unless a siege is active, in which case the declaration is
  refused with `:siege_active`.
  """
  @spec declare_antagonist(pos_integer(), pos_integer()) ::
          :ok
          | {:error,
             :same_guild | :already_antagonist | :antagonist_limit | :siege_active | :not_found}
  def declare_antagonist(a, b) do
    write([a, b], fn guilds ->
      with :ok <- refuse(a == b, :same_guild),
           :ok <- refuse(relation_kind(a, b) == "antagonist", :already_antagonist),
           :ok <- clear_ally_if_present(guilds, a, b),
           :ok <- refuse(count_kind(a, "antagonist") >= @antagonist_limit, :antagonist_limit) do
        insert_relation(a, b, "antagonist", guilds[b].name)
        log(a, :antagonist_declared, guilds[b].name)
      end
    end)
  end

  @doc """
  Removes an existing `a -> b` antagonist declaration.
  """
  @spec remove_antagonist(pos_integer(), pos_integer()) ::
          :ok | {:error, :not_related | :not_found}
  def remove_antagonist(a, b) do
    write([a, b], fn guilds ->
      with :ok <- refuse(relation_kind(a, b) != "antagonist", :not_related) do
        remove_antagonist_row(guilds, a, b)
      end
    end)
  end

  @doc """
  Hot-path hostility read: whether `a` and `b` are allied, in either
  direction. `nil`, `0`, or equal ids are never allied. Reads only the
  Horde-replicated guild entries, never the database.
  """
  @spec allied?(non_neg_integer() | nil, non_neg_integer() | nil) :: boolean()
  def allied?(nil, _b), do: false
  def allied?(_a, nil), do: false
  def allied?(0, _b), do: false
  def allied?(_a, 0), do: false
  def allied?(id, id), do: false

  def allied?(a, b) do
    ally_via_entry?(a, b) or ally_via_entry?(b, a)
  end

  @doc """
  Hot-path hostility read: whether `a` and `b` are on the same, non-hostile
  side. True when both are the same nonzero guild id, otherwise defers to
  `allied?/2`.
  """
  @spec friendly?(non_neg_integer() | nil, non_neg_integer() | nil) :: boolean()
  def friendly?(a, a) when is_integer(a) and a != 0, do: true
  def friendly?(a, b), do: allied?(a, b)

  @doc """
  Rebuilds `guild_id`'s relation map from persisted rows, keyed by the other
  guild's id. Each relation also carries the other guild's level, member
  count, master name and emblem version as its rows hold them now, which is
  what a snapshot shows while that guild has no live entry.
  """
  @spec load(pos_integer()) :: %{pos_integer() => Relation.t()}
  def load(guild_id) do
    member_count =
      from(c in Character, where: c.guild_id == parent_as(:other).id, select: count())

    GuildRelation
    |> where([r], r.guild_id == ^guild_id)
    |> join(:inner, [r], g in GuildModel, as: :other, on: g.id == r.other_guild_id)
    |> join(:left, [r, g], m in Character, on: m.id == g.master_char_id)
    |> select([r, g, m], %{
      guild_id: r.other_guild_id,
      name: r.other_name,
      kind: r.kind,
      level: g.level,
      member_count: subquery(member_count),
      master_name: coalesce(m.name, ""),
      emblem_id: g.emblem_id
    })
    |> Repo.all()
    |> Map.new(fn row ->
      {row.guild_id, struct!(Relation, %{row | kind: kind_atom(row.kind)})}
    end)
  end

  # Whether a WoE siege is currently active on this node. `:noproc` is the
  # exact exit `GenServer.call` raises against a `:via`-registered name with
  # no running process (verified against Registry's via dispatch): no WoE
  # server on this node means no siege. Any other exit -- a call timeout
  # included -- propagates so the enclosing transaction rolls back instead
  # of silently treating a busy server as "no siege" and letting the write
  # through.
  defp siege_active? do
    WoeServer.active?()
  catch
    :exit, {:noproc, _} -> false
  end

  defp ally_via_entry?(guild_id, other_guild_id) do
    case Manager.get(guild_id) do
      {:ok, %State{} = state} -> State.ally?(state, other_guild_id)
      {:error, :not_found} -> false
    end
  end

  defp refuse(true, reason), do: {:error, reason}
  defp refuse(false, _reason), do: :ok

  defp clear_ally_if_present(guilds, a, b) do
    if relation_kind(a, b) == "ally" do
      if siege_active?() do
        {:error, :siege_active}
      else
        break_alliance(guilds, a, b)
      end
    else
      :ok
    end
  end

  defp break_alliance(guilds, a, b) do
    delete_relation(a, b, "ally")
    delete_relation(b, a, "ally")
    log_pair(guilds, a, b, :alliance_broken)
  end

  # Drops `guild_id`'s antagonist declaration against `other_guild_id`, if it
  # holds one.
  defp remove_antagonist_row(guilds, guild_id, other_guild_id) do
    case delete_relation(guild_id, other_guild_id, "antagonist") do
      {0, _} -> :ok
      {_deleted, _} -> log(guild_id, :antagonist_removed, guilds[other_guild_id].name)
    end
  end

  defp log_pair(guilds, a, b, kind) do
    log(a, kind, guilds[b].name)
    log(b, kind, guilds[a].name)
  end

  defp log(guild_id, kind, other_name) do
    {:ok, _entry} = Activity.log(guild_id, kind, %{subject: other_name})
    :ok
  end

  defp already_allied?(a, b), do: relation_kind(a, b) == "ally" or relation_kind(b, a) == "ally"

  defp ally_limit_reached?(a, b),
    do: count_kind(a, "ally") >= @ally_limit or count_kind(b, "ally") >= @ally_limit

  defp guild_exists?(id), do: Repo.exists?(where(GuildModel, [g], g.id == ^id))

  defp relation_kind(guild_id, other_guild_id) do
    case relation_row(guild_id, other_guild_id) do
      nil -> nil
      row -> row.kind
    end
  end

  defp relation_row(guild_id, other_guild_id) do
    Repo.one(
      where(
        GuildRelation,
        [r],
        r.guild_id == ^guild_id and r.other_guild_id == ^other_guild_id
      )
    )
  end

  defp count_kind(guild_id, kind) do
    Repo.aggregate(
      where(GuildRelation, [r], r.guild_id == ^guild_id and r.kind == ^kind),
      :count
    )
  end

  defp delete_relation(guild_id, other_guild_id, kind) do
    Repo.delete_all(
      where(
        GuildRelation,
        [r],
        r.guild_id == ^guild_id and r.other_guild_id == ^other_guild_id and r.kind == ^kind
      )
    )
  end

  defp insert_relation(guild_id, other_guild_id, kind, other_name) do
    Repo.insert!(
      GuildRelation.changeset(%GuildRelation{}, %{
        guild_id: guild_id,
        other_guild_id: other_guild_id,
        kind: kind,
        other_name: other_name
      })
    )
  end

  defp kind_atom("ally"), do: :ally
  defp kind_atom("antagonist"), do: :antagonist

  defp write(ids, fun) do
    case Repo.transaction(fn -> run_locked(ids, fun) end) do
      {:ok, :ok} ->
        Enum.each(ids, &refresh_entry/1)
        :ok

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp run_locked(ids, fun) do
    with {:ok, guilds} <- lock_guilds(ids),
         :ok <- fun.(guilds) do
      :ok
    else
      {:error, reason} -> Repo.rollback(reason)
    end
  end

  defp lock_guilds(ids) do
    uniq_ids = Enum.uniq(ids)

    rows =
      GuildModel
      |> where([g], g.id in ^uniq_ids)
      |> order_by([g], g.id)
      |> lock("FOR UPDATE")
      |> Repo.all()

    if length(rows) == length(uniq_ids) do
      {:ok, Map.new(rows, &{&1.id, &1})}
    else
      {:error, :not_found}
    end
  end

  # A missing live entry (`{:error, :not_found}`) is discarded here: the
  # rebuild loads relations from rows on next `ensure_started/1`.
  defp refresh_entry(guild_id) do
    Manager.put_relations(guild_id, load(guild_id))
  end
end
