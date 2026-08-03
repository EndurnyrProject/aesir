defmodule Aesir.ZoneServer.Mmo.Combat.Relationship do
  @moduledoc """
  Pure PvE relationship decisions over typed combatants and unit references.
  """

  alias Aesir.ZoneServer.Mmo.Combat.Combatant
  alias Aesir.ZoneServer.Unit.Ref

  @typedoc "A field-owned predicate over a typed unit reference."
  @type ground_selector :: (Ref.t() -> boolean())

  @doc "Returns a combatant's social root."
  @spec social_root(Combatant.t()) :: Ref.t()
  def social_root(%Combatant{social_root: root}) when is_tuple(root) do
    if Ref.valid?(root), do: root, else: raise(ArgumentError, "invalid social root")
  end

  def social_root(%Combatant{unit_type: :homunculus}),
    do: raise(ArgumentError, "missing social root")

  def social_root(%Combatant{unit_type: unit_type, unit_id: unit_id}),
    do: Ref.new!(unit_type, unit_id)

  @doc "Returns a combatant's reward root, when it has one."
  @spec reward_root(Combatant.t()) :: {:player, pos_integer()} | nil
  def reward_root(%Combatant{reward_root: nil, unit_type: :player, unit_id: unit_id}),
    do: Ref.new!(:player, unit_id)

  def reward_root(%Combatant{reward_root: nil, unit_type: :mob}), do: nil

  def reward_root(%Combatant{reward_root: nil, unit_type: :homunculus}),
    do: raise(ArgumentError, "missing reward root")

  def reward_root(%Combatant{reward_root: root}) do
    if Ref.valid?(root) and elem(root, 0) == :player,
      do: root,
      else: raise(ArgumentError, "invalid reward root")
  end

  @doc "Returns whether two combatants are enemies on a PvE map."
  @spec enemy?(Combatant.t(), Combatant.t()) :: boolean()
  def enemy?(%Combatant{} = attacker, %Combatant{} = target) do
    attacker_root = social_root(attacker)
    target_root = social_root(target)

    cond do
      Ref.equal?(attacker_root, target_root) -> false
      player_side?(attacker_root) and player_side?(target_root) -> false
      player_side?(attacker_root) or player_side?(target_root) -> true
      true -> false
    end
  end

  @doc "Returns whether a player may directly support the exact owned Homunculus."
  @spec direct_support?(Combatant.t(), Combatant.t()) :: boolean()
  def direct_support?(
        %Combatant{unit_type: :player} = caster,
        %Combatant{unit_type: :homunculus} = target
      ),
      do: Ref.equal?(social_root(caster), social_root(target))

  def direct_support?(%Combatant{}, %Combatant{}), do: false

  @doc "Returns whether an explicit ground-field selector chooses a typed unit."
  @spec ground_selected?(ground_selector(), Ref.t()) :: boolean()
  def ground_selected?(selector, target_ref) when is_function(selector, 1) do
    if Ref.valid?(target_ref) do
      selector.(target_ref) == true
    else
      raise ArgumentError, "invalid ground target reference"
    end
  end

  defp player_side?({:player, _unit_id}), do: true
  defp player_side?(_root), do: false
end
