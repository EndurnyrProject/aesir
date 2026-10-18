defmodule Aesir.ZoneServer.Mmo.StatusEffect.CloseConfineLink do
  @moduledoc """
  Close Confine's caster hold and recipient links.

  A new recipient starts the caster's hold for one extra second; additional
  recipients extend its deadline without refreshing the held FLEE contribution.
  Ending a recipient decrements the caster entry's level field. An ordinary
  level-one hold therefore ends with the first released recipient, releasing
  only its nearby living links. Death alone does not end either status.
  """

  alias Aesir.Commons.GameMode
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.SpatialIndex
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc "Captures the recipient value supplied when a new caster hold is required."
  @spec initialize_recipient(StatusEntry.t()) :: StatusEntry.t()
  def initialize_recipient(instance) do
    case caster(instance) do
      {:ok, {type, id}} ->
        if is_nil(StatusStorage.get_status(type, id, :sc_closeconfine)),
          do: %{instance | val3: flee_bonus()},
          else: instance

      :missing ->
        instance
    end
  end

  @doc "Starts or extends the caster's hold before the recipient is stored."
  @spec start_recipient(StatusEntry.t(), pos_integer()) ::
          {:ok, StatusEntry.t()} | {:error, :caster_not_found}
  def start_recipient(instance, duration) do
    case caster(instance) do
      {:ok, {type, id}} ->
        start_caster(type, id, instance.val1, duration)
        {:ok, instance}

      :missing ->
        {:error, :caster_not_found}
    end
  end

  @doc "Applies a recipient end to its caster without touching another session."
  @spec end_recipient(StatusEntry.t()) :: :ok
  def end_recipient(instance) do
    with {:ok, {type, id}} <- caster(instance),
         %StatusEntry{val1: level} = held <-
           Interpreter.update_link_status(type, id, :sc_closeconfine, fn entry ->
             %{entry | val1: entry.val1 - 1}
           end),
         true <- level <= 0 do
      Interpreter.remove_status_if_current(type, id, :sc_closeconfine, held)
    end

    :ok
  end

  @doc "Releases the matching recipients within the caster's cleanup square."
  @spec end_caster({atom(), integer()}, StatusEntry.t()) :: :ok
  def end_caster({type, id}, %{val2: count}) when count > 0 do
    with {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(type, id) do
      radius = if type == :player, do: 2, else: 11

      state.map_name
      |> SpatialIndex.get_all_units_in_range(state.x, state.y, radius)
      |> Enum.each(&release_recipient(&1, {type, id}))
    end

    :ok
  end

  def end_caster(_target, _instance), do: :ok

  defp start_caster(type, id, level, duration) do
    case StatusStorage.get_status(type, id, :sc_closeconfine) do
      nil ->
        Interpreter.apply_status(type, id, :sc_closeconfine,
          val1: level,
          val2: 1,
          val3: flee_bonus(),
          caster_id: id,
          source_type: type,
          duration: duration + 1_000
        )

      _held ->
        deadline = System.monotonic_time(:millisecond) + duration + 1_000

        Interpreter.update_link_status(type, id, :sc_closeconfine, fn entry ->
          %{entry | val2: entry.val2 + 1, expires_at: deadline}
        end)
    end
  end

  defp release_recipient({type, id}, {caster_type, caster_id})
       when type in [:player, :mob, :homunculus] do
    with {:ok, {_module, state, _pid}} <- UnitRegistry.get_unit(type, id),
         true <- Unit.living?(state) do
      replacement =
        Interpreter.update_link_status(type, id, :sc_closeconfine2, fn
          %{val2: ^caster_id, source_type: ^caster_type} = entry -> %{entry | val2: 0}
          _other -> :keep
        end)

      if replacement,
        do: Interpreter.remove_status_if_current(type, id, :sc_closeconfine2, replacement)
    end
  end

  defp release_recipient(_target, _caster), do: :ok

  defp caster(%{val2: id, source_type: type})
       when id > 0 and type in [:player, :mob, :homunculus] do
    case UnitRegistry.get_unit(type, id) do
      {:ok, _unit} -> {:ok, {type, id}}
      _missing -> :missing
    end
  end

  defp caster(_instance), do: :missing

  defp flee_bonus, do: if(GameMode.mode() == :renewal, do: 50, else: 10)
end
