defmodule Aesir.ZoneServer.Mmo.Combat.MagicDefense do
  @moduledoc """
  Resolves equipment-based magic reflection, reduction, and immunity.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Unit
  alias Aesir.ZoneServer.Unit.Ref
  alias Aesir.ZoneServer.Unit.UnitRegistry

  @status_immunity_threshold 50
  @typedoc "The result of resolving an incoming magic hit."
  @type outcome :: :hit | :miss | :reflect

  @doc "Decides a from-caster magic hit before any packet is built."
  @spec resolve(Combatant.t(), map()) :: outcome()
  def resolve(%Combatant{} = defender, hit_info) do
    resolve(defender, hit_info, &Resistance.roll_success/1)
  end

  @doc "Decides a from-caster magic hit using an injectable reflection roll."
  @spec resolve(Combatant.t(), map(), (non_neg_integer() -> boolean())) :: outcome()
  def resolve(%Combatant{} = defender, hit_info, roll) do
    cond do
      Map.get(hit_info, :reflected, false) -> :hit
      full_immunity?(defender) -> :miss
      not Map.get(hit_info, :from_caster?, false) -> :hit
      roll.(Map.get(defender.equip_modifiers, :magic_damage_return, 0)) -> :reflect
      true -> :hit
    end
  end

  @doc "Returns the incoming magic-damage reduction percentage, clamped to 0..100."
  @spec reduction_percent(map()) :: 0..100
  def reduction_percent(equip_modifiers) do
    equip_modifiers
    |> Map.get(:no_magic_damage, 0)
    |> max(0)
    |> min(100)
  end

  @doc "Applies a player's equipment reduction to incoming magic damage; non-players read zero."
  @spec reduce(integer(), Unit.unit_type(), integer()) :: integer()
  def reduce(damage, :player, target_id) do
    case UnitRegistry.get_unit_info(:player, target_id) do
      {:ok, %{equip_modifiers: equip_modifiers}} ->
        damage - div(damage * reduction_percent(equip_modifiers), 100)

      _missing_or_non_equipped ->
        damage
    end
  end

  def reduce(damage, _target_type, _target_id), do: damage

  @doc "Returns whether a unit has enough magic reduction to refuse magic-applied effects."
  @spec immune?(Ref.t()) :: boolean()
  def immune?({:player, target_id}) do
    case UnitRegistry.get_unit_info(:player, target_id) do
      {:ok, %{equip_modifiers: equip_modifiers}} ->
        reduction_percent(equip_modifiers) >= @status_immunity_threshold

      _missing_or_non_equipped ->
        false
    end
  end

  def immune?({_unit_type, _unit_id}), do: false

  @doc "Returns whether a combatant has complete magic immunity after clamping."
  @spec full_immunity?(Combatant.t()) :: boolean()
  def full_immunity?(%Combatant{} = combatant) do
    reduction_percent(combatant.equip_modifiers) == 100
  end
end
