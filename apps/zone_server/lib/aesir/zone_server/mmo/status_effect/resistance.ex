defmodule Aesir.ZoneServer.Mmo.StatusEffect.Resistance do
  @moduledoc """
  Implements status effect resistance calculations based on rAthena mechanics.

  This module handles:
  - Success rate calculations for physical and magical status effects
  - Duration reduction based on target stats (VIT/LUK)
  - Integration with the status effect definition system

  This module works in conjunction with the status effect definitions
  in the database and does not hardcode specific status effect behaviors.
  """

  @type status_type :: :physical | :magical

  @doc """
  Calculates the success rate for applying a status effect.

  ## Parameters
  - `status_type`: Whether the status is :physical or :magical
  - `target_stats`: Map containing target's stats (must include :vit for physical, :mdef for magical)
  - `base_success_rate`: Initial success rate (0-100)

  ## Returns
  The adjusted success rate (0-100) after resistance calculations.

  ## Formula from rAthena
  - Physical: `success_rate = base_rate - (target_VIT * 100 / 100)`
  - Magical: `success_rate = base_rate - (target_MDEF * 100 / 100)`

  ## Examples
      iex> calculate_success_rate(:physical, %{vit: 50}, 100)
      50.0

      iex> calculate_success_rate(:magical, %{mdef: 30}, 100)
      70.0
  """
  @spec calculate_success_rate(status_type(), map(), number()) :: float()
  def calculate_success_rate(:physical, %{vit: vit}, base_success_rate) when is_number(vit) do
    # Physical status resistance formula from rAthena
    # success_rate = base_rate - (target_VIT * 100 / 100)
    resistance = vit * 1.0
    max(0.0, base_success_rate - resistance)
  end

  def calculate_success_rate(:magical, target_stats, base_success_rate) do
    # For magical resistance, we need MDEF which might be in different forms
    mdef = get_mdef_value(target_stats)
    resistance = mdef * 1.0
    max(0.0, base_success_rate - resistance)
  end

  def calculate_success_rate(_, _, base_success_rate), do: base_success_rate

  @doc """
  Calculates the reduced duration for a status effect based on target stats.

  ## Parameters
  - `base_duration`: Initial duration in milliseconds
  - `target_stats`: Map containing target's stats (must include :vit and :luk)

  ## Returns
  The adjusted duration in milliseconds after resistance calculations.

  ## Formula from rAthena
  `final_duration = base_duration * (100 - (target_VIT + target_LUK/3)) / 100`

  ## Examples
      iex> calculate_duration(10000, %{vit: 50, luk: 30})
      4000

      iex> calculate_duration(5000, %{vit: 100, luk: 0})
      0
  """
  @spec calculate_duration(integer(), map()) :: integer()
  def calculate_duration(base_duration, %{vit: vit, luk: luk})
      when is_integer(base_duration) and is_number(vit) and is_number(luk) do
    # Duration reduction formula from rAthena
    # final_duration = base_duration * (100 - (target_VIT + target_LUK/3)) / 100
    reduction_percent = vit + luk / 3
    multiplier = max(0, 100 - reduction_percent) / 100

    round(base_duration * multiplier)
  end

  def calculate_duration(base_duration, _), do: base_duration

  @doc """
  Determines the resistance type of a status effect from its definition.

  Status effects can define their resistance type in the definition,
  or it can be inferred from their properties.

  ## Parameters
  - `definition`: The status effect definition map

  ## Returns
  Either `:physical` or `:magical`, defaults to `:physical` if not specified
  """
  @spec get_resistance_type(map()) :: status_type()
  def get_resistance_type(%{resistance_type: type}) when type in [:physical, :magical] do
    type
  end

  def get_resistance_type(%{properties: properties}) when is_list(properties) do
    cond do
      :magical in properties -> :magical
      :physical in properties -> :physical
      true -> :physical
    end
  end

  def get_resistance_type(_), do: :physical

  @doc """
  Applies full resistance calculation pipeline.

  ## Parameters
  - `definition`: The status effect definition
  - `target_stats`: Complete target stats including VIT, LUK, MDEF
  - `base_success_rate`: Initial success rate (0-100), defaults to 100
  - `base_duration`: Initial duration in milliseconds

  ## Returns
  A tuple with `{adjusted_success_rate, adjusted_duration}`
  """
  @spec apply_resistance(map(), map(), number(), integer()) :: {float(), integer()}
  def apply_resistance(definition, target_stats, base_success_rate \\ 100, base_duration) do
    status_type = get_resistance_type(definition)

    success_rate = calculate_success_rate(status_type, target_stats, base_success_rate)
    duration = calculate_duration(base_duration, target_stats)

    {success_rate, duration}
  end

  @doc """
  Checks if resistance should be applied to a status effect.

  Some status effects bypass resistance calculations entirely
  (e.g., beneficial effects, special mechanics).

  ## Parameters
  - `definition`: The status effect definition

  ## Returns
  `true` if resistance should be applied, `false` to bypass
  """
  @spec should_apply_resistance?(map()) :: boolean()
  def should_apply_resistance?(%{bypass_resistance: true}), do: false

  def should_apply_resistance?(%{properties: properties}) when is_list(properties) do
    # Buffs and certain special effects bypass resistance
    not (:buff in properties or :no_resistance in properties)
  end

  def should_apply_resistance?(_), do: true

  @doc """
  Calculates hit chance based on success rate.

  ## Parameters
  - `success_rate`: The calculated success rate (0-100)

  ## Returns
  `true` if the status should be applied, `false` if resisted
  """
  @spec roll_success(float()) :: boolean()
  def roll_success(success_rate) when success_rate <= 0, do: false
  def roll_success(success_rate) when success_rate >= 100, do: true

  def roll_success(success_rate) do
    :rand.uniform(100) <= success_rate
  end

  # Private helper functions

  defp get_mdef_value(stats) do
    cond do
      Map.has_key?(stats, :mdef) -> stats.mdef || 0
      Map.has_key?(stats, :mdef1) -> stats.mdef1 || 0
      Map.has_key?(stats, :mdef_rate) -> stats.mdef_rate || 0
      true -> 0
    end
  end
end
