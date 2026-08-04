defmodule Aesir.ZoneServer.Unit.Homunculus.NaturalRegen do
  @moduledoc "Natural HP/SP recovery advanced by the existing Homunculus AI clock."

  alias Aesir.ZoneServer.Unit.Homunculus.HomunculusState
  alias Aesir.ZoneServer.Unit.Homunculus.Runtime

  @hp_interval 2_000
  @sp_interval 4_000

  @spec tick(HomunculusState.t(), Runtime.t(), integer()) ::
          {HomunculusState.t(), Runtime.t()}
  def tick(%HomunculusState{} = homunculus, %Runtime{} = runtime, now_ms) do
    if eligible?(homunculus) do
      {homunculus, runtime}
      |> recover_hp(now_ms)
      |> recover_sp(now_ms)
    else
      {homunculus, reset(runtime)}
    end
  end

  @spec reset(Runtime.t()) :: Runtime.t()
  def reset(%Runtime{} = runtime) do
    %{runtime | hp_regen_deadline_ms: nil, sp_regen_deadline_ms: nil}
  end

  defp eligible?(homunculus) do
    HomunculusState.living?(homunculus) and homunculus.lifecycle == :active and
      homunculus.movement_state == :standing
  end

  defp recover_hp({homunculus, %Runtime{hp_regen_deadline_ms: nil} = runtime}, now_ms) do
    {homunculus, %{runtime | hp_regen_deadline_ms: now_ms + @hp_interval}}
  end

  defp recover_hp({homunculus, %Runtime{hp_regen_deadline_ms: deadline} = runtime}, now_ms)
       when now_ms >= deadline do
    base = div(homunculus.vit, 5) + max(1, div(homunculus.max_hp, 200))
    amount = apply_rate(base, homunculus.combat_stats.hp_regen_rate)
    healed = %{homunculus | hp: min(homunculus.hp + amount, homunculus.max_hp)}
    {healed, %{runtime | hp_regen_deadline_ms: now_ms + @hp_interval}}
  end

  defp recover_hp(pair, _now_ms), do: pair

  defp recover_sp({homunculus, %Runtime{sp_regen_deadline_ms: nil} = runtime}, now_ms) do
    {homunculus, %{runtime | sp_regen_deadline_ms: now_ms + @sp_interval}}
  end

  defp recover_sp({homunculus, %Runtime{sp_regen_deadline_ms: deadline} = runtime}, now_ms)
       when now_ms >= deadline do
    threshold_bonus = if homunculus.int >= 120, do: div(homunculus.int - 120, 2) + 4, else: 0
    base = 1 + div(homunculus.int, 6) + div(homunculus.max_sp, 100) + threshold_bonus
    amount = apply_rate(base, homunculus.combat_stats.sp_regen_rate)
    healed = %{homunculus | sp: min(homunculus.sp + amount, homunculus.max_sp)}
    {healed, %{runtime | sp_regen_deadline_ms: now_ms + @sp_interval}}
  end

  defp recover_sp(pair, _now_ms), do: pair

  defp apply_rate(amount, rate), do: max(div(amount * (100 + rate), 100), 1)
end
