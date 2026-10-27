defmodule Aesir.ZoneServer.Mmo.StatusEffect.Resistance do
  @moduledoc """
  Status defense: decides whether an inflicted status lands and for how long.

  Rates are per 10000. A status with a defense recipe (`recipe/5`) lowers the
  rate by its `sc_def` share and then by the flat `sc_def2`, subtracts the
  target's equipment resistance share, rounds the rate up to a multiple of 10
  and rolls it. A surviving duration is lowered by its `tick_def` share (the
  `sc_def` share unless the recipe sets one), in renewal by the equipment
  resistance share too, and then by the flat `tick_def2`, never below 1 ms. A
  duration of 0 is a field-held status with no expiry and is never reduced.

  `no_rate_def` (`SCSTART_NORATEDEF`) skips the rate reductions and the
  rounding; `no_tick_def` (`SCSTART_NOTICKDEF`) keeps the duration as given.

  Both shares are capped at 100% before the holder's status resistance adds to
  `sc_def`: Status Resistance first, otherwise Siegfried (in renewal only for
  Blind, Stone, Freeze, Stun, Curse, Sleep and Silence). The shares are clamped
  at 0 in renewal only. Any other status only rolls its rate and keeps its
  duration.

  Renewal recipes subtract a level advantage from `sc_def`: one hundred times
  the squared level lead of the source over the target, divided by five, kept
  in 16 bits as the reference's `uint16` (a 98-level lead gives 60928).
  """

  import Bitwise

  @typedoc "The stats a recipe reads, for the target or the source."
  @type unit_view :: %{
          player?: boolean(),
          level: integer(),
          str: integer(),
          agi: integer(),
          vit: integer(),
          int: integer(),
          dex: integer(),
          luk: integer(),
          mdef: integer()
        }

  @typedoc """
  A status defense attempt.

  `scresist` and `siegfried` are the holder's Status Resistance `val1` and
  Siegfried ailment resistance (nil when not held). `res_eff` is the target's
  equipment resistance to this status, per 10000 (players only). `roll` gets the
  final rate and decides the application. `no_rate_def` and `no_tick_def` are
  optional and default to false.
  """
  @type input :: %{
          optional(:no_rate_def) => boolean(),
          optional(:no_tick_def) => boolean(),
          status: atom(),
          rate: integer(),
          tick: integer(),
          target: unit_view(),
          source: unit_view(),
          scresist: integer() | nil,
          siegfried: integer() | nil,
          res_eff: integer(),
          roll: (integer() -> boolean())
        }

  @typedoc "A status's defense values before caps and resistance statuses."
  @type defense :: %{
          sc_def: integer(),
          sc_def2: integer(),
          tick_def: integer() | nil,
          tick_def2: integer(),
          tick: integer()
        }

  @max_def 10_000
  @defended [
    :sc_poison,
    :sc_dpoison,
    :sc_stun,
    :sc_silence,
    :sc_bleeding,
    :sc_sleep,
    :sc_stonewait,
    :sc_freeze,
    :sc_curse,
    :sc_blind,
    :sc_confusion,
    :sc_decreaseagi,
    :sc_jointbeat,
    :sc_norecover_state
  ]
  # The list names Stone, not the petrifying wait that is actually defended.
  @siegfried_renewal [
    :sc_blind,
    :sc_stone,
    :sc_freeze,
    :sc_stun,
    :sc_curse,
    :sc_sleep,
    :sc_silence
  ]

  @doc """
  Resolves one attempt: `{:ok, duration}` when the status lands, otherwise
  `:resisted` (including Curse on a target without LUK).
  """
  @spec defend(input(), :renewal | :pre_renewal) :: {:ok, non_neg_integer()} | :resisted
  def defend(%{} = input, mode) do
    case recipe(input.status, mode, input.target, input.source, input.tick) do
      :default -> default_roll(input)
      :immune -> :resisted
      %{} = defense -> defend_with(input, mode, defense)
    end
  end

  @doc "Whether a status has a defense recipe (`recipe/5`) in both modes."
  @spec defended?(atom()) :: boolean()
  def defended?(status), do: status in @defended

  @doc """
  Rolls an undefended status: `{:ok, tick}` when its rate lands, otherwise
  `:resisted`.
  """
  @spec roll_chance(integer(), integer() | nil, (integer() -> boolean())) ::
          {:ok, integer() | nil} | :resisted
  def roll_chance(rate, tick, roll),
    do: if(lands?(rate, roll), do: {:ok, tick}, else: :resisted)

  @doc """
  Returns a status's defense recipe, `:default` for a status without one, or
  `:immune` when the target cannot receive it.
  """
  @spec recipe(atom(), :renewal | :pre_renewal, unit_view(), unit_view(), integer()) ::
          defense() | :default | :immune
  def recipe(status, :pre_renewal, t, s, tick) when status in [:sc_poison, :sc_dpoison] do
    base = %{sc_def: t.vit * 100, sc_def2: classic_sc_def2(t, s), tick_def2: 0}

    if t.player?,
      do: Map.merge(base, %{tick_def: t.vit * 75, tick_def2: t.luk * 100, tick: tick}),
      else: Map.merge(base, %{tick_def: div(t.vit * 200, 3), tick: div(tick, 2)})
  end

  def recipe(status, :pre_renewal, t, s, tick)
      when status in [:sc_stun, :sc_silence, :sc_bleeding],
      do: defense(t.vit * 100, classic_sc_def2(t, s), nil, t.luk * 10, tick)

  def recipe(:sc_sleep, :pre_renewal, t, s, tick),
    do: defense(t.int * 100, classic_sc_def2(t, s), nil, t.luk * 10, tick)

  def recipe(:sc_stonewait, :pre_renewal, t, s, tick),
    do: defense(t.mdef * 100, classic_sc_def2(t, s), 0, 0, tick)

  def recipe(:sc_freeze, :pre_renewal, t, s, tick),
    do: defense(t.mdef * 100, classic_sc_def2(t, s), nil, s.luk * -10, tick)

  def recipe(:sc_curse, _mode, %{luk: 0}, _s, _tick), do: :immune

  def recipe(:sc_curse, :pre_renewal, t, s, tick),
    do: defense(t.luk * 100, t.luk * 10 - s.level * 10, t.vit * 100, t.luk * 10, tick)

  def recipe(:sc_blind, :pre_renewal, t, s, tick),
    do: defense((t.vit + t.int) * 50, classic_sc_def2(t, s), nil, t.luk * 10, tick)

  def recipe(:sc_confusion, :pre_renewal, t, s, tick) do
    sc_def2 = s.level * 10 - t.level * 10 - t.luk * 10
    defense((t.str + t.int) * 50, sc_def2, nil, t.luk * 10, tick)
  end

  def recipe(status, :renewal, t, s, tick) when status in [:sc_poison, :sc_dpoison],
    do: renewal(t.vit, t, s, -2000, tick)

  def recipe(:sc_stun, :renewal, t, s, tick), do: renewal(t.vit, t, s, -500, tick)
  def recipe(:sc_silence, :renewal, t, s, tick), do: renewal(t.int, t, s, -2000, tick)
  def recipe(:sc_bleeding, :renewal, t, s, tick), do: renewal(t.agi, t, s, -12_000, tick)
  def recipe(:sc_sleep, :renewal, t, s, tick), do: renewal(t.agi, t, s, -2000, tick)

  def recipe(status, :renewal, t, s, tick) when status in [:sc_stonewait, :sc_freeze],
    do: renewal(t.mdef, t, s, -3000, tick)

  def recipe(status, :renewal, t, s, tick) when status in [:sc_curse, :sc_confusion],
    do: renewal(t.luk, t, s, -2000, tick)

  def recipe(:sc_blind, :renewal, t, s, tick), do: renewal(t.int, t, s, -2000, tick)

  def recipe(:sc_decreaseagi, _mode, t, _s, tick) do
    tick = if t.player?, do: div(tick, 2), else: tick
    defense(0, t.mdef * 100, nil, 0, tick)
  end

  def recipe(:sc_jointbeat, _mode, t, _s, tick),
    do: defense(0, 0, nil, 1000 * div(div(t.luk, 2) + div(t.agi, 5), 2), tick)

  def recipe(:sc_norecover_state, _mode, t, _s, tick), do: defense(0, 0, nil, t.luk * 100, tick)

  def recipe(_status, _mode, _t, _s, _tick), do: :default

  @doc """
  Rolls a per-10000 rate: at least 10000 always lands, 0 or less never does.
  """
  @spec roll_rate(integer()) :: boolean()
  def roll_rate(rate) when rate >= @max_def, do: true
  def roll_rate(rate) when rate <= 0, do: false
  def roll_rate(rate), do: :rand.uniform(@max_def) <= rate

  @doc """
  Rolls a percentage chance that is not a status start (magic reflection, a
  skill's own trigger roll).
  """
  @spec roll_success(number()) :: boolean()
  def roll_success(success_rate), do: roll_success(success_rate, &:rand.uniform/1)

  @doc """
  Rolls a success rate using an injectable 1..10,000 sampler.

  Fractional percentages are rounded up to the next 0.1% before sampling,
  matching Aegis/rAthena status chance precision.
  """
  @spec roll_success(number(), (pos_integer() -> pos_integer())) :: boolean()
  def roll_success(success_rate, _sampler) when success_rate <= 0, do: false
  def roll_success(success_rate, _sampler) when success_rate >= 100, do: true

  def roll_success(success_rate, sampler) do
    threshold = success_rate |> Kernel.*(10) |> ceil() |> Kernel.*(10)
    sampler.(10_000) <= threshold
  end

  defp defense(sc_def, sc_def2, tick_def, tick_def2, tick),
    do: %{sc_def: sc_def, sc_def2: sc_def2, tick_def: tick_def, tick_def2: tick_def2, tick: tick}

  defp classic_sc_def2(t, s), do: t.luk * 10 + t.level * 10 - s.level * 10

  defp renewal(stat, t, s, tick_def2, tick),
    do: defense(stat * 100 - level_advantage(s, t), 0, nil, tick_def2, tick)

  # Both the squared lead and the result are narrowed to 16 bits.
  defp level_advantage(s, t) do
    lead = max(0, s.level - t.level)
    band(div(band(lead * lead, 0xFFFF), 5) * 100, 0xFFFF)
  end

  defp default_roll(%{rate: rate, tick: tick, roll: roll}), do: roll_chance(rate, tick, roll)

  defp lands?(rate, _roll) when rate >= @max_def, do: true
  defp lands?(rate, _roll) when rate <= 0, do: false
  defp lands?(rate, roll), do: roll.(rate)

  defp defend_with(input, mode, defense) do
    sc_def = cap(defense.sc_def, mode) + status_resistance(input, mode)
    sc_def2 = cap(defense.sc_def2, mode)
    tick_def = defense.tick_def || sc_def

    rate =
      if Map.get(input, :no_rate_def, false) do
        input.rate
      else
        input.rate
        |> Kernel.-(div(input.rate * sc_def, @max_def))
        |> Kernel.-(sc_def2)
        |> reduce_by(input.res_eff)
        |> aegis_round()
      end

    cond do
      not lands?(rate, input.roll) -> :resisted
      Map.get(input, :no_tick_def, false) -> {:ok, defense.tick}
      true -> {:ok, duration(defense.tick, tick_def, defense.tick_def2, input.res_eff, mode)}
    end
  end

  defp cap(value, :renewal), do: value |> max(0) |> min(@max_def)
  defp cap(value, :pre_renewal), do: min(value, @max_def)

  defp status_resistance(%{scresist: value}, _mode) when is_integer(value), do: value * 100

  defp status_resistance(%{siegfried: value, status: status}, :renewal)
       when is_integer(value) and status in @siegfried_renewal,
       do: value * 100

  defp status_resistance(%{siegfried: value}, :pre_renewal) when is_integer(value),
    do: value * 100

  defp status_resistance(_input, _mode), do: 0

  defp reduce_by(value, 0), do: value
  defp reduce_by(value, share), do: value - div(value * share, @max_def)

  defp aegis_round(rate) when rate > 0 and rem(rate, 10) != 0, do: rate + 10 - rem(rate, 10)
  defp aegis_round(rate), do: rate

  defp duration(0, _tick_def, _tick_def2, _res_eff, _mode), do: 0

  defp duration(tick, tick_def, tick_def2, res_eff, mode) do
    tick = tick - div(tick * tick_def, @max_def)
    tick = if mode == :renewal, do: reduce_by(tick, res_eff), else: tick
    max(tick - tick_def2, 1)
  end
end
