defmodule Aesir.ZoneServer.Mmo.Combat.Coma do
  @moduledoc """
  The SC_COMA start: a flat per-10000 roll that zaps a living target to 1 HP
  and 1 SP without a source and without a status entry.

  Mirrors the reference's `status_change_start` gates, checked before the
  roll: a dead target, a target under Gravity Control, a status-immune
  monster (BossResist) and an MVP monster (MvpResist) all resist.
  """

  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Mob.MobSession
  alias Aesir.ZoneServer.Unit.Mob.MobState
  alias Aesir.ZoneServer.Unit.Player.PlayerSession
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @doc """
  Attempts a coma on a unit.

  Options: `:rate` (required, per 10000) and `:sampler`, a `1..10000` sampler
  defaulting to `:rand.uniform/1`.
  """
  @spec attempt(atom(), integer(), keyword()) :: :applied | :resisted
  def attempt(unit_type, unit_id, opts) do
    rate = Keyword.fetch!(opts, :rate)
    sampler = Keyword.get(opts, :sampler, &:rand.uniform/1)

    with {:ok, {_module, unit, pid}} when is_pid(pid) <- UnitRegistry.get_unit(unit_type, unit_id),
         true <- Unit.living?(unit),
         false <- StatusStorage.has_status?(unit_type, unit_id, :sc_gravitycontrol),
         false <- resists?(unit),
         true <- sampler.(10_000) <= rate do
      zap(unit_type, unit_id, pid)
    else
      _ -> :resisted
    end
  end

  defp resists?(%MobState{} = mob),
    do: MobState.status_immune?(mob) or :mvp in MobState.modes(mob)

  defp resists?(_unit), do: false

  defp zap(:player, _id, pid), do: applied(PlayerSession.apply_coma(pid, nil, %{passive?: true}))
  defp zap(:mob, _id, pid), do: applied(MobSession.apply_coma(pid, nil, %{passive?: true}))

  defp zap(:homunculus, id, pid),
    do: applied(GenServer.cast(pid, {:homunculus, {:apply_coma, id, nil, %{passive?: true}}}))

  defp zap(_type, _id, _pid), do: :resisted

  defp applied(:ok), do: :applied
end
