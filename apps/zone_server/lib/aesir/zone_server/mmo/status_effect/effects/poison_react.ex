defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.PoisonReact do
  @moduledoc """
  Poison React (SC_POISONREACT) counters ordinary weapon hits and arms one
  boosted ordinary swing after intercepting a Poison-element attack.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_poisonreact,
    no_dispel: false,
    properties: [:buff],
    icon: :poisonreact,
    prevented_by: [:sc_refresh, :sc_inspiration]

  import Aesir.ZoneServer.Mmo.StatusEffect.Helpers

  alias Aesir.ZoneServer.Mmo.Combat.TargetResolver
  alias Aesir.ZoneServer.Mmo.Skills.Shared.Envenom
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage
  alias Aesir.ZoneServer.Unit.AttackIntent
  alias Aesir.ZoneServer.Unit.Ref

  @poison_duration 60_000

  @impl true
  @spec on_apply(Ref.t(), StatusEntry.t(), map()) :: {:ok, StatusEntry.t()}
  def on_apply(_target, instance, _context) do
    state = %{level: instance.val1, charges: div(instance.val1, 2), chance: 50, mode: :block}
    {:ok, put_state(instance, state)}
  end

  @impl true
  @spec before_weapon_hit(Ref.t(), StatusEntry.t(), map(), map()) ::
          :continue | {:intercept, :poison_react}
  def before_weapon_hit({unit_type, unit_id} = holder, instance, attack_info, _context) do
    with true <- poison_basic_swing?(attack_info),
         %{mode: :block} <- instance.state,
         boosted = put_in(instance.state.mode, :boost),
         true <-
           StatusStorage.replace_status_if_current(
             unit_type,
             unit_id,
             :sc_poisonreact,
             instance,
             boosted
           ) do
      _ = AttackIntent.start(holder, attack_info.attacker)
      {:intercept, :poison_react}
    else
      _ -> :continue
    end
  end

  @impl true
  @spec after_damage_taken(Ref.t(), StatusEntry.t(), map(), map()) :: :ok
  def after_damage_taken(holder, instance, hit_info, _context) do
    if counter_hit?(instance, hit_info) and roll?(instance.state.chance) and
         claim_charge(holder, instance) do
      counter(holder, hit_info.attacker)
    end

    :ok
  end

  @impl true
  @spec before_normal_attack(Ref.t(), StatusEntry.t(), map(), map()) ::
          :continue | {:claim, map()}
  def before_normal_attack(
        _holder,
        %{state: %{mode: :boost, level: level}},
        _attack_info,
        _context
      ) do
    {:claim,
     %{
       damage_rate: 30 * level,
       poison: %{chance: 50, level: level, duration: @poison_duration}
     }}
  end

  def before_normal_attack(_holder, _instance, _attack_info, _context), do: :continue

  defp poison_basic_swing?(attack_info) do
    Map.get(attack_info, :basic_attack?, true) and Map.get(attack_info, :element) == :poison
  end

  defp counter_hit?(%{state: %{mode: :block, charges: charges}}, hit_info) do
    charges > 0 and
      Map.get(hit_info, :basic_attack?, false) and
      Map.get(hit_info, :dmg_type) == :physical
  end

  defp counter_hit?(_instance, _hit_info), do: false

  defp roll?(chance), do: :rand.uniform(100) <= chance

  defp claim_charge({unit_type, unit_id}, %{state: %{charges: 1}} = instance) do
    Interpreter.expire_status_if_current(unit_type, unit_id, :sc_poisonreact, instance)
  end

  defp claim_charge({unit_type, unit_id}, %{state: %{charges: charges}} = instance) do
    replacement = put_in(instance.state.charges, charges - 1)

    StatusStorage.replace_status_if_current(
      unit_type,
      unit_id,
      :sc_poisonreact,
      instance,
      replacement
    )
  end

  defp counter(holder, attacker) do
    with {:ok, _pid, holder_state, _holder_type} <- TargetResolver.resolve(holder) do
      _ = Envenom.execute(holder_state, attacker, 5)
    end

    :ok
  end
end
