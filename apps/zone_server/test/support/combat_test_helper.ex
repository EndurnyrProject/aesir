defmodule Aesir.ZoneServer.CombatTestHelper do
  @moduledoc """
  Combat test helpers that are not fixtures: an element-step stub and the
  equipment-fold shape of on-hit status bonuses. Combatants come from
  `Aesir.ZoneServer.Factory` (`build(:player_combatant)`, `build(:mob_combatant)`).
  """

  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Mmo.Combat.EquipAddEff

  @doc """
  Stubs every attribute step to scale its damage by a coefficient.

  `coefficient` receives the attack element, defense element, defense level and
  the summed bonus points of the step and returns the multiplier; the step's
  damage is truncated after scaling. Fields and webs are still captured by the
  real boundary before the stub runs.
  """
  @spec stub_element_coefficient((atom(), atom(), integer(), integer() -> number())) :: :ok
  def stub_element_coefficient(coefficient) do
    Mimic.stub(ElementModifiers, :adjust_damage, fn damage, adjustment ->
      bonus = adjustment.modifiers |> Enum.map(&elem(&1, 1)) |> Enum.sum()

      factor =
        coefficient.(
          adjustment.attack_element,
          adjustment.defense_element,
          adjustment.defense_level,
          bonus
        )

      trunc(damage * factor)
    end)

    :ok
  end

  @doc """
  Equipment modifiers as the equipment fold leaves them: the on-hit status
  bonuses among `mods` (`{:add_eff, ...}`-style destinations and their `bonus4`
  durations) registered into `EquipAddEff`'s ordered lists, everything else kept.
  """
  @spec equip_modifiers(map()) :: map()
  def equip_modifiers(mods) do
    {durations, rest} =
      Enum.split_with(mods, fn {dest, _value} -> EquipAddEff.duration_list(dest) != :error end)

    {bonuses, plain} =
      Enum.split_with(rest, fn {dest, value} -> EquipAddEff.bonus(dest, value) end)

    registered =
      Enum.map(bonuses, fn {dest, value} ->
        bonus = EquipAddEff.bonus(dest, value)
        param = elem(dest, tuple_size(dest) - 1)

        case Enum.find(durations, fn {{_family, duration_param}, _ms} ->
               duration_param == param
             end) do
          {_dest, ms} -> %{bonus | duration: ms}
          nil -> bonus
        end
      end)

    plain |> Map.new() |> EquipAddEff.register(registered)
  end
end
