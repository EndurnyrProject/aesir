defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Stone do
  @moduledoc """
  Stone Curse (SC_STONE), the petrified body state.

  Starts only when a `sc_stonewait` runs out, unavoidably, with that wait's remaining
  petrification duration (`val3`). The holder cannot move, attack or use skills, becomes
  earth element level 1, has its DEF halved and its MDEF raised by a quarter. Any active
  damage breaks it. Starting it ends Lex Aeterna, and applying it while the target is
  petrifying or petrified ends both instead.

  Petrification runs on a 5 second timer: every 5 seconds, while time remains and the
  holder has more than a quarter of its Max HP, it loses 1% of Max HP (at least 1) without
  dying. The last step of the timer ends it, so it lasts at least 5 seconds, and a final
  remainder shorter than 100 ms is dropped.

  It stops movement through the `:prevents_movement` property, not through a speed
  penalty: the speed calculation never consults this status.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_stone,
    no_dispel: false,
    properties: [:debuff, :prevents_movement, :prevents_skills, :prevents_attack],
    calc_flags: [:def_ele, :def_rate, :mdef_rate],
    prevented_by: [
      renewal: [
        :sc_refresh,
        :sc_inspiration,
        :sc_power_of_gaia,
        :sc_gvg_stone,
        :sc_whiteimprison,
        :sc_freeze,
        :sc_stun,
        :sc_sleep,
        :sc_burning,
        :sc_protection
      ],
      pre_renewal: [
        :sc_refresh,
        :sc_inspiration,
        :sc_power_of_gaia,
        :sc_gvg_stone,
        :sc_freeze,
        :sc_stun,
        :sc_sleep,
        :sc_burning,
        :sc_protection
      ]
    ],
    end_return: [:sc_stonewait, :sc_stone],
    end_on_start: [:sc_aeterna],
    immunity: [:boss, :undead],
    bypass_resistance: true,
    tick_interval: 1_000,
    opt1: :stone

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  @interval_ms 5_000

  @impl true
  def modifiers(_instance, _context),
    do: %{element_override: {:earth, 1}, def_rate: -50, mdef_rate: 25}

  @impl true
  def resolve_duration(instance, duration) do
    {lifetime(duration), %{instance | val3: duration}}
  end

  @impl true
  def on_tick(target, instance, context) do
    remaining = max(instance.expires_at - System.monotonic_time(:millisecond), 0)
    {:ok, run_steps(target, instance, context, remaining)}
  end

  @impl true
  def on_timeout(target, instance, context) do
    run_steps(target, instance, context, 0)
    []
  end

  @impl true
  def on_damage(_target, _instance, _damage_info, _context), do: :remove

  @doc """
  Returns the timer steps of a petrification lasting `petrify_ms`.

  Each step is `{at_ms, drain?}`: its time from the start and whether time still
  remained when it fired. The last step ends the status.
  """
  @spec steps(integer()) :: [{pos_integer(), boolean()}]
  def steps(petrify_ms), do: steps(@interval_ms, petrify_ms - @interval_ms, [])

  defp steps(at, remaining, acc) do
    acc = [{at, remaining >= 0} | acc]

    if remaining >= 100,
      do: steps(at + min(remaining, @interval_ms), remaining - @interval_ms, acc),
      else: Enum.reverse(acc)
  end

  @doc "Returns how long a petrification lasting `petrify_ms` stays on its holder."
  @spec lifetime(integer()) :: pos_integer()
  def lifetime(petrify_ms), do: petrify_ms |> steps() |> List.last() |> elem(0)

  @doc """
  Returns the HP a petrified holder loses in one step: 1% of its Max HP, at least 1.
  """
  @spec drain(non_neg_integer()) :: pos_integer()
  def drain(max_hp), do: max(div(max_hp, 100), 1)

  # Steps fire once each, as the remaining duration crosses their countdown. The
  # countdown window starts at the stored duration, so a restored petrification
  # does not repeat steps that fired before it was saved.
  defp run_steps(target, instance, context, remaining) do
    lifetime = lifetime(instance.val3)

    previous =
      Map.get(instance.state || %{}, :remaining, instance.expires_at - instance.started_at)

    instance.val3
    |> steps()
    |> Enum.filter(fn {at, _drain?} ->
      lifetime - at >= remaining and lifetime - at < previous
    end)
    |> Enum.each(fn {_at, drain?} -> if drain?, do: drain_hp(target, context) end)

    put_state(instance, :remaining, remaining)
  end

  defp drain_hp(target, %{target: %{hp: hp, max_hp: max_hp}}) when hp > div(max_hp, 4),
    do: apply_passive_hp_loss(target, drain(max_hp))

  defp drain_hp(_target, _context), do: :ok
end
