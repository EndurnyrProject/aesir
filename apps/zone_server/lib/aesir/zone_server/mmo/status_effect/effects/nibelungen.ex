defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.Nibelungen do
  @moduledoc """
  Finite Ring of Nibelungen random-bonus snapshot.

  The baseline's twelve-way roll includes one unmatched dud. This implementation
  deliberately rolls uniformly across the eleven effective outcomes instead.
  """

  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_nibelungen,
    no_dispel: true,
    properties: [:buff],
    calc_flags: [
      :aspd_rate,
      :atk_rate,
      :matk_rate,
      :max_hp_rate,
      :max_sp_rate,
      :str,
      :agi,
      :vit,
      :int,
      :dex,
      :luk,
      :hit,
      :flee,
      :sp_cost_rate,
      :hp_regen,
      :sp_regen
    ],
    end_on_start: [
      :sc_richmankim,
      :sc_eternalchaos,
      :sc_drumbattle,
      :sc_nibelungen,
      :sc_rokisweil,
      :sc_intoabyss,
      :sc_siegfried
    ],
    duration: 60_000,
    remove_on_death: false,
    remove_on_map_change: false,
    icon: :ringnibelungen

  @outcome_count 11

  @impl true
  def on_apply(_target, instance, _context) do
    {rng, state} = Map.pop(instance.state, :rng, &__MODULE__.roll/1)
    outcome = validate_roll!(rng.(@outcome_count))
    {:ok, %{instance | state: Map.put(state, :outcome, outcome)}}
  end

  @impl true
  def modifiers(%{state: %{outcome: 1}}, _context), do: %{aspd_rate: 20}
  def modifiers(%{state: %{outcome: 2}}, _context), do: %{atk_rate: 20}
  def modifiers(%{state: %{outcome: 3}}, _context), do: %{matk_rate: 20}
  def modifiers(%{state: %{outcome: 4}}, _context), do: %{max_hp_rate: 30}
  def modifiers(%{state: %{outcome: 5}}, _context), do: %{max_sp_rate: 30}

  def modifiers(%{state: %{outcome: 6}}, _context) do
    %{str: 15, agi: 15, vit: 15, int: 15, dex: 15, luk: 15}
  end

  def modifiers(%{state: %{outcome: 7}}, _context), do: %{hit: 50}
  def modifiers(%{state: %{outcome: 8}}, _context), do: %{flee: 50}
  def modifiers(%{state: %{outcome: 9}}, _context), do: %{sp_cost_rate: -30}
  def modifiers(%{state: %{outcome: 10}}, _context), do: %{hp_regen: 100}
  def modifiers(%{state: %{outcome: 11}}, _context), do: %{sp_regen: 100}

  @doc "Returns a uniform random outcome index in `1..upper`."
  @spec roll(pos_integer()) :: pos_integer()
  def roll(upper), do: :rand.uniform(upper)

  defp validate_roll!(roll) when roll in 1..@outcome_count, do: roll

  defp validate_roll!(roll) do
    raise ArgumentError, "Nibelungen roll must be in 1..#{@outcome_count}, got: #{inspect(roll)}"
  end
end
