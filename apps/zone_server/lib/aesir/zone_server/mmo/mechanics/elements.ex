defmodule Aesir.ZoneServer.Mmo.Mechanics.Elements do
  @moduledoc """
  Contract for mode-specific element damage.

  Each mode owns an exact four-level attribute table (rows are attack elements, columns are
  defense elements, values are integer percentages) and its own integer arithmetic for applying
  a ratio to damage. `adjust_damage/2` is pure: callers capture field and status bonuses as named,
  ordered `modifiers` and perform any status consumption themselves.
  """

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Element

  @typedoc """
  A named element bonus in percentage points, applied in list order.

  Renewal adds the value to the table ratio; classic adds the truncated percentage to the running
  damage before the table step.
  """
  @type modifier :: {atom(), integer()}

  @typedoc """
  Inputs of one attribute adjustment.

  `allow_negative_ratio?` lets a negative final ratio through (the attack can heal); otherwise a
  negative ratio is treated as zero.
  """
  @type adjustment :: %{
          required(:attack_element) => ElementModifiers.element(),
          required(:defense_element) => ElementModifiers.element(),
          required(:defense_level) => ElementModifiers.element_level(),
          required(:modifiers) => [modifier()],
          required(:allow_negative_ratio?) => boolean()
        }

  @typedoc "Four defense-level tables of ten attack rows by ten defense columns."
  @type tables :: tuple()

  @callback ratio(
              ElementModifiers.element(),
              ElementModifiers.element(),
              ElementModifiers.element_level()
            ) :: integer()

  @callback adjust_damage(integer(), adjustment()) :: integer()

  @callback get_modifier(
              ElementModifiers.element(),
              ElementModifiers.element(),
              ElementModifiers.element_level(),
              number()
            ) :: float()

  @doc """
  Looks up the table percentage, or `nil` for an unknown element or defense level.
  """
  @spec lookup(tables(), atom(), atom(), integer()) :: integer() | nil
  def lookup(tables, attack_element, defense_element, defense_level)
      when defense_level in 1..4 do
    case {Element.id(attack_element, nil), Element.id(defense_element, nil)} do
      {attack, defense} when is_integer(attack) and is_integer(defense) ->
        tables |> elem(defense_level - 1) |> elem(attack) |> elem(defense)

      _unknown ->
        nil
    end
  end

  def lookup(_tables, _attack_element, _defense_element, _defense_level), do: nil

  @doc """
  Clamps a negative final ratio to zero unless the adjustment allows recovery.
  """
  @spec final_ratio(integer(), adjustment()) :: integer()
  def final_ratio(ratio, %{allow_negative_ratio?: true}), do: ratio
  def final_ratio(ratio, _adjustment), do: max(ratio, 0)
end
