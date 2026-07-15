defmodule Aesir.ZoneServer.Mmo.Skills.EstimationView do
  @moduledoc "Builds caster-only Estimation results from live mob state."

  alias Aesir.Commons.Utils.ServerTick
  alias Aesir.Net.EstimationResult
  alias Aesir.ZoneServer.Mmo.Combat.ElementModifiers
  alias Aesir.ZoneServer.Unit.Mob.MobState

  @attack_elements [:water, :earth, :fire, :wind, :poison, :holy, :shadow, :ghost, :undead]

  @spec result(non_neg_integer(), MobState.t()) :: EstimationResult.t()
  def result(target_id, %MobState{hp: hp, mob_data: mob_data}) do
    {element, element_level} = mob_data.element

    modifiers =
      Map.new(@attack_elements, fn attack_element ->
        {:"#{attack_element}_modifier",
         round(ElementModifiers.get_modifier(attack_element, element, element_level) * 100)}
      end)

    struct(
      EstimationResult,
      Map.merge(modifiers, %{
        target_id: target_id,
        class_id: mob_data.id,
        level: mob_data.level,
        size: size_id(mob_data.size),
        hp: hp,
        def: mob_data.def,
        race: race_id(mob_data.race),
        mdef: mob_data.mdef,
        element: ElementModifiers.id(element),
        server_tick: ServerTick.now()
      })
    )
  end

  defp size_id(:small), do: 0
  defp size_id(:medium), do: 1
  defp size_id(:large), do: 2

  defp race_id(:formless), do: 0
  defp race_id(:undead), do: 1
  defp race_id(:brute), do: 2
  defp race_id(:plant), do: 3
  defp race_id(:insect), do: 4
  defp race_id(:fish), do: 5
  defp race_id(:demihuman), do: 6
  defp race_id(:angel), do: 7
  defp race_id(:demon), do: 8
  defp race_id(:dragon), do: 9
  defp race_id(:player), do: 10
end
