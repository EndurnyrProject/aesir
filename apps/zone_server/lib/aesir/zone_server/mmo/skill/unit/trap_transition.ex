defmodule Aesir.ZoneServer.Mmo.Skill.Unit.TrapTransition do
  @moduledoc """
  Reads a group's trap lifecycle, moves it between phases and persists the
  result, materializing a hidden trap's cells when the transition makes it
  visible and republishing a visible trap whose view changed.

  Every function runs inside `Skill.Unit.Manager`.
  """

  alias Aesir.ZoneServer.Mmo.Skill.Unit.Cells
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Group
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Publisher
  alias Aesir.ZoneServer.Mmo.Skill.Unit.Storage
  alias Aesir.ZoneServer.Mmo.Skill.Unit.TrapState

  @sprung_trap_lifetime 1_500

  @doc "How long a sprung or used trap lingers, in ms."
  @spec sprung_lifetime() :: pos_integer()
  def sprung_lifetime, do: @sprung_trap_lifetime

  @doc """
  The validated trap state of a group: `{:error, :unsupported_trap}` for a
  group that is not a trap, `{:error, :invalid_trap_state}` for a malformed one.
  """
  @spec from_group(Group.t()) ::
          {:ok, TrapState.t()} | {:error, :unsupported_trap | :invalid_trap_state}
  def from_group(%Group{state: %{trap: %TrapState{} = trap}}) do
    case TrapState.new(Map.from_struct(trap)) do
      {:ok, valid} -> {:ok, valid}
      {:error, :invalid_trap_state} = error -> error
    end
  end

  def from_group(%Group{state: state}) do
    if Map.has_key?(state, :trap),
      do: {:error, :invalid_trap_state},
      else: {:error, :unsupported_trap}
  end

  @doc "Moves a trap to `phase` with a new expiry, without persisting."
  @spec transition(Group.t(), TrapState.phase(), integer()) :: Group.t()
  def transition(%Group{state: %{trap: %TrapState{} = trap}} = group, phase, expires_at) do
    %{group | expires_at: expires_at, state: %{group.state | trap: %{trap | phase: phase}}}
  end

  @doc """
  Persists a trap's new state. A hidden trap becoming materialized gets its
  cells and a tracked spawn; a visible trap whose phase or expiry changed is
  republished; a materialized trap cannot go back to hidden.
  """
  @spec persist(Group.t(), Group.t()) :: :ok | {:error, term()}
  def persist(%Group{} = original, %Group{} = updated) do
    with {:ok, %TrapState{}} <- from_group(updated) do
      case {Group.materialized?(original), Group.materialized?(updated)} do
        {false, false} ->
          Storage.update(updated)

        {false, true} ->
          materialize(original, updated)

        {true, true} ->
          persist_visible(original, updated)

        {true, false} ->
          {:error, :invalid_trap_transition}
      end
    end
  end

  @doc "Drops a trap's materialized cells and restores its earlier stored state."
  @spec rollback_materialization(Group.t()) :: :ok
  def rollback_materialization(%Group{} = original) do
    original.group_id
    |> Storage.get_cells_by_group()
    |> Enum.each(&Cells.remove/1)

    Storage.update(original)
  end

  defp materialize(%Group{} = original, %Group{} = updated) do
    case Storage.get_cells_by_group(original.group_id) do
      [] ->
        :ok = Storage.update(updated)

        case Cells.materialize_visible(updated, []) do
          {:ok, _cells} ->
            Publisher.tracked_spawn(updated)

          {:error, _reason} = error ->
            rollback_materialization(original)
            error
        end

      [_cell | _cells] ->
        {:error, :already_materialized}
    end
  end

  defp persist_visible(%Group{} = original, %Group{} = updated) do
    case Storage.get_cells_by_group(original.group_id) do
      [] ->
        {:error, :not_materialized}

      cells ->
        :ok = Storage.update(updated)

        if view_changed?(original, updated) do
          Publisher.group_replacement(updated, cells)
        end

        :ok
    end
  end

  defp view_changed?(original, updated) do
    original.expires_at != updated.expires_at or
      original.state.trap.phase != updated.state.trap.phase
  end
end
