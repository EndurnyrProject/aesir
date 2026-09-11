defmodule Aesir.ZoneServer.Mmo.Woe.CastleStore do
  @moduledoc """
  Authoritative runtime WoE castle state in ETS with atomic claims.

  Each castle is one flat tuple in `:castle_states`:
  `{castle_id, owner_guild_id, siege_active?, epoch, emperium_unit_id,
  economy, defense, invested_economy, invested_defense}`.

  `claim_break/3` compares `{siege_active?, emperium_unit_id}` and uses
  `:ets.select_replace` so the winning call replaces the whole row in one
  atomic operation, carrying the economy fields through unchanged. This is
  the correctness boundary of the siege — no offer/claim protocol between
  sessions, just one atomic claim on the shared store.
  """

  import Aesir.ZoneServer.EtsTable, only: [table_for: 1]

  alias Aesir.ZoneServer.Mmo.Woe.CastleDb
  alias Aesir.ZoneServer.Mmo.Woe.Persistence

  @typedoc "Runtime state of a castle, rebuilt from its ETS row."
  @type castle_state :: %{
          owner_guild_id: non_neg_integer() | nil,
          siege_active?: boolean(),
          epoch: non_neg_integer(),
          emperium_unit_id: non_neg_integer() | nil
        }

  @typedoc "Castle economy/defense levels and today's investment counters."
  @type economy_state :: %{
          economy: 0..100,
          defense: 0..100,
          invested_economy: 0..2,
          invested_defense: 0..2
        }

  @default_state %{owner_guild_id: nil, siege_active?: false, epoch: 0, emperium_unit_id: nil}
  @default_economy %{economy: 0, defense: 0, invested_economy: 0, invested_defense: 0}

  @doc """
  Seeds one neutral row per `CastleDb` castle: no owner, siege inactive, zero
  economy state.

  Uses `:ets.insert_new`, so re-running after `hydrate/1` never clobbers an
  already-hydrated row.
  """
  @spec init() :: :ok
  def init do
    Enum.each(CastleDb.all(), fn castle ->
      :ets.insert_new(table_for(:castle_states), {castle.id, nil, false, 0, nil, 0, 0, 0, 0})
    end)

    :ok
  end

  @doc """
  Sets castle owners and economy state from a full-row map (restored from the DB).
  """
  @spec hydrate(%{non_neg_integer() => Persistence.row()}) :: :ok
  def hydrate(rows) do
    table = table_for(:castle_states)

    Enum.each(rows, fn {castle_id, row} ->
      :ets.update_element(table, castle_id, [
        {2, row.guild_id},
        {6, row.economy},
        {7, row.defense},
        {8, row.invested_economy},
        {9, row.invested_defense}
      ])
    end)

    :ok
  end

  @doc """
  Returns the runtime state of a castle, or neutral defaults if unknown.
  """
  @spec get(non_neg_integer()) :: castle_state()
  def get(castle_id) do
    case :ets.lookup(table_for(:castle_states), castle_id) do
      [{^castle_id, owner_guild_id, siege_active?, epoch, emperium_unit_id, _, _, _, _}] ->
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
      [{^castle_id, owner_guild_id, _, _, _, _, _, _, _}] -> owner_guild_id
      [] -> nil
    end
  end

  @doc """
  Returns the castle's economy state, or zeros when unknown.
  """
  @spec economy(non_neg_integer()) :: economy_state()
  def economy(castle_id) do
    case :ets.lookup(table_for(:castle_states), castle_id) do
      [{^castle_id, _, _, _, _, economy, defense, invested_economy, invested_defense}] ->
        %{
          economy: economy,
          defense: defense,
          invested_economy: invested_economy,
          invested_defense: invested_defense
        }

      [] ->
        @default_economy
    end
  end

  @doc """
  Replaces the castle's economy state, leaving owner/siege/epoch/emperium untouched.
  """
  @spec put_economy(non_neg_integer(), economy_state()) :: :ok
  def put_economy(castle_id, %{
        economy: economy,
        defense: defense,
        invested_economy: invested_economy,
        invested_defense: invested_defense
      }) do
    :ets.update_element(table_for(:castle_states), castle_id, [
      {6, economy},
      {7, defense},
      {8, invested_economy},
      {9, invested_defense}
    ])

    :ok
  end

  @doc """
  Toggles whether the castle is under siege.

  Deactivation also advances the existing epoch so delayed work from the ended
  siege cannot become valid again after a restart.
  """
  @spec set_siege(non_neg_integer(), boolean()) :: :ok
  def set_siege(castle_id, false) do
    table = table_for(:castle_states)
    :ets.update_element(table, castle_id, {3, false})
    :ets.update_counter(table, castle_id, {4, 1})
    :ok
  end

  def set_siege(castle_id, true) do
    :ets.update_element(table_for(:castle_states), castle_id, {3, true})
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
      [
        {^castle_id, owner_guild_id, true, epoch, ^emperium_unit_id, economy, defense,
         invested_economy, invested_defense}
      ] ->
        new_owner_guild_id = guild_id || owner_guild_id

        state = %{
          owner_guild_id: new_owner_guild_id,
          siege_active?: true,
          epoch: epoch + 1,
          emperium_unit_id: nil
        }

        match_spec = [
          {{castle_id, owner_guild_id, true, epoch, emperium_unit_id, economy, defense,
            invested_economy, invested_defense}, [],
           [
             {{castle_id, new_owner_guild_id, true, epoch + 1, nil, economy, defense,
               invested_economy, invested_defense}}
           ]}
        ]

        case :ets.select_replace(table, match_spec) do
          1 -> {:ok, state}
          0 -> classify_break_failure(castle_id)
        end

      _ ->
        classify_break_failure(castle_id)
    end
  end

  @spec classify_break_failure(non_neg_integer()) ::
          {:error, :stale_emperium | :not_active}
  defp classify_break_failure(castle_id) do
    case :ets.lookup(table_for(:castle_states), castle_id) do
      [{^castle_id, _, true, _, _, _, _, _, _}] -> {:error, :stale_emperium}
      _ -> {:error, :not_active}
    end
  end
end
