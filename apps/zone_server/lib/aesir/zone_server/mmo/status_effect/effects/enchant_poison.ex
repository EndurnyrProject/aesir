defmodule Aesir.ZoneServer.Mmo.StatusEffect.Effects.EnchantPoison do
  @moduledoc """
  Enchant Poison (SC_ENCPOISON).

  Endows the weapon with the poison element, replacing other weapon endows.
  A normal attack's additional-effect stage (a connected hit on a target that
  survives it, whatever its damage) may Poison the target (`roll_poison/2`). In classic it also ends Weapon Enchant
  (SC_ENCHANTARMS); in renewal the two coexist and Weapon Enchant's element
  wins.
  """
  use Aesir.ZoneServer.Mmo.StatusEffect.Definition,
    id: :sc_encpoison,
    no_dispel: false,
    no_clear_buff: false,
    clear_buff_flags: [:remove_on_hermode],
    properties: [:buff],
    calc_flags: [:atk_ele],
    flags: [:remove_on_unequip_weapon],
    end_on_start: [
      renewal: [
        :sc_aspersio,
        :sc_fireweapon,
        :sc_waterweapon,
        :sc_windweapon,
        :sc_earthweapon,
        :sc_shadowweapon,
        :sc_ghostweapon
      ],
      pre_renewal: [
        :sc_aspersio,
        :sc_fireweapon,
        :sc_waterweapon,
        :sc_windweapon,
        :sc_earthweapon,
        :sc_shadowweapon,
        :sc_ghostweapon,
        :sc_enchantarms
      ]
    ],
    prevented_by: [:sc_refresh, :sc_inspiration],
    icon: :enchantpoison

  alias Aesir.ZoneServer.Mmo.StatusEffect.Definition
  alias Aesir.ZoneServer.Mmo.StatusEffect.Interpreter, as: StatusInterpreter
  alias Aesir.ZoneServer.Mmo.StatusEffect.Resistance
  alias Aesir.ZoneServer.Mmo.StatusEntry
  alias Aesir.ZoneServer.Mmo.StatusStorage

  @impl true
  def modifiers(_instance, _context), do: %{attack_element: :poison}

  @doc """
  Rolls the attacker's Enchant Poison against `target` on a normal attack's
  additional-effect stage. An attacker without the endow attempts nothing.
  """
  @spec roll_poison(Definition.target(), Definition.target()) :: :ok
  def roll_poison(attacker, target), do: roll_poison(attacker, target, &Resistance.roll_rate/1)

  @doc false
  @spec roll_poison(Definition.target(), Definition.target(), (integer() -> boolean())) :: :ok
  def roll_poison({source_type, source_id}, {target_type, target_id}, roll) do
    case StatusStorage.get_status(source_type, source_id, :sc_encpoison) do
      nil ->
        :ok

      %StatusEntry{} = instance ->
        poison(instance, {source_type, source_id}, target_type, target_id, roll)
    end
  end

  defp poison(instance, {source_type, source_id}, target_type, target_id, roll) do
    case StatusInterpreter.apply_status(target_type, target_id, :sc_poison,
           caster_id: source_id,
           source_type: source_type,
           duration: 10_000 * instance.val1,
           success_rate: (250 + 50 * instance.val1) / 100,
           resistance_roll: roll
         ) do
      :ok ->
        :ok

      {:error, reason}
      when reason in [:immune, :boss_immune, :prevented, :conflict, :resisted, :target_dead] ->
        :ok

      {:error, reason} ->
        raise "SC_POISON application failed: #{inspect(reason)}"
    end
  end
end
