defmodule Aesir.ZoneServer.Mmo.Woe.CastleStore do
  @moduledoc """
  Authoritative runtime WoE castle state in ETS with atomic claims.

  Each castle is one flat tuple in `:castle_states`:
  `{castle_id, owner_guild_id, siege_active?, epoch, emperium_unit_id}`.

  `capture/3` compares `{siege_active?, epoch}`, while `claim_break/3` compares
  `{siege_active?, emperium_unit_id}`. Both use `:ets.select_replace` so the
  winning call replaces the whole row in one atomic operation. This is the
  correctness boundary of the siege — no offer/claim protocol between
  sessions, just one atomic claim on the shared store.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.Woe.CastleDb

  @typedoc "Runtime state of a castle, rebuilt from its ETS row."
  @type castle_state :: %{
          owner_guild_id: non_neg_integer() | nil,
          siege_active?: boolean(),
          epoch: non_neg_integer(),
          emperium_unit_id: non_neg_integer() | nil
        }

  @default_state %{owner_guild_id: nil, siege_active?: false, epoch: 0, emperium_unit_id: nil}

  @doc """
  Seeds one neutral row per `CastleDb` castle: no owner, siege inactive.

  Uses `:ets.insert_new`, so re-running after `hydrate/1` never clobbers an
  already-hydrated owner.
  """
  @spec init() :: :ok
  def init do
    Enum.each(CastleDb.all(), fn castle ->
      :ets.insert_new(table_for(:castle_states), {castle.id, nil, false, 0, nil})
    end)

    :ok
  end

  @doc """
  Sets castle owners from a `%{castle_id => guild_id}` map (restored from the DB).
  """
  @spec hydrate(%{non_neg_integer() => non_neg_integer()}) :: :ok
  def hydrate(owners) do
    table = table_for(:castle_states)

    Enum.each(owners, fn {castle_id, guild_id} ->
      :ets.update_element(table, castle_id, {2, guild_id})
    end)

    :ok
  end

  @doc """
  Returns the runtime state of a castle, or neutral defaults if unknown.
  """
  @spec get(non_neg_integer()) :: castle_state()
  def get(castle_id) do
    case :ets.lookup(table_for(:castle_states), castle_id) do
      [{^castle_id, owner_guild_id, siege_active?, epoch, emperium_unit_id}] ->
        %{
          owner_guild_id: owner_guild_id,
          siege_active?: siege_active?,
          epoch: epoch,
          emperium_unit_id: emperium_unit_id
        }

      [] ->
        @default_state
    end
  end

  @doc """
  Returns the castle's current owner guild, or `nil` when unowned.
  """
  @spec owner(non_neg_integer()) :: non_neg_integer() | nil
  def owner(castle_id) do
    case :ets.lookup(table_for(:castle_states), castle_id) do
      [{^castle_id, owner_guild_id, _, _, _}] -> owner_guild_id
      [] -> nil
    end
  end

  @doc """
  Toggles whether the castle is under siege. Atomic single-element update.
  """
  @spec set_siege(non_neg_integer(), boolean()) :: :ok
  def set_siege(castle_id, siege_active?) do
    :ets.update_element(table_for(:castle_states), castle_id, {3, siege_active?})
    :ok
  end

  @doc """
  Records the live emperium unit for the castle (or `nil` when it is down).
  Atomic single-element update.
  """
  @spec set_emperium(non_neg_integer(), non_neg_integer() | nil) :: :ok
  def set_emperium(castle_id, emperium_unit_id) do
    :ets.update_element(table_for(:castle_states), castle_id, {5, emperium_unit_id})
    :ok
  end

  @doc """
  Atomically claims the break of the expected live emperium for `guild_id`.

  The claim succeeds only during an active siege when `emperium_unit_id`
  identifies the current live emperium. It clears that identity, advances the
  epoch, and returns the resulting castle state.
  """
  @spec claim_break(non_neg_integer(), pos_integer(), pos_integer() | nil) ::
          {:ok, castle_state()} | {:error, :not_active | :stale_emperium | :invalid_guild}
  def claim_break(_castle_id, _emperium_unit_id, guild_id)
      when is_integer(guild_id) and guild_id <= 0 do
    {:error, :invalid_guild}
  end

  def claim_break(castle_id, emperium_unit_id, guild_id)
      when is_integer(guild_id) and guild_id > 0 do
    claim_live_emperium(castle_id, emperium_unit_id, guild_id)
  end

  def claim_break(castle_id, emperium_unit_id, nil) do
    claim_live_emperium(castle_id, emperium_unit_id, nil)
  end

  defp claim_live_emperium(castle_id, emperium_unit_id, guild_id) do
    table = table_for(:castle_states)

    case :ets.lookup(table, castle_id) do
      [{^castle_id, owner_guild_id, true, epoch, ^emperium_unit_id}] ->
        new_owner_guild_id = guild_id || owner_guild_id

        state = %{
          owner_guild_id: new_owner_guild_id,
          siege_active?: true,
          epoch: epoch + 1,
          emperium_unit_id: nil
        }

        match_spec = [
          {{castle_id, owner_guild_id, true, epoch, emperium_unit_id}, [],
           [{{castle_id, new_owner_guild_id, true, epoch + 1, nil}}]}
        ]

        case :ets.select_replace(table, match_spec) do
          1 -> {:ok, state}
          0 -> classify_break_failure(castle_id)
        end

      _ ->
        classify_break_failure(castle_id)
    end
  end

  @doc """
  Atomically captures the castle for `guild_id`.

  Succeeds only while the castle is under siege and still at `expected_epoch`;
  the winning call replaces the row with the new owner and `expected_epoch + 1`
  in one atomic operation, making concurrent captures exactly-once. The loser
  reports `:stale_epoch` (a newer capture won) or `:not_active` (siege ended or
  the castle is unknown).
  """
  @spec capture(non_neg_integer(), non_neg_integer(), non_neg_integer()) ::
          {:ok, non_neg_integer()} | {:error, :stale_epoch | :not_active}
  def capture(castle_id, expected_epoch, guild_id) do
    ms = [
      {{castle_id, :_, true, expected_epoch, :"$1"}, [],
       [{{castle_id, guild_id, true, expected_epoch + 1, :"$1"}}]}
    ]

    case :ets.select_replace(table_for(:castle_states), ms) do
      1 -> {:ok, expected_epoch + 1}
      0 -> classify_failure(castle_id)
    end
  end

  @spec classify_break_failure(non_neg_integer()) ::
          {:error, :stale_emperium | :not_active}
  defp classify_break_failure(castle_id) do
    case :ets.lookup(table_for(:castle_states), castle_id) do
      [{^castle_id, _, true, _, _}] -> {:error, :stale_emperium}
      _ -> {:error, :not_active}
    end
  end

  @spec classify_failure(non_neg_integer()) :: {:error, :stale_epoch | :not_active}
  defp classify_failure(castle_id) do
    case :ets.lookup(table_for(:castle_states), castle_id) do
      [{^castle_id, _, true, _, _}] -> {:error, :stale_epoch}
      _ -> {:error, :not_active}
    end
  end
end
