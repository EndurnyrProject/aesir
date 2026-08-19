defmodule Aesir.ZoneServer.Mmo.Combat.Relationship do
  @moduledoc """
  Pure relationship decisions over typed combatants and unit references, with
  an explicit versus context for player-versus-player hostility.
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

  @typedoc "Versus context for player-vs-player hostility."
  @type versus :: :off | :gvg | {:pvp, noparty :: boolean(), noguild :: boolean()}

  @doc "Returns whether two combatants are enemies on a PvE map."
  @spec enemy?(Combatant.t(), Combatant.t()) :: boolean()
  def enemy?(%Combatant{} = attacker, %Combatant{} = target) do
    enemy?(attacker, target, :off)
  end

  @doc """
  Returns whether two combatants are enemies under an explicit versus context.

  `:off` reproduces PvE behavior: player sides are never enemies. Under `:gvg`
  player sides are enemies unless they share a nonzero party or guild. Under
  `{:pvp, noparty, noguild}` party/guild protection applies unless the matching
  override is set. Mob and homunculus-vs-mob branches are identical across all
  contexts.
  """
  @spec enemy?(Combatant.t(), Combatant.t(), versus()) :: boolean()
  def enemy?(%Combatant{} = attacker, %Combatant{} = target, versus) do
    attacker_root = social_root(attacker)
    target_root = social_root(target)

    cond do
      Ref.equal?(attacker_root, target_root) ->
        false

      player_side?(attacker_root) and player_side?(target_root) ->
        versus_enemy?(attacker, target, versus)

      player_side?(attacker_root) or player_side?(target_root) ->
        true

      true ->
        false
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

  defp versus_enemy?(_attacker, _target, :off), do: false

  defp versus_enemy?(attacker, target, :gvg),
    do: not (same_party?(attacker, target) or same_guild?(attacker, target))

  defp versus_enemy?(attacker, target, {:pvp, noparty, noguild}) do
    party_protected? = same_party?(attacker, target) and not noparty
    guild_protected? = same_guild?(attacker, target) and not noguild
    not (party_protected? or guild_protected?)
  end

  defp same_party?(%{party_id: party_id}, %{party_id: party_id}) when party_id > 0, do: true
  defp same_party?(_attacker, _target), do: false

  defp same_guild?(%{guild_id: guild_id}, %{guild_id: guild_id}) when guild_id > 0, do: true
  defp same_guild?(_attacker, _target), do: false
end
